#!/bin/bash

# ================================
# Comprehensive Blockchain Node Management Script
# Usage: ./initExecution.sh
# ================================

if ! which jq &>/dev/null; then
    echo "jq is required but not installed. Aborting."
    exit 1
fi
if ! which docker &>/dev/null; then
    echo "docker is required but not installed. Aborting."
    exit 1
fi

LOG_FILE="node_manager.log"
CUSTOM_GENESIS="el-cl-genesis-data"
GENESIS_DATA_TAR_NAME="${CUSTOM_GENESIS}.tar.gz"

# Logging Function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}


# Color definitions
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

# Logging Functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

handle_error() {
    log "ERROR: $1"
    exit 1
}

run_command() {
    "$@" || handle_error "Failed to execute: $*"
}

COMPOSE_CMD="docker compose"


# ================================
# Section 1: Clear 
# ================================
clear_node() {
    log "Clearing old blockchain data..."
    run_command rm -rvf execution-data consensus-data
    run_command rm -rvf validator_keys/{logs,slashing_protection.sqlite,slashing_protection.sqlite-journal,.secp-sk,api-token.txt}
    log "Node data cleared."
}


# ================================
# Section 3: Down 
# ================================
down_node() {
    log "Stopping and removing containers..."
    $COMPOSE_CMD -f compose.yaml down
    log "Containers stopped and removed."
}

# ================================
# Section 4: Init Execution 
# ================================
init_execution() {
    if ! [ -d "${CUSTOM_GENESIS}" ]; then
        log_error "Genesis data not found: ${CUSTOM_GENESIS}"
        log_info "Unpacking genesis data..."
        tar -xzvf ${GENESIS_DATA_TAR_NAME}
    fi

    log "Initializing Execution Layer..."
    docker run \
      --rm \
      -it \
      -v $(pwd)/execution-data:/execution-data \
      -v $(pwd)/${CUSTOM_GENESIS}:/el-cl-genesis-data \
      ethereum/client-go:v1.13.4 \
      --state.scheme=hash \
      --datadir=/execution-data \
      init \
      /el-cl-genesis-data/custom_config_data/genesis.json
    log "Execution Layer initialized."
}

