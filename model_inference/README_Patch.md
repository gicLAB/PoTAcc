# PoTAcc Patch Documentation

## Overview
These patches apply Power-of-Two (PoT) quantization configuration support to some key files in SECDA-TFLite:
- `hw_gen.py` - Hardware generation and HLS build script generation
- `process_flags_n_config.py` - Application evaluation suite configuration
- `launch.json` and `tasks.json` - VSCode launch and task configurations

## Changes Summary

### 1. `patch_hw_gen.sh` - Hardware Generator Patch
**File Modified:** `hardware_automation/hw_gen.py`

**Changes:**
- **Addition 1:** Added `self.potq` configuration parameter in `hardware_exp.__init__()`
  - Reads `"potq"` key from hardware config JSON
  - Defaults to `"QKERAS"` if key is not present
  - Location: After `self.acc_link_folder` initialization

- **Addition 2:** Updated `generate_hls_tcl()` method
  - Includes `{self.potq}` in HLS compiler flags
  - Allows different PoT quantization schemes (APOT, MSQ, QKERAS) to be passed to HLS during compilation
  - Flag format: `-D{self.potq}` (e.g., `-DAPOT`, `-DQKERAS`)

**Usage in hw_gen.py:**
```python
self.potq = dict_default(config, "potq", "QKERAS")
# In add_files command:
f' -cflags "-D__SYNTHESIS__, -D{self.board}, -D{self.potq}"'
```

### 2. `patch_secda_apps_evaluation_suite.sh` - Application Evaluation Suite Patch
**File Modified:** `src/secda_apps_evaluation_suite/scripts/process_flags_n_config.py`

**Changes:**
- **Addition 1:** Added `find_potq_value_for_board()` helper function
  - Nested function inside `generate_bazel_build_scripts()`
  - Searches through hardware configs for vm_shift_delegate entries
  - Returns the `"potq"` value if present, otherwise returns empty string
  - Ensures only the first matching potq config is used (per design)

- **Addition 2:** Replaced hardcoded APOT flag with dynamic potq lookup
  - Old: `potq_flag = "  --copt='-DAPOT'"`
  - New: Dynamic lookup via `find_potq_value_for_board(board_name)`
  - Constructs compiler flag based on found potq value
  - Supports multiple quantization schemes (APOT, MSQ, etc.)

**Usage in process_flags_n_config.py:**
```python
def find_potq_value_for_board(target_board):
    # Iterates through hw_arr
    # Returns hw_config["potq"] if found
    # Returns "" if not found

potq_value = find_potq_value_for_board(board_name)
if isinstance(potq_value, str) and potq_value.strip():
    potq_flag = f" --copt='-D{potq_value.strip().upper()}'"
else:
    potq_flag = ""
```

### 3. `patch_launch.sh` - VSCode Launch/Tasks Merge Patch
**Files Modified:** `tensorflow/.vscode/launch.json`, `tensorflow/.vscode/tasks.json`

**Changes:**
- **Addition 1:** Merges missing VSCode launch configurations from the PoTAcc copy into the SECDA-TFLite copy
  - Compares launch entries by `preLaunchTask`
  - If a `preLaunchTask` already exists in the destination file, that entry is skipped
  - New entries are appended to the end of the destination `configurations` array

- **Addition 2:** Merges missing VSCode tasks from the PoTAcc copy into the SECDA-TFLite copy
  - Compares tasks by `label`, then `taskName`, then `id`
  - If the task key already exists in the destination file, that task is skipped
  - New tasks are appended to the end of the destination `tasks` array

- **Addition 3:** Handles PoTAcc-generated files that are stored as JSON fragments
  - Supports fragment-style `launch.json` and `tasks.json` content
  - Strips JSONC comments and trailing commas before parsing
  - Automatically wraps fragments into the correct JSON object shape when needed

- **Addition 4:** Creates backups before writing destination files
  - Existing destination files are copied to `launch.json.backup` and `tasks.json.backup`
  - This allows manual recovery if the merge needs to be reverted


**Merge Rules:**
```python
# launch.json: compare by preLaunchTask
if preLaunchTask already exists in dst:
    skip entry

# tasks.json: compare by label -> taskName -> id
if task key already exists in dst:
    skip task
```


## How It Works

### Hardware Configuration JSON Structure
The patches expect hardware configuration JSON files to have optional `"potq"` key:

```json
{
  "acc_name": "VMSHv12",
  "acc_version": 0,
  "acc_sub_version": 4,
  "board": "KRIA",
  "del": "vm_shift_delegate",
  "del_version": 12,
  "potq": "APOT",
  ...
}
```

### Compilation Flow

1. **hw_gen.py**: When `hw_gen.py` reads a hardware config:
   - Extracts `potq` value (defaults to `QKERAS`)
   - Passes it to HLS as a compiler define
   - Example: `hls_script.tcl` gets `-DAPOT` or `-DQKERAS`

2. **process_flags_n_config.py**: When generating bazel build scripts:
   - Searches hardware configs for vm_shift_delegate with matching board
   - Extracts `potq` value from config
   - Constructs bazel compiler flag: `--copt='-D<potq_value>'`
   - Example: `--copt='-DAPOT'` or `--copt='-DQKERAS'`

## Supported PoT Quantization Schemes

The patches support any quantization scheme name in the `"potq"` field:
- `APOT` - Arbitrary Power-of-Two quantization
- `MSQ` - Mixed-Size Quantization (future support)
- `QKERAS` - QKeras quantization (default)
- Custom schemes can be added by specifying the potq value in JSON

## Backup and Recovery

Each patch script creates a backup of the modified file:
- `hw_gen.py.backup`
- `process_flags_n_config.py.backup`

If patches fail, backups are automatically restored. You can manually restore using:
```bash
cp hardware_automation/hw_gen.py.backup hardware_automation/hw_gen.py
cp src/secda_apps_evaluation_suite/scripts/process_flags_n_config.py.backup \
   src/secda_apps_evaluation_suite/scripts/process_flags_n_config.py
```

## Troubleshooting

### Patch fails to apply
- Check if files have been modified manually
- Verify file paths are correct
- Restore backups and try again

### potq flag not being used in builds
- Check hardware config JSON includes `"potq"` field
- Verify board name matches in config
- Check delegate is `"vm_shift_delegate"`

### Compilation errors with potq defines
- Ensure source code supports the defines (e.g., `#ifdef APOT`)
- Check spelling matches in hardware config vs source code
- Verify quantization scheme is implemented in delegate code
