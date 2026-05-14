#!/usr/bin/env bash
set -euo pipefail

echo "[PoTAcc] Applying targeted Image-Classification/Preprocessing C++ patches..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_secda_root() {
    local dir="$SCRIPT_DIR"
    while [[ "$dir" != "/" ]]; do
        if [[ "$(basename "$dir")" == "SECDA-TFLite" ]]; then
            printf '%s' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

SECDA_ROOT="$(find_secda_root || true)"
if [[ -z "$SECDA_ROOT" ]]; then
    echo "ERROR: SECDA-TFLite root not found. Place PoTAcc under SECDA-TFLite and re-run."
    exit 1
fi

STAGES_DIR="$SECDA_ROOT/tensorflow/tensorflow/lite/tools/evaluation/stages"

mkdir -p "$STAGES_DIR"

echo "Patching: image_classification_stage.cc"
CLASS_FILE="$STAGES_DIR/image_classification_stage.cc"
if [[ -f "$CLASS_FILE" ]]; then
    cp -p "$CLASS_FILE" "${CLASS_FILE}.potacc.bak"
    echo "  Backup created: ${CLASS_FILE}.potacc.bak"
    python3 - "${CLASS_FILE}" <<'PY'
import io,sys
fn=sys.argv[1]
p=io.open(fn,'r',encoding='utf8').read()
old='builder.AddCroppingStep(kCroppingFraction, true /*square*/);\n    builder.AddResizingStep(input_shape->data[2], input_shape->data[1], false);'
new=('    //original\n'
     '    // builder.AddCroppingStep(kCroppingFraction, true /*square*/);\n'
     '    // builder.AddResizingStep(input_shape->data[2], input_shape->data[1], false);\n'
     '    // For ResNet\n'
     '    // builder.AddResizingStep(256, 256, true /*aspect_preserving*/);\n'
     '    // For MobileNet-V2\n'
     '    builder.AddResizingStep(232, 232, true /*aspect_preserving*/);\n\n'
     '    builder.AddCroppingStep(input_shape->data[2], input_shape->data[1],\n'
     '                            true /*square*/);')
if old in p:
    p = p.replace(old, new, 1)
    io.open(fn,'w',encoding='utf8').write(p)
    print('  Patched image_classification_stage.cc')
else:
    print('  Pattern not found; no changes made to image_classification_stage.cc')
PY
else
    echo "  Warning: $CLASS_FILE not found; skipping"
fi

echo "Patching: image_preprocessing_stage.cc"
PRE_FILE="$STAGES_DIR/image_preprocessing_stage.cc"
if [[ -f "$PRE_FILE" ]]; then
    cp -p "$PRE_FILE" "${PRE_FILE}.potacc.bak"
    echo "  Backup created: ${PRE_FILE}.potacc.bak"
    python3 - "${PRE_FILE}" <<'PY'
import io,sys,re
fn=sys.argv[1]
p=io.open(fn,'r',encoding='utf8').read()
changed=False
# Rename Normalize -> Normalize_old if needed
if 'inline void Normalize_old(' not in p and 'inline void Normalize(' in p:
    p=p.replace('inline void Normalize(', 'inline void Normalize_old(', 1)
    changed=True

# Ensure new Normalize implementation present
if 'float mean_arr[3] = {0.485f' not in p:
    # Find the end of the Normalize_old function
    m=re.search(r'(inline void Normalize_old\([^)]*\)[\s\S]*?\n\})', p)
    new_fn='''
inline void Normalize(ImageData* image_data,
                      const NormalizationParams& params) {
  float* data_end = image_data->data->data() + image_data->data->size();
  float mean_arr[3] = {0.485f, 0.456f, 0.406f};  // RGB mean
  float std_arr[3] = {0.229f, 0.224f, 0.225f};   // RGB std

  // Normalize to [0,1], then normalize with mean and std.
  for (float* data = image_data->data->data(); data < data_end;) {
    *data = (*data / 255.0f - mean_arr[0]) / std_arr[0];
    ++data;
    *data = (*data / 255.0f - mean_arr[1]) / std_arr[1];
    ++data;
    *data = (*data / 255.0f - mean_arr[2]) / std_arr[2];
    ++data;
  }
}
'''
    if m:
        p = p.replace(m.group(1), m.group(1) + '\n' + new_fn, 1)
        changed=True
    else:
        # fallback: append new fn before anonymous namespace end
        p = p.replace('\n}  // namespace\n', new_fn + '\n}  // namespace\n', 1)
        changed=True

if changed:
    io.open(fn,'w',encoding='utf8').write(p)
    print('  Patched image_preprocessing_stage.cc')
else:
    print('  No changes needed for image_preprocessing_stage.cc')
PY
else
    echo "  Warning: $PRE_FILE not found; skipping"
fi

echo "Done. Backups saved with .potacc.bak suffix in the same directory."

exit 0
