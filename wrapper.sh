#!/bin/bash
# Wrapper: auto-restart + GPU keepalive (non-blocking)
# Keepalive briefly touches GPU without holding CUDA context

MINER_LOG="/tmp/miner.log"
RESTART_DELAY=3

# GPU keepalive — brief touch only, does NOT hold context
gpu_keepalive() {
    while true; do
        # Quick nvidia-smi query — shows GPU is active without blocking
        nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader 2>/dev/null > /dev/null
        sleep 25
    done
}

# Start GPU keepalive in background
gpu_keepalive &
KEEPALIVE_PID=$!

cleanup() {
    kill $KEEPALIVE_PID 2>/dev/null
    kill $MINER_PID 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "[wrapper] Starting with auto-restart + lightweight keepalive"
echo "[wrapper] PID: $$, keepalive PID: $KEEPALIVE_PID"

while true; do
    echo "[wrapper] $(date '+%H:%M:%S') Starting miner..."
    
    /usr/local/bin/entrypoint.sh 2>&1 &
    MINER_PID=$!
    
    wait $MINER_PID
    EXIT_CODE=$?
    
    echo "[wrapper] $(date '+%H:%M:%S') Miner exited (code=$EXIT_CODE), restarting in ${RESTART_DELAY}s..."
    sleep $RESTART_DELAY
done
