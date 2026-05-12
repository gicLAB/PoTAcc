#!/bin/bash
# Patch script to apply PoTAcc potq configuration changes to process_flags_n_config.py
# This script adds dynamic potq lookup based on hardware configuration
# Author: PoTAcc Integration
# Date: 2026

set -e

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

SECDA_TFLITE_PATH="$(find_secda_root || true)"
PROCESS_FLAGS_FILE="${SECDA_TFLITE_PATH}/src/secda_apps_evaluation_suite/scripts/process_flags_n_config.py"

if [ ! -f "$PROCESS_FLAGS_FILE" ]; then
    echo "  ERROR: process_flags_n_config.py not found at $PROCESS_FLAGS_FILE"
    exit 1
fi

echo "  Applying PoTAcc potq support to process_flags_n_config.py..."
echo "  File: $PROCESS_FLAGS_FILE"

# Create backup
cp "$PROCESS_FLAGS_FILE" "${PROCESS_FLAGS_FILE}.backup"
echo "  Created backup: ${PROCESS_FLAGS_FILE}.backup"

# Apply patches using Python
PROCESS_FLAGS_FILE="$PROCESS_FLAGS_FILE" python3 << 'PYTHON_PATCH_EOF'
import sys
import os

file_path = os.environ.get('PROCESS_FLAGS_FILE')
if not file_path or not os.path.exists(file_path):
    print(f"  ERROR: File not found: {file_path}")
    sys.exit(1)

with open(file_path, 'r') as f:
    content = f.read()

# Patch 1: Add helper function after generate_bazel_build_scripts definition
if 'def find_potq_value_for_board(target_board):' not in content:
    helper_func = '''def generate_bazel_build_scripts(sc, hw_arr, app_dict):
    def find_potq_value_for_board(target_board):
        for hw in hw_arr:
            hw_config_file = utils.find_hw_config(
                f"{sc['secda_tflite_path']}/{sc['hw_configs']}", hw
            )
            hw_config = utils.load_config(hw_config_file)
            if hw_config.get("board") != target_board:
                continue
            if hw_config.get("del") != "vm_shift_delegate":
                continue
            if "potq" in hw_config:
                return hw_config["potq"]
        return ""

    cpu_paths = {'''
    
    old_pattern = '''def generate_bazel_build_scripts(sc, hw_arr, app_dict):
    cpu_paths = {'''
    
    if old_pattern in content:
        content = content.replace(old_pattern, helper_func)
        print("  Added find_potq_value_for_board helper function")
    else:
        print("  WARNING: Could not find exact pattern for function definition")
else:
    print("  Helper function already present")

# Patch 2: Inject vm_shift_delegate potq flag into the generated build commands
old_vm_shift_block = '''                    if board_name == "KRIA":
                        script += f"{bb_pr_kria}{del_path}:{bin_name} {bb_po_kria} \\n"
                        script += f"rsync -r -avz -e 'ssh -p {board_port}' {path_to_tf}/bazel-out/aarch64-opt/bin/{del_path}/{bin_name} {board_user}@{board_hostname}:{board_eval_dir}/bins/{name}\\n"
                    elif board_name == "Z1" or board_name == "Z2":
                        script += f"{bb_pr_pynq}{del_path}:{bin_name} {bb_po_pynq}  \\n"
                        script += f"rsync -r -avz -e 'ssh -p {board_port}' {path_to_tf}/bazel-out/armhf-opt/bin/{del_path}/{bin_name} {board_user}@{board_hostname}:{board_eval_dir}/bins/{name}\\n"'''

new_vm_shift_block = '''                    potq_flag = ""
                    if delegate == "vm_shift_delegate":
                        potq_value = find_potq_value_for_board(board_name)
                        if isinstance(potq_value, str) and potq_value.strip():
                            potq_flag = f" --copt='-D{potq_value.strip().upper()}'"

                    if board_name == "KRIA":
                        script += f"{bb_pr_kria}{del_path}:{bin_name} {bb_po_kria} {potq_flag}\\n"
                        script += f"rsync -r -avz -e 'ssh -p {board_port}' {path_to_tf}/bazel-out/aarch64-opt/bin/{del_path}/{bin_name} {board_user}@{board_hostname}:{board_eval_dir}/bins/{name}\\n"
                    elif board_name == "Z1" or board_name == "Z2":
                        script += f"{bb_pr_pynq}{del_path}:{bin_name} {bb_po_pynq} {potq_flag} \\n"
                        script += f"rsync -r -avz -e 'ssh -p {board_port}' {path_to_tf}/bazel-out/armhf-opt/bin/{del_path}/{bin_name} {board_user}@{board_hostname}:{board_eval_dir}/bins/{name}\\n"'''

if old_vm_shift_block in content:
    content = content.replace(old_vm_shift_block, new_vm_shift_block)
    print("  Replaced vm_shift_delegate potq flag logic")
else:
    print("  WARNING: Could not find exact pattern for vm_shift_delegate block")

with open(file_path, 'w') as f:
    f.write(content)

print("  Python patching completed successfully")
PYTHON_PATCH_EOF

if [ $? -eq 0 ]; then
    echo "✓ Successfully applied all patches to process_flags_n_config.py. Backups created with .backup suffix if destinations existed."
else
    echo "  ERROR: Failed to apply patches"
    mv "${PROCESS_FLAGS_FILE}.backup" "$PROCESS_FLAGS_FILE"
    echo "  Restored original file from backup"
    exit 1
fi