# ================================
# Section 5: Start 
# ================================
start_node() {
    log_info "Starting validator node..."
    
    # Get IP address or use default
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Enter your server's public IP address (leave blank for auto-detect): ")" IP_ADDRESS
    
    if [ -z "$IP_ADDRESS" ]; then
        IP_ADDRESS=$(curl -s https://ipinfo.io/ip)
        log_info "Using auto-detected IP: $IP_ADDRESS"
    fi
    
    # Export IP for the docker compose file
    export IP_ADDRESS="$IP_ADDRESS"
    
    # Define default bootnodes
    STATIC_EL_BOOTNODES=(
        "enode://378d074d9041983bc58950253a3e02694b9ae59f7a8f332c37e018e385f83ce9f2409f689ccd22af995d888ab38d1c4101b9dcf7f10d1ea5a84a315d2243c146@209.145.57.126:30303"
        "enode://a1da3ead2f3e553939b8cc748a8c93d7e08d8353d403c3d9eeb0b5f738bf5b9f151561a6536a70dd865f6c1fe0ab66e72e243b8e5cb3d49b32b4378a96cca928@209.126.0.162:30303"
        "enode://8a33188e594a9dc0b178d93f1a6909a19623581c087d4c1d9ead1173df69a63acc0128df17b3f0909b929a27420b47f9429546380a16444fa3c48961d6ef0ac6@161.97.156.81:30303"
        "enode://e3bed860ac9336e47856b4d76f239b860da61edc319ad9e20853f925b05c5816c734f98eaaa84fca647cacae7f86e526f979d4d879b50ce8c8c89ddff02770c2@178.18.248.45:30303"
        "enode://08c09e4c923f90f2416d840eb1a8c1125e70ac9de24cc77a1f99392d439da9f0574b730478497ce68841423638206219e5cf27992b6f94e29cfc040eae5bdd36@65.20.108.189:30303"
        "enode://04d488ca9c39d6f55ab5a4acc9ab0c949aa1e7590f62d65e3ee079acf49b43c6ce9cbaaa54ebad1493b7a94e7f9aa9ba540707aa497c83dec9507e2faa1dbb40@8.213.135.163:30303"
        "enode://9a681f701a607c34b47beb9ccb05d7264655732886fa9511db07be54689609fc642539f0f6fc7b799ff8b2e2473d38d07812b22952d5153bb021b2a73afada46@8.211.26.181:30303"
        "enode://d658550ea78a206171b22d2d7986a60101573c04d5bc24cb47be2b4ed09a109e0b0232a7d49e2bf8d1bb7ddfa89d6c8bbce7d9d68be1a903dd31ab7fbdd111ab@47.253.42.79:30303"
        "enode://703e82bb29768004bd546092e5009c14df94f20db95503706dd35343ab1e3fb28bd1319d80abedbf6249a8185c64ea64f71ec7681f511a9c996bad4d86282649@47.253.41.183:30303"
        "enode://11710fc840a4311a5b16f155134806fc6630dacf4cd4f97cad3f539b319ad2ecfc300b73fb073ca3849b7d07ffe41bab3f0a3cacecc8978fd549bd9a0f4bbce7@47.87.12.149:30303"
        "enode://1657367413f23d6bce60081566e61ac42206c0a67d52e4728f76620e6259b782754356c806bfecff6df4525ac5ab878b18835519760b5fcf1caab99a57cf81d6@8.208.101.214:30303"
        "enode://98ef4ce7c1c18bbe80231349dddfbf697ece605e4e06ccfd45b48a2e84cd8cd358e4cbbaf60df62b51aa00d0e137465ec618775f00f923f5aafadcffdef7c9ba@47.91.87.108:30303"
    )

    STATIC_CL_BOOTNODES=(
        "enr:-MS4QBk-L-MpPuqfyNwYovIeqTBikWd6vU9E7DPCNgo4IB3hIu8uYe5ivuiAbSEtyhlnhTYPwZqpf7rp5FC4L6-uMi9Fh2F0dG5ldHOI__________-EZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhNGROX6EcXVpY4IjKYlzZWNwMjU2azGhApQnZwoBeP2IcxTsLjaURKxGAf4Ygw7ZEOBDxo4osc1LiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QP8ZkC2oYF6qrQVXo2zayqMIfNyGfI9wI2NiuT8K6NkuMwC-k5jLssKKfq9EUlbfJNmv4iJLWGvBJxcnuAZEp0pFh2F0dG5ldHOI__________-EZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhNF-AKKEcXVpY4IjKYlzZWNwMjU2azGhAh-KPeRLwYhhon2zT-GdEuVu2QjVen9m1GqM_KB9AnP1iHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QI5h6K7PpozTlDPjPu6bVxxoTgI_u--vPqFBbFPkV75NBeVabima9QhFdH66A3sDa5OlXT4vqRuj1WJCHobbY8dFh2F0dG5ldHOI__________-EZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhKFhnFGEcXVpY4IjKYlzZWNwMjU2azGhAzwv-_IlJ3FU1IisE8hvrDpWZk859feSfuu4FtvSXoSCiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QGCTOnGDuRqQOVc_J9RGXvDu9mj4oRIiZALj7VRNuXn7WN8PDByc9GNJmOb2-cByyXmjpOHwo_u9iN0MmJ6qRApFh2F0dG5ldHOI__________-EZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhLIS-C2EcXVpY4IjKYlzZWNwMjU2azGhAzcSo4SLTe-NgUaBicZeUiWyBkGCqQ3qPIizEC_MXvVFiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QOrRTECzxsKpyAAsx6KPTFTE6Ji7PWs-HNxEa-rfnFx2FL-09MJNGvvcwtnNiotN8e-wanUql3OoQAWs-HRMjiNFh2F0dG5ldHOI__________-EZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhEEUbL2EcXVpY4IjKYlzZWNwMjU2azGhA30b0glGo9cnMZJzvB9JSv54LuVLj2V2XM1iNdAh0sW_iHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MW4QLfTp5uJCaXEAI5rO4F7xeZFkVJcTZ22W5rFF3DeyWbsLiS7ZzutgdRb7NatoIRkAIXN8TxJDMjpvDBEEbYQknuBi4dhdHRuZXRziAAAAAAAAAAAhGV0aDKQZHiqnlAAAAH_yZo7AAAAAIJpZIJ2NIJpcIQI1YejhHF1aWOCIymJc2VjcDI1NmsxoQMzyTe6R1QeqWxk--DUtuhdbT3AyUBfR2A91tUFqJcB-4hzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA"
        "enr:-MS4QG46vTqgdBlVK62mfGLztOLhQGD385WQQ38mwzafxf0ceZWda2RbAKxZ-FtAFky9A4TPyV8UNKa6KJNmnrMzIotGh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhC_9Kk-EcXVpY4IjKYlzZWNwMjU2azGhAgWmP8TH2J8Vb122mibZXa_NPExLhMcP2h_D6EKUKAwLiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QEwKNKF_qUeHiY01odPAJ2zICSIt0bMa5D4w_ZFdtxWbTyX4C9tjRPnjclhXBDKh6J0zKItzxA0SIrcxrlo807NGh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhAjTGrWEcXVpY4IjKYlzZWNwMjU2azGhAyKGMTOCeciRtNDk1KKGzjVtaK9eIic8gUA5EqF7H4QsiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QHkW1xqE1iPS73J73c71cx3n8ZSzN9UT4-jAyh0gawYlTcyvt-dlRVczm2Mx7KC7JC_CI4WG49II_fXTVkzd0fQBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhC9XDJWEcXVpY4IjKYlzZWNwMjU2azGhA0VJy4X4cHTqeJM912RlLJE2cU0GFVeMM-yO7r6QAcJciHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QAetO_dg3A3hY9so63ph8IZ3x6uJCqhfB9u-C_EOmoSGYH5ME3Lt8t0x-0XeCRqtq6m3cD_mB4xbpLYxMV8amd4Bh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhAjQZdaEcXVpY4IjKYlzZWNwMjU2azGhAtFmsChvnTGc6Nrtt9-zCWHKg_nR_FYBgBnFfcugWig8iHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QOp7Bj6yGCqng7v4Xq6DZ9Nde9NT6q28YpR36DcEA39RY48RFqMhZmzkvnOOjBSbOOVqPhV-AFmQhrIsFzls8wsBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhC9bV2yEcXVpY4IjKYlzZWNwMjU2azGhAitO6A9DQxUvi_PR8JMwRuUVkJuQforsFRuN-evoC4mPiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
    )

    STATIC_CL_TRUSTPEERS=(
        "16Uiu2HAm5Q1AeAfNuwaBaVqvxRM8L1bXf7gjQiURPHvyCmzqWyDC"
        "16Uiu2HAkwYnt1kNmK8iP9K9cUigddJfjgVKcBeSK6yJVJzJmdFrc"
        "16Uiu2HAmGhwFT2F8UkhLarvvvA8CGXBa1SmHYAT7yrwaRCVdKNKj"
        "16Uiu2HAmGMyFvqzWATNuQahhkEDkfaCeyc6qmNKLkt4r9zz9VN3W"
        "16Uiu2HAmM5MvAPAq64SrpW9c2uzAxYXHADeg32hwmCHQmhFh9hCa"
        "16Uiu2HAmG996pYKMsq6WoET55fTcjMe3nGevbKQcEErPXiUjxWCJ"
        "16Uiu2HAmEyktiyziDTctFiKUpdyc3mxiHJUtMFk1P8DzXWmGeH7R"
        "16Uiu2HAkuoj3rZp6sUeDVpbNKMGkVi4JW8jnfUg6N1fy1jyXnFS2"
        "16Uiu2HAmEyktiyziDTctFiKUpdyc3mxiHJUtMFk1P8DzXWmGeH7R"
        "16Uiu2HAmHKTkFLQQjD1M5qTqkEahz5ecYXWhsTrHvQfq6zq4wYf5"
        "16Uiu2HAm9X61Lsh2Xw1CvH5t6PkuNHTXB5ZEajofht1BNeUbZ8iw"
        "16Uiu2HAkxLjJ912WZRRTyB18Puz5Tg6DR6AfsEZnX7Zw8B7J2d3L"
    )
    STATIC_CL_CHECKPOINTS=("https://checkpointz.blocxscan.com/")
    
    # Export environment variables
    export EL_BOOTNODES=$(IFS=, ; echo "${STATIC_EL_BOOTNODES[*]}")
    export CL_BOOTNODES=$(IFS=, ; echo "${STATIC_CL_BOOTNODES[*]}")
    export CL_TRUSTPEERS=$(IFS=, ; echo "${STATIC_CL_TRUSTPEERS[*]}")
    export CL_CHECKPOINT=$(IFS=, ; echo "${STATIC_CL_CHECKPOINTS[0]}")
    export CHAIN_ID=86996
    
    echo "export EL_BOOTNODES=$EL_BOOTNODES" #>> .env
    echo "export CL_BOOTNODES=$CL_BOOTNODES" #>> .env
    echo "export CL_TRUSTPEERS=$CL_TRUSTPEERS" #>> .env
    echo "export CL_CHECKPOINT=$CL_CHECKPOINT" #>> .env
    echo "export CHAIN_ID=$CHAIN_ID" #>> .env
    
    # Generate JWT secret if it doesn't exist
    if [ ! -f "el-cl-genesis-data/jwt/jwtsecret" ]; then
        log_info "Generating JWT secret..."
        openssl rand -hex 32 > "el-cl-genesis-data/jwt/jwtsecret" || handle_error "Failed to generate JWT secret"
    fi
    
    # Start the validator node
    log_info "Starting docker compose..."
    docker compose -f compose.yaml up -d || handle_error "Failed to start validator node"
    
    log_success "Validator node started successfully"
    log_info "You can check logs with: docker compose -f compose-validator.yaml logs -f"
}

# ================================
# Section 6: Stop 
# ================================
stop_node() {
    log "Stopping containers..."
    $COMPOSE_CMD -f compose.yaml stop
    log "Containers stopped."
}

# ================================
# Section 7: Clean 
# ================================
clean() {    
    log_info "Cleaning up..."

    down_node

    sudo rm -rvf execution-data
    sudo rm -rvf consensus-data
    sudo rm -rvf el-cl-genesis-data

    sudo rm -rvf keys/validator_keys/logs
    sudo rm -rvf keys/validator_keys/slashing_protection.sqlite
    sudo rm -rvf keys/validator_keys/slashing_protection.sqlite-journal
    sudo rm -rvf keys/validator_keys/.secp-sk
    sudo rm -rvf keys/validator_keys/api-token.txt

    git clean -fdx
    log_success "Cleanup complete."
}

# ================================
# Main Execution
# ================================
display_menu() {
    echo -e "${YELLOW}Select an option:${RESET}"
    echo "clear. Clear Terminal"
    echo "init. Start Node"
    echo "start. Start Node"
    echo "stop. Stop Node"
    echo "down. Down POS Chain Node"
    echo "clean. Shutdown & Cleanup POS Chain Node"
    echo "exit. Exit"
}

while true; do
    display_menu  
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Enter your choice: ")" CHOICE
    
    case "$CHOICE" in
        clear)
            clear
            ;;
        init)
            init_execution
            ;;
        start)
            start_node
            ;;
        stop)
            stop_node
            ;;
        down)
            down_node
            ;;
        clean)
            clean
            ;;
        exit)
            log_info "Exiting script. Goodbye!"
            exit 0
            ;;
        *)
            log_warning "Invalid choice. Please try again."
            ;;
    esac
    echo
done
