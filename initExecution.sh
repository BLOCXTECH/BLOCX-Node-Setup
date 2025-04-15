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
    log "Starting Blockchain Node..."
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Enter your node 1 address: ")" NODE1_ADDRESS
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Enter your node 1 execution port: ")" E_PORT
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Enter your node 1 consensus port: ")" C_PORT
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Enter your Network ChainId: ")" CHAIN_ID
    export NODE1_ADDRESS=${NODE1_ADDRESS:-0.0.0.0}
    export E_PORT=${E_PORT:-8545}
    export C_PORT=${C_PORT:-5052}
    export CHAIN_ID=${CHAIN_ID:-86996}
    echo "Using NODE1_ADDRESS: $NODE1_ADDRESS"
    echo "Using EXECUTION_PORT: $E_PORT"
    echo "Using CONSENSUS_PORT: $C_PORT"

    export IP_ADDRESS=$(curl -4 -s https://icanhazip.com/) || handle_error "Failed to retrieve public IP."
    echo "Using IP address: $IP_ADDRESS"

    RESPONSE_EL=$(curl -m 1 -s -X POST -H "Content-Type: application/json" --data @el.request.json http://$NODE1_ADDRESS:$E_PORT)
    export ENODE=$(echo $RESPONSE_EL | jq -r '.result.enode')
    export EL_BOOTNODES=$ENODE

    RESPONSE_CL=$(curl -m 1 -s -X GET -H "Content-Type: application/json" http://$NODE1_ADDRESS:$C_PORT/eth/v1/node/identity)
    PEER_ID=$(echo $RESPONSE_CL | jq -r '.data.peer_id')
    ENR=$(echo $RESPONSE_CL | jq -r '.data.enr')

    export CL_TRUSTPEERS=$PEER_ID
    export CL_BOOTNODES=$ENR

    export CL_CHECKPOINT=http://$NODE1_ADDRESS:$C_PORT/

    run_command log_info "EL_BOOTNODES=$EL_BOOTNODES"
    run_command log_info "CL_BOOTNODES=$CL_BOOTNODES"
    run_command log_info "CL_TRUSTPEERS=$CL_TRUSTPEERS"
    run_command log_info "CL_CHECKPOINT=$CL_CHECKPOINT"

    # Prompt for user input
    read -rp "$(echo -e "${BLUE}[INPUT]${RESET} Do you want to set validator node (Y/N): ")" VALIDATOR_NODE

    log "Starting $COMPOSE_CMD..."
    # Check the user input
    if [[ "$VALIDATOR_NODE" == "Y" || "$VALIDATOR_NODE" == "y" ]]; then
        $COMPOSE_CMD -f compose-validator.yaml up -d
    else
        $COMPOSE_CMD -f compose.yaml up -d
    fi
    log "Node started successfully."
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
