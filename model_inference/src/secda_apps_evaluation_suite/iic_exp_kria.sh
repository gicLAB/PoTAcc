#!/bin/bash

set -e  # Exit on any error


# Configuration
BOARD_NAME="${BOARD_NAME:-KRIA}"
BOARD_HOSTNAME="${BOARD_HOSTNAME:-xx}"  # Update with your board IP
BOARD_USER="${BOARD_USER:-xx}" # Update with your board username
BOARD_PORT="${BOARD_PORT:-xx}" # Update with your board SSH port if not default 22
RESTART_WAIT_TIME=180  # 3 minutes in seconds

# system config path
sc_path="../../config.json"

# collect BOARD_HOSTNAME, BOARD_USER, BOARD_PORT from system config for KRIA board
if [ -f "$sc_path" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            BOARD_HOSTNAME) BOARD_HOSTNAME="$value" ;;
            BOARD_USER) BOARD_USER="$value" ;;
            BOARD_PORT) BOARD_PORT="$value" ;;
        esac
    done < <(python3 - "$sc_path" "$BOARD_NAME" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    config = json.load(f)

board_name = sys.argv[2]
board = config.get("boards", {}).get(board_name, {})
print(f"BOARD_HOSTNAME={board.get('board_hostname', '')}")
print(f"BOARD_USER={board.get('board_user', '')}")
print(f"BOARD_PORT={board.get('board_port', '')}")
PY
)
fi

# Function to log messages and commands
log_msg() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

log_cmd() {
    local cmd="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD: $cmd" >> "$LOG_FILE"
}

# Function to check SSH connectivity
check_ssh_connectivity() {
    log_msg "Checking SSH connectivity to ${BOARD_HOSTNAME}..."

    local attempts=2
    local attempt=1

    while [ $attempt -le $attempts ]; do
        log_cmd "ssh -o BatchMode=yes -o ConnectTimeout=2 -p ${BOARD_PORT} ${BOARD_USER}@${BOARD_HOSTNAME} 'exit' > /dev/null 2>&1"
        if ssh -o BatchMode=yes -o ConnectTimeout=2 -p "${BOARD_PORT}" "${BOARD_USER}@${BOARD_HOSTNAME}" 'exit' > /dev/null 2>&1; then
            log_msg "✓ SSH reachable (attempt ${attempt})"
            return 0
        else
            log_msg "(attempt ${attempt}) SSH not reachable yet"
            attempt=$((attempt + 1))
            sleep 1
        fi
    done

    log_msg "✗ SSH not reachable after ${attempts} attempts"
    exit 1
}

# Function to restart board
restart_board() {
    log_msg "Restarting board at ${BOARD_NAME}..."

    # Send reboot command (expects NOPASSWD sudo on remote)
    log_cmd "ssh -p "$BOARD_PORT" -o BatchMode=yes -o ConnectTimeout=5 "$BOARD_USER@$BOARD_HOSTNAME" 'sudo systemctl reboot --no-block'"
    if ! ssh -p "$BOARD_PORT" -o BatchMode=yes -o ConnectTimeout=5 "$BOARD_USER@$BOARD_HOSTNAME" 'sudo systemctl reboot --no-block' &>>"$LOG_FILE"; then
        log_msg "✗ Failed to send reboot command. Ensure NOPASSWD sudo is configured for ${BOARD_USER} on the board."
        exit 1
    fi
}


# Logging configuration
LOG_FILE="./PotAcc_log/running_iic_exp_kria_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "Logging to: $LOG_FILE" >&2
echo "Using BOARD_NAME=${BOARD_NAME}, BOARD_HOSTNAME=${BOARD_HOSTNAME}, BOARD_USER=${BOARD_USER}, BOARD_PORT=${BOARD_PORT}" | tee -a "$LOG_FILE"

#run all the imagenet_image_classification evaluations for Kria hardware
echo "Running imagenet_image_classification evaluations for Kria hardware..." | tee -a "$LOG_FILE"

log_msg "Running iic_VMOPT_kria_10K_0 evaluation..."
restart_board
log_msg "Waiting ${RESTART_WAIT_TIME}s for board to reboot..."
sleep "$RESTART_WAIT_TIME"
check_ssh_connectivity

log_msg ""
log_cmd "./secda_apps_evaluation_suite.sh -j configs/iic_VMOPT_kria_10K_0.json -n iic_VMOPT_kria_10K_0 -b -c"
./secda_apps_evaluation_suite.sh -j configs/iic_VMOPT_kria_10K_0.json -n iic_VMOPT_kria_10K_0 -b -c

log_msg "✓ Completed iic_VMOPT_kria_10K_0 evaluation"

log_msg ""
log_msg "Running iic_VMSHAPOT_kria_10K_0 evaluation..."
restart_board
log_msg "Waiting ${RESTART_WAIT_TIME}s for board to reboot..."
sleep "$RESTART_WAIT_TIME"
check_ssh_connectivity

log_msg ""
log_cmd "./secda_apps_evaluation_suite.sh -j configs/iic_VMSHAPOT_kria_10K_0.json -n iic_VMSHAPOT_kria_10K_0 -b -c"
./secda_apps_evaluation_suite.sh -j configs/iic_VMSHAPOT_kria_10K_0.json -n iic_VMSHAPOT_kria_10K_0 -b -c | tee -a "$LOG_FILE"
log_msg "✓ Completed iic_VMSHAPOT_kria_10K_0 evaluation"
