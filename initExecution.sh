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
        "enode://8dfdc7b6986a3f82a7fc43e4a79665a35116478e89681a095a5651732a35286c866a68b86632b4bf6e0e0f7d6dd21fab51a728dcb88300f147230230903b8755@89.117.60.7:30303"
        "enode://c278cd02070baf1f8d9c3c15f68d813550dbbab5d13530130bf5de2f385677ea8ba0785452253673f294f5e34f0027429e4029d622e549dfaee688dfd3302712@161.97.156.81:30303"
        "enode://e3bed860ac9336e47856b4d76f239b860da61edc319ad9e20853f925b05c5816c734f98eaaa84fca647cacae7f86e526f979d4d879b50ce8c8c89ddff02770c2@178.18.248.45:30303"
        "enode://08c09e4c923f90f2416d840eb1a8c1125e70ac9de24cc77a1f99392d439da9f0574b730478497ce68841423638206219e5cf27992b6f94e29cfc040eae5bdd36@65.20.108.189:30303"
        "enode://e42c9e37663ea00124344533f508137eba42fb0ee141da9e5121a5910a8e7680f001c6425fe37e53c8b574382c7ec7949fdc250bf673a83b578a808741c45aae@66.42.97.78:30303"
    )

    STATIC_CL_BOOTNODES=(
        "enr:-MS4QDxgoveCg4gYIby9oQEksvZ34Op0PXFXPogLePtHLMHsBfOjwDVD1W4bbD3Ph6qUOhLcap7R60WuyympoAftYnRGh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhNGROX6EcXVpY4IjKYlzZWNwMjU2azGhA7RSfIDLDnspHv0ANcTODH9HFq71fJ6F5twel1XqHZ_ZiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QHvieKTxolN94vlaieTRSPFdqNjJXfCsccQjzrx3mdoeFXRdY9rNDC3AGiMCh8hGc_s-CZbYAL_uzB2looEWiMIBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhFl1PAeEcXVpY4IjKYlzZWNwMjU2azGhAj35DN23nkm2j0THOShcMMWnac_LXuqqj5qkNDj6_CQLiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"        
        "enr:-MS4QF-MkVUZxANk6ox9VkZYsN3UH61YBcuOSm7EMSQyMKVTLkh2TEgxEynBcUVyyJ9BgEWQTHuMfWEH6XxWvSbrlIBGh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhKFhnFGEcXVpY4IjKYlzZWNwMjU2azGhAwlEut7pAGBYnUK-M-XJH2UNzi-ul9OBqb9nYRR-tEwiiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"        
        "enr:-MS4QCdm1w7Uze2bplZdEc_SEkmwWq5BMgbB3MYEgqhFJTTUUEAN3NoFT2AgZ7LywQHe4xHkeV88w-QQbUasG8YKRDsBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhFl1Ow6EcXVpY4IjKYlzZWNwMjU2azGhAwAdv1e9RWlHqjOcFpunUkgKzoqj8VhuRMuxKk31F45AiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"        
        "enr:-MS4QGun7qyyJWefiyFqfocsX8dKwPPmkufeNX4NVyF0t0CANdkb45Jo0M-lAeoaDCHiBn3qQQM15AV5YpITM_cwW7lGh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhLIS-C2EcXVpY4IjKYlzZWNwMjU2azGhAuJt5giclYBnUGDMPguKTxoyN0G1w5GA-Cit3KeKVvxBiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"        
        "enr:-MS4QIDEyqZHmfUUdo36FAXd9EAUHMuGB7-20b_1MsJBwcdbV8vOdpP4U9uGWdYInEHgjKdLOd7PN1eFlA3TcO57A39Gh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhEEUbL2EcXVpY4IjKYlzZWNwMjU2azGhA6AJVjPJq28pSbwAf-e9nsXo7Ay3iHGInzxw8wL_A3gziHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"        
        "enr:-MS4QJV9XsXDptu7AQJAeiQ4uhTH9U-6rg2llwIehu0qFdXkQjhlHligUOr3Z16wWNH2VKca2EdQEmw4ZaLzSUkLyO9Gh2F0dG5ldHOIAAAAAAAAAACEZXRoMpBkeKqeUAAAAf_JmjsAAAAAgmlkgnY0gmlwhEIqYU6EcXVpY4IjKYlzZWNwMjU2azGhAuA_JErMlKSryGJ7C5n-iGeaeI2ZGgXVyPBfVt1-KjWPiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
    )

    STATIC_CL_TRUSTPEERS=(
        "16Uiu2HAmQntgqDMfeAHNoQaEEbvBGrsyeqJDMHoke9GkL43SN3rY"
        "16Uiu2HAkybb7PEnUcMvkvj8D5rgW18RhAvazCDjzQFvZWKa6JKz2"
        "16Uiu2HAmDHAoePub7LBbLAdeKCvM8nGUofEbHcPhbdU2exMNqRrR"
        "16Uiu2HAmCfSfCW7H8wMhytQsUPwRVVqDZugKkJjN4864atJJGaL7"
        "16Uiu2HAmAfZKCPVCEaKpjN4knZ7rgSKCTi5ScwoPRdgcdr4hNKkL"
        "16Uiu2HAmPRhqf4wmhUnu2qUpVUUXDWRk1FK8CrYYAmb15Wkk6ZAJ"
        "16Uiu2HAmAX39VRjvDYAXC4gBtoFgWuzAN3MrRkttCKdGgDN9vjhp"
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
