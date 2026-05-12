#!/bin/bash
# Patch script to apply PoTAcc potq configuration changes to hw_gen.py
# This script modifies the hardware_exp class to support Power-of-Two quantization
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
HW_GEN_FILE="${SECDA_TFLITE_PATH}/hardware_automation/hw_gen.py"

if [ ! -f "$HW_GEN_FILE" ]; then
    echo "  ERROR: hw_gen.py not found at $HW_GEN_FILE"
    exit 1
fi

echo "  Applying PoTAcc potq support to hw_gen.py..."
echo "  File: $HW_GEN_FILE"

# Create backup
cp "$HW_GEN_FILE" "${HW_GEN_FILE}.backup"
echo "  Created backup: ${HW_GEN_FILE}.backup"

# Apply patches using Python for precise modifications
HW_GEN_FILE="$HW_GEN_FILE" python3 << 'PYTHON_PATCH_EOF'
import sys
import os

file_path = os.environ.get('HW_GEN_FILE')
if not file_path or not os.path.exists(file_path):
    print(f"  ERROR: File not found: {file_path}")
    sys.exit(1)

with open(file_path, 'r') as f:
    content = f.read()

# Patch 1: Add self.potq initialization after self.acc_link_folder
if 'self.potq = dict_default(config, "potq", "QKERAS")' not in content:
    old_block = '''        self.acc_link_folder = os.path.abspath(
            self.hw_link_dir + config["acc_link_folder"]
        )'''
    
    new_block = '''        self.acc_link_folder = os.path.abspath(
            self.hw_link_dir + config["acc_link_folder"]
        )
        self.potq = dict_default(config, "potq", "QKERAS")'''
    
    if old_block in content:
        content = content.replace(old_block, new_block)
        print("  Added potq configuration initialization in __init__")
    else:
        print("  WARNING: Could not find exact match for acc_link_folder block")
else:
    print("  potq initialization already present")

# Patch 2: Update add_files line to include {self.potq} in compiler flags
if '-D{self.potq}' not in content:
    old_cflags = 'f\' -cflags "-D__SYNTHESIS__, -D{self.board}"'
    new_cflags = 'f\' -cflags "-D__SYNTHESIS__, -D{self.board}, -D{self.potq}"'
    
    if old_cflags in content:
        content = content.replace(old_cflags, new_cflags)
        print("  Updated add_files compiler flags to include potq")
    else:
        print("  WARNING: Could not find exact match for cflags pattern")
else:
    print("  potq flag already present in cflags")

with open(file_path, 'w') as f:
    f.write(content)

print("  Python patching completed successfully")
PYTHON_PATCH_EOF

if [ $? -eq 0 ]; then
    echo "✓ Successfully applied all patches to hw_gen.py. Backups created with .backup suffix if destinations existed."
else
    echo "  ERROR: Failed to apply patches"
    mv "${HW_GEN_FILE}.backup" "$HW_GEN_FILE"
    echo "  Restored original file from backup"
    exit 1
fi
