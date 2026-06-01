#!/bin/bash
# PearlHash wrapper: auto-restart + lightweight keepalive
# Uses pearl_miner_v11 binary for PearlHash pool

MINER_URL="https://pearlhash.xyz/downloads/pearl_miner_v11.tar.gz"
MINER_BIN="/tmp/pearl_miner_v11"
POOL_HOST="${PEARL_POOL_HOST:-84.32.220.219}"
POOL_PORT="${PEARL_POOL_PORT:-9000}"
WALLET="${PEARL_ADDRESS}"
WORKER="${PEARL_WORKER:-worker}"
RESTART_DELAY=3

# GPU keepalive — nvidia-smi only, no CUDA context
gpu_keepalive() {
    while true; do
        nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader 2>/dev/null > /dev/null
        sleep 25
    done
}

gpu_keepalive &
KEEPALIVE_PID=$!

cleanup() {
    kill $KEEPALIVE_PID 2>/dev/null
    kill $MINER_PID 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

# Download miner if needed
if [ ! -f "$MINER_BIN" ]; then
    echo "[wrapper] Downloading pearl_miner_v11..."
    curl -sLo /tmp/pearl_miner_v11.tar.gz "$MINER_URL"
    cd /tmp && tar xzf pearl_miner_v11.tar.gz 2>/dev/null
    # Find binary in extracted files
    BIN=$(find /tmp -name "pearl_miner*" -type f -executable 2>/dev/null | head -1)
    if [ -n "$BIN" ]; then
        mv "$BIN" "$MINER_BIN"
    fi
    chmod +x "$MINER_BIN" 2>/dev/null
fi

if [ ! -f "$MINER_BIN" ]; then
    echo "[wrapper] ERROR: pearl_miner_v11 not found, falling back to entrypoint.sh"
    exec /usr/local/bin/entrypoint.sh
fi

echo "[wrapper] PearlHash miner ready: $MINER_BIN"
echo "[wrapper] Pool: $POOL_HOST:$POOL_PORT"
echo "[wrapper] Wallet: $WALLET"
echo "[wrapper] Worker: $WORKER"

while true; do
    echo "[wrapper] $(date '+%H:%M:%S') Starting miner..."
    "$MINER_BIN" --pool "$POOL_HOST:$POOL_PORT" --wallet "$WALLET" --worker "$WORKER" 2>&1 &
    MINER_PID=$!
    wait $MINER_PID
    EXIT_CODE=$?
    echo "[wrapper] $(date '+%H:%M:%S') Miner exited (code=$EXIT_CODE), restarting in ${RESTART_DELAY}s..."
    sleep $RESTART_DELAY
done
