#!/bin/bash
set -e

# patch_launch.sh
# Merge PoTAcc tensorflow/.vscode/launch.json and tasks.json into
# SECDA-TFLite/tensorflow/.vscode, adding missing entries and
# creating backups of destination files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_secda_root() {
    local dir="$SCRIPT_DIR"

    while [[ "$dir" != "/" ]]; do
        if [[ "$(basename "$dir")" == "SECDA-TFLite" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi

        dir="$(dirname "$dir")"
    done

    return 1
}

SECDA_ROOT="$(find_secda_root || true)"

if [[ -z "$SECDA_ROOT" ]]; then
    echo "ERROR: PoTAcc must be placed under the SECDA-TFLite folder before running this script."
    exit 1
fi

SRC_VSCODE="$SCRIPT_DIR/tensorflow/.vscode"
DST_VSCODE="$SECDA_ROOT/tensorflow/.vscode"

if [[ ! -d "$SRC_VSCODE" ]]; then
    echo "Source VSCode folder not found: $SRC_VSCODE"
    echo "Nothing to do."
    exit 0
fi

mkdir -p "$DST_VSCODE"
export SRC_VSCODE DST_VSCODE

# Use Python to merge JSON/JSONC (strip comments and trailing commas)
python3 - <<'PY'
import os,sys,shutil,re,json

# load JSONC-like content safely: strip comments while preserving strings
def load_jsonc(path, fragment_key=None):
    txt = open(path,'r',encoding='utf-8').read()
    out_chars = []
    i = 0
    n = len(txt)
    in_str = False
    esc = False
    while i < n:
        c = txt[i]
        if in_str:
            out_chars.append(c)
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
            i += 1
        else:
            if c == '"':
                in_str = True
                out_chars.append(c)
                i += 1
            elif c == '/' and i+1 < n and txt[i+1] == '/':
                # skip until end of line
                i += 2
                while i < n and txt[i] not in '\r\n':
                    i += 1
            elif c == '/' and i+1 < n and txt[i+1] == '*':
                # skip block comment
                i += 2
                while i+1 < n and not (txt[i] == '*' and txt[i+1] == '/'):
                    i += 1
                i += 2
            else:
                out_chars.append(c)
                i += 1
    txt = ''.join(out_chars)
    # remove trailing commas before } or ]
    txt = re.sub(r',\s*(\}|\])', r'\1', txt)
    # remove any trailing comma at end of file
    txt = re.sub(r',\s*\Z', '', txt)
    try:
        return json.loads(txt)
    except Exception:
        # If it's a fragment (sequence of objects), try wrapping as configurations/tasks array
        keys_to_try = []
        if fragment_key == 'tasks':
            keys_to_try = ['tasks', 'configurations']
        elif fragment_key == 'configurations':
            keys_to_try = ['configurations', 'tasks']
        else:
            keys_to_try = ['configurations', 'tasks']

        last_err = None
        for key in keys_to_try:
            wrapper_version = '2.0.0' if key == 'tasks' else '0.2.0'
            wrapped = '{"version":"' + wrapper_version + '","' + key + '":[' + txt + ']}'
            try:
                return json.loads(wrapped)
            except Exception as e:
                last_err = e
        raise last_err

added_total = 0

# launch.json
src_launch = os.path.join(os.environ['SRC_VSCODE'],'launch.json')
dst_launch = os.path.join(os.environ['DST_VSCODE'],'launch.json')
if os.path.exists(src_launch):
    try:
        src_data = load_jsonc(src_launch, 'configurations')
    except Exception as e:
        print(f"  ERROR: Failed to parse source launch.json: {e}")
        sys.exit(2)
    if os.path.exists(dst_launch):
        shutil.copy2(dst_launch,dst_launch+'.backup')
        try:
            dst_data = load_jsonc(dst_launch, 'configurations')
        except Exception as e:
            print(f"  ERROR: Failed to parse dest launch.json: {e}")
            sys.exit(3)
    else:
        dst_data = {"version":"0.2.0","configurations":[]}

    dst_cfgs = dst_data.get('configurations',[])
    dst_pre = set([c.get('preLaunchTask') for c in dst_cfgs if c.get('preLaunchTask')])
    added = 0
    for c in src_data.get('configurations',[]):
        pre = c.get('preLaunchTask')
        if pre and pre in dst_pre:
            continue
        if not pre and c in dst_cfgs:
            continue
        dst_cfgs.append(c)
        added += 1
    dst_data['configurations'] = dst_cfgs
    with open(dst_launch,'w',encoding='utf-8') as f:
        json.dump(dst_data,f,indent=4)
    print(f"  launch.json: added {added} configuration(s)")
    added_total += added
else:
    print('  source launch.json missing; skipping')

# tasks.json
src_tasks = os.path.join(os.environ['SRC_VSCODE'],'tasks.json')
dst_tasks = os.path.join(os.environ['DST_VSCODE'],'tasks.json')
if os.path.exists(src_tasks):
    try:
        src_t = load_jsonc(src_tasks, 'tasks')
    except Exception as e:
        print(f"  ERROR: Failed to parse source tasks.json: {e}")
        sys.exit(4)
    if os.path.exists(dst_tasks):
        shutil.copy2(dst_tasks,dst_tasks+'.backup')
        try:
            dst_t = load_jsonc(dst_tasks, 'tasks')
        except Exception as e:
            print(f"  ERROR: Failed to parse dest tasks.json: {e}")
            sys.exit(5)
    else:
        dst_t = {"version":"2.0.0","tasks":[]}

    def key_of(t):
        return t.get('label') or t.get('taskName') or t.get('id')

    dst_tasks_list = dst_t.get('tasks',[])
    dst_keys = set([key_of(t) for t in dst_tasks_list if key_of(t)])
    added = 0
    for t in src_t.get('tasks',[]):
        k = key_of(t)
        if k and k in dst_keys:
            continue
        if not k and t in dst_tasks_list:
            continue
        dst_tasks_list.append(t)
        added += 1
    dst_t['tasks'] = dst_tasks_list
    with open(dst_tasks,'w',encoding='utf-8') as f:
        json.dump(dst_t,f,indent=4)
    print(f"  tasks.json: added {added} task(s)")
    added_total += added
else:
    print(' source tasks.json missing; skipping')

print(f"  Total entries added: {added_total}")
PY

echo "✓ patch_launch.sh completed. Backups created with .backup suffix if destinations existed."
