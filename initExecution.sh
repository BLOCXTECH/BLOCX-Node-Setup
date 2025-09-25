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
        "enode://d65683eda3edc21704e403d07938a505e68748fbe21b8bc16432287ab7b397db5964ed23d1070e712fd77252ee4eb0b0549036637abc0d75527886eeedf22e49@89.117.60.7:30303"
        "enode://62acb20f764908868f1e5dbfef0491f08c75b367355476039e88c5eaa75ecb47f1afacb56cd6d43eeaa19f21a3c9cd5ff6128a4bd9d870f530ee62e21d38002c@161.97.156.81:30303"
        "enode://cca368898222a15a25a054d479b9c4ddb8156d50e9e36a2cc5988c53a1511a91b731bc897ec644d1400aea597075e06948269ff675b413f15c7dd2472d5114e1@89.117.59.14:30303"
        "enode://6595cb6c6bceec09ca57f298fa93ec65f8995d4952fccd0a7067172e00b0ce8bd8013fa1162747705bf631881d4ec0bbfd5199276dab0d8620b61475691a1f20@178.18.248.45:30303"
        "enode://d5e241a2ee793d80bb9e3a68a6c9ada2c24b376c809e2afe52b4831997a788c07a7f5ca0c2d713453e026bde89a5b4497c1fc8dab46333e5fdf9278d93464189@194.163.173.243:30303"
        "enode://bafa68dde8bac9093d9621ed4e17142aea19a0b9952ade2c12bbc5e4baf655b3e574a1be3ce51e192a064115cb27be165eac8ab8f042369aa19bcf1cf9f08dac@65.20.108.189:30303"
        "enode://6a0ac81508777f00b1abb86bb6a4ce2cb2719474ef9defe7d972681ae816d0da6500217800c5c9dda8180f3e6378e20a2ddb9826489d2fbaf23107e7290ee9c0@66.42.97.78:30303"
    )

    STATIC_CL_BOOTNODES=(
        "enr:-MS4QBcHBxNZd8XZQE8tVBFy45ud4d8Gk6i83u3HR2b8swH9KGR5CZiRfQfs1RTLJb6WA24bygGEsz8tZYVnokQu629Bh2F0dG5ldHOI__________-EZXRoMpBEFUdzUAAAAYCWmAAAAAAAgmlkgnY0gmlwhFl1PAeEcXVpY4IjKYlzZWNwMjU2azGhA-KwlD6q8u9-MplTFPL7KQG0Ee2W4XEsVOqooTk6gx2yiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QPetWTF5jkQbeCoFDhZH_dvTQR5kGjjE0IbStABBfXujOcDCKNW2kpxbaPxPV8_-iXzIscjKnu_4-gbA9XNbYNBFh2F0dG5ldHOI__________-EZXRoMpBEFUdzUAAAAYCWmAAAAAAAgmlkgnY0gmlwhKFhnFGEcXVpY4IjKYlzZWNwMjU2azGhAzL9MxWNSqV0AaR0jjhgcydLf3aXf8rzR-kD_e8QYZjSiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QHBMm_ArfR9TaZihSpCShYRIZT-OFvXitszijDJ2QjknXg-hpgfA-BxZbWer70O73ttCOpzWukTGwReZoCS-MptFh2F0dG5ldHOI__________-EZXRoMpBEFUdzUAAAAYCWmAAAAAAAgmlkgnY0gmlwhFl1Ow6EcXVpY4IjKYlzZWNwMjU2azGhAyhh1CLUfsvr0ctsjVgr27Bkof6E-dJtA2x6B_s-OMaDiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QGpeD-EIOoO_wjqmLj9ErVvub54Hntwp59rRUCvvvO0SPt__wZurtuIA0oCnF2BFPqzAZObOGrD4IVgFA0YKRaxFh2F0dG5ldHOI__________-EZXRoMpBEFUdzUAAAAYCWmAAAAAAAgmlkgnY0gmlwhLIS-C2EcXVpY4IjKYlzZWNwMjU2azGhAtb_eRDp6BeHJ0snIUt8IPZ2bXlsnSpCP6hnmY5KTofGiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MW4QLCYmZHK3sRCNHrSsNscWD1vc73cXFIMULTtl2pcHk4kfyUO5S5k7MZBgdWaq4IiUHQ6-VSN6Yw6vXqaZ6ngf4SBiodhdHRuZXRziP__________hGV0aDKQRBVHc1AAAAGAlpgAAAAAAIJpZIJ2NIJpcITCo63zhHF1aWOCIymJc2VjcDI1NmsxoQK8YiZa3zCwIbxVfe8JM4EBtcEFdak87ES9LrmZQIzEjIhzeW5jbmV0cw-DdGNwgiMog3VkcIIjKA"
        "enr:-MS4QCqHaJhRAkg_dtb3jgUCNWxvTndep-wU2FT8JUbb6ufOPIvXhmMYnNF26LcOW3ElKWnQVMrclrmERTmkDHw3ZyJFh2F0dG5ldHOI__________-EZXRoMpBEFUdzUAAAAYCWmAAAAAAAgmlkgnY0gmlwhEEUbL2EcXVpY4IjKYlzZWNwMjU2azGhAvSPfDRGORlw4t_5NDFDN_RoZDFfQp1CZ6578nk_Q5cpiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
        "enr:-MS4QGNRQfj6SPAs2becAvfErxvsilljVkkbl0EJGlbspKtmILwA3TjJ29IigdTVEJC-KIpQBanptssvTugkjM9Wo6ZFh2F0dG5ldHOI__________-EZXRoMpBEFUdzUAAAAYCWmAAAAAAAgmlkgnY0gmlwhEIqYU6EcXVpY4IjKYlzZWNwMjU2azGhA6D6gnO2d5R03Orac0c0NS9VKB_wWk8Sr00PZ40oT_QNiHN5bmNuZXRzD4N0Y3CCIyiDdWRwgiMo"
    )

    STATIC_CL_TRUSTPEERS=(
        "16Uiu2HAmTutf6wswdBu1kEYQRmas2wY47JfQN2KPiZDbNs8822xZ"
        "16Uiu2HAmG62fcHpahKJUrepsGMiXMBeafc6TR9kDxoXFh8iYQhwF"
        "16Uiu2HAmFNdBKPpdif1KYHfsp6fqLRKZ8PQD5PswfYJShm9kcdQN"
        "16Uiu2HAm9twAkJn3e6Ec4fJC4gK3LebyBMRmAGyYwmfZx9MKcNQ5"
        "16Uiu2HAm873RyRWqw17J6AMRwqV3wV2QNWQwHqsmTkfTWCvmWrm9"
        "16Uiu2HAmBtLMg785JYdZWLSiCtcR4q1sBEgPE1k3U8HwwNwYm9UU"
        "16Uiu2HAmPVP8jjmj4BB1JsAr4uHvb7pwTzZL6fV4Y1mPWuTYt6jn"
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


#  export EL_BOOTNODES=enode://3fd56f5517b53ca2f6ad5e5ebf94a708b2d761fe25f758523e48e5d3693095df0f58e9e060a8beceb701f7aa6954e9ee1f64ac69a05f59cda1015e21d1f6a5ed@66.42.97.78:30303,enode://1e32cbe880bc57764b9b76f755ba76954c6eeca8150b69c03851d659cea2504ff712b67774b9c33d327d4365b6bd7834a13fbe616a2ad2b66bba8283bd4e6253@89.117.60.7:30303,enode://03ee18b3f2726b6851c07384a154230de26c0a04f0ada76337deb91a8de6432d8faed0cb9e3c7d3bfa1c04052194bdb89d831d4a016c24d025cebd5b13e52174@209.145.57.126:30303,enode://e310cd64e2b58684bea4aaa9b54ac7bc028841abb76085d64182639f0eae3914396a1fa677eafcd645e813a2efe4765041bb99a50c56aeb9b2f38b3e08d51265@89.117.59.14:30303,enode://2abf2f26feb0974a8529acfbe6ba43b6985aa1637ddac0c0f9dc102d440d79065945b2e94cedab92ed6e9a46bac0055ee551ea252e0d41a4ad326f914963576c@65.20.108.189:30303,enode://43ce576e15fa13efda83de7b38ece6c60668236aac680f332664440085c10a576fb4a4c2eee427535af89f9f022c82cef8f13cd8410ca969a789d6bb9be5f721@178.18.248.45:30303,enode://0684105ac530a91e2f8c6cd6c48d9054a67c3bd8836aa21c3b19d38432693cd4d6f093bf206a96f3d6240bc4faad699ca6b21e7de011e05203286aaff14e8bcf@161.97.156.81:30303
# export CL_BOOTNODES=enr:-MS4QFd0PAkl8-OfzXauTCYytHWkX-QctXPTttdWLUMX-Dh2Y33MdJHwp8XE8ip3mfqwmeRd0My9Rg-zIVZ7WeFmvXIBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhEIqYU6EcXVpY4IjKYlzZWNwMjU2azGhA6AG3zZaFfFrG7flzYRz4QwTGwicn5TogSUX5I1uTUz4iHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo,enr:-MS4QACyngwZimSf7rPsZo-J2UYpinh84j8OJ0TGitzcv5lwYt6xYbzvAEGK-QT5Ij8Wt-XvCH05CUbvHlyA6j8o-jwBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhFl1PAeEcXVpY4IjKYlzZWNwMjU2azGhA7cZCdOfKzExRam2LEllYPR_msvjt9GmQsq-Lck5kzxsiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo,enr:-MS4QD5CdvaHWYmHnizpdkoHrC9Qk77enYexZsbQd5jBJWyLJDnTiHpX35adrqVwW9XW-XJhfG_BTc6LeRvnS20m1-EBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhNGROX6EcXVpY4IjKYlzZWNwMjU2azGhA7YMT9hQnpVuoV4S9M7enoZI6HUNINSKZq7O3QSPB1CFiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo,enr:-MS4QM9Kyjlq2oQAvFUVmy2ywh4Np98ZAMdya9857D1uyggMVv2qGaSI8K_WxdyJ4hPbmb85euUu6w9epChUqCbZBdoBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhFl1Ow6EcXVpY4IjKYlzZWNwMjU2azGhAvTU-ERldETa2H5FLcinXgtlJWBrThGUGXhkO88ejQ46iHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo,enr:-MS4QD0eMK-1u-Na4NNad7m2KBJkFkGGveKT72Kkclt1RzJYJgBlpnNK3i8XetVYBrhha4X6w4M1QfozNzLJQEezOWoBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhEEUbL2EcXVpY4IjKYlzZWNwMjU2azGhAu7UrJod5OmxWvzEGlmyPOxI5kxhr2671ihHA9K6U4ibiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo,enr:-MS4QEvSCkqisLXM39yTmcl5pglyPUOl5lshsYDt_cZQNYS_YnE5eVaoLd4f0xygadm96GsubyC4TofMIC_EZyQhEXgBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhLIS-C2EcXVpY4IjKYlzZWNwMjU2azGhAi-xhUDbmeqsJMuPwF4zpYFxbdaNvJtHYCC0yIDe-x9qiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo,enr:-MS4QKdytlMyGgA3u0ek5fwOAbY2ry-cCYpi4rimi5u2fBLrPLTbR4xlJTv9U61-ph1hqiucquBYgZeJm9ldDNoXOcgBh2F0dG5ldHOIAAAAAAAAAACEZXRoMpD-yjkaUAAAAf__________gmlkgnY0gmlwhKFhnFGEcXVpY4IjKYlzZWNwMjU2azGhA57Mqj6VJsCgfWHN1bxZ5L6k7kGyWfdjL2q9EdQhPb0FiHN5bmNuZXRzAIN0Y3CCIyiDdWRwgiMo
# export CL_TRUSTPEERS=16Uiu2HAmPRffDw5umGdUfvebjVbATB6JNHfhznwuzv2zPt673MCT,16Uiu2HAmQyj6x4vm8d8wdBCBFSamjbWaPxSbufLaz3enBoPXqTKH,16Uiu2HAmQudSVVrW6LNycAFxWsNbQUA6Kq2pTecK277XbHekQg8C,16Uiu2HAmBuPovVGKF2WmxGY3U6VuMaCMMhmfxnS9wnz9u5z4c7Eh,16Uiu2HAmBVy6tASse4XmpVrauEzbrFpTprBRXzz2dpDLM7NUyYF4,16Uiu2HAkxdr9BREQMnw1iZtdwCpvHQfuKnJ9hAsiwx38g92zcysF,16Uiu2HAmPLsmpphESD7juXytUB3JbiRNK4E136wLyphWB81VK4FW
