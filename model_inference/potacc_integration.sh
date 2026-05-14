#!/bin/bash
# this script will linkup the potacc folder to the respective directories in the SECDA-TFLite repository.
# PoTAcc repo can be downloaded anywhere in the host machine
# this script will take input the installation path of the SECDA-TFLite repository and the PoTAcc repository and link the respective folders.

# git update-index --assume-unchanged .vscode/launch.json 

# PoTAcc Integration Script

set -e

echo "=========================================="
echo "PoTAcc Integration for SECDA-TFLite v2"
echo "=========================================="

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
    echo "If you already opened the Dev Container, close it first, copy the PoTAcc folder under SECDA-TFLite, and then reopen the container."
    exit 1
fi

# Step 1: Apply hw_gen.py patch
echo ""
echo "[1/6] Applying hw_gen.py patch..."
bash "$SCRIPT_DIR/patch_hw_gen.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply hw_gen.py patch"
    exit 1
fi

# Step 2: Apply process_flags_n_config.py patch
echo ""
echo "[2/6] Applying process_flags_n_config.py patch..."
bash "$SCRIPT_DIR/patch_secda_apps_evaluation_suite.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply process_flags_n_config.py patch"
    exit 1
fi

# Step 3: Copy POTACC configs into SECDA-TFLite hardware_automation/configs
echo ""
echo "[3/6] Copying POTACC hardware configs into SECDA-TFLite..."
SRC="$SCRIPT_DIR/hardware_automation"
DST="$SECDA_ROOT/hardware_automation"

if [[ -d "$SRC" ]]; then
    echo "  Source: $SRC"
    echo "  Destination: $DST"
    mkdir -p "$DST"
    # Copy contents and overwrite existing files
    cp -a "$SRC"/. "$DST"/
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to copy HW configs and Generated files to $DST"
        exit 1
    fi
    echo "✓ HW configs and Generated files are copied and existing files overwritten."
else
    echo "WARNING: HW configs and Generated files not found at $SRC; skipping copy."
fi

# Step 4: Copy secda_delegates and secda_apps_evaluation_suite from PoTAcc into SECDA-TFLite src/
echo ""
echo "[4/6] Copying secda_delegates and secda_apps_evaluation_suite from PoTAcc into SECDA-TFLite..."

copy_src_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    local label="$3"

    if [[ -d "$src_dir" ]]; then
        echo "  Source: $src_dir"
        echo "  Destination: $dst_dir"
        mkdir -p "$dst_dir"
        # Copy contents and overwrite existing files
        cp -a "$src_dir"/. "$dst_dir"/
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to copy $label to $dst_dir"
            exit 1
        fi
        echo "✓ $label copied and existing files overwritten."
    else
        echo "WARNING: $label not found at $src_dir; skipping copy."
    fi
}

SRC_DELEGATES="$SCRIPT_DIR/src/secda_delegates"
DST_DELEGATES="$SECDA_ROOT/src/secda_delegates"
copy_src_dir "$SRC_DELEGATES" "$DST_DELEGATES" "secda_delegates"

SRC_APPS_EVAL="$SCRIPT_DIR/src/secda_apps_evaluation_suite"
DST_APPS_EVAL="$SECDA_ROOT/src/secda_apps_evaluation_suite"
copy_src_dir "$SRC_APPS_EVAL" "$DST_APPS_EVAL" "secda_apps_evaluation_suite"

if [[ -d "$DST_APPS_EVAL" ]]; then
    # Ensure copied shell scripts are executable.
    find "$DST_APPS_EVAL" -type f -name "*.sh" -exec chmod +x {} +
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to set executable permissions on .sh files in $DST_APPS_EVAL"
        exit 1
    fi
    echo "✓ Executable permissions updated for .sh files in secda_apps_evaluation_suite."
fi

# Step 5: Copy data folders from PoTAcc into SECDA-TFLite/data
echo ""
echo "[5/6] Copying data folders from PoTAcc into SECDA-TFLite/data..."
SRC_DATA="$SCRIPT_DIR/data"
DST_DATA="$SECDA_ROOT/data"

if [[ -d "$SRC_DATA" ]]; then
    echo "  Source: $SRC_DATA"
    echo "  Destination: $DST_DATA"
    mkdir -p "$DST_DATA"
    # Copy contents and overwrite existing files
    cp -a "$SRC_DATA"/. "$DST_DATA"/
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to copy data folders to $DST_DATA"
        exit 1
    fi
    echo "✓ Data folders copied and existing files overwritten."
    echo ""
    echo "Reminder: Ensure you've downloaded the test datasets into the 'testData' folders before running evaluations."
    echo "See: $SCRIPT_DIR/README_DataPrep.md for instructions on downloading and placing data under the appropriate testData folders."
else
    echo "WARNING: data folder not found at $SRC_DATA; skipping copy."
    echo "If you need the test data, follow: $SCRIPT_DIR/README_DataPrep.md to download and place datasets under the 'testData' folders, then re-run this script."
fi

# Step 6: Merge vscode `launch.json` and `tasks.json` from PoTAcc into tensorflow/.vscode
echo ""
echo "[6/7] Merging VSCode launch/tasks from PoTAcc into tensorflow/.vscode..."
bash "$SCRIPT_DIR/patch_launch.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to merge VSCode launch/tasks"
    exit 1
fi

# Step 7: Apply Image-Classification / Preprocessing patches
echo ""
echo "[7/7] Applying Image-Classification and Preprocessing C++ patches..."
bash "$SCRIPT_DIR/tensorflow/patch_iic.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply IIC patches"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ PoTAcc Integration Completed Successfully"
echo "=========================================="
