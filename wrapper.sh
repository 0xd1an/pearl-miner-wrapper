#!/bin/bash
# Wrapper: auto-restart + GPU keepalive
# Prevents Salad idle-kill by keeping GPU active during reconnect gaps

MINER_LOG="/tmp/miner.log"
RESTART_DELAY=3

# GPU warmup — small CUDA operation to show activity
gpu_keepalive() {
    while true; do
        python3 -c "
import ctypes, time, os
try:
    lib = ctypes.CDLL('libcuda.so.1')
    dev = ctypes.c_int(0)
    ctx = ctypes.c_void_p()
    if lib.cuInit(0) == 0 and lib.cuCtxCreate_v2(ctypes.byref(ctx), 0, dev) == 0:
        # Just keep context alive — shows GPU activity
        time.sleep(30)
        lib.cuCtxDestroy(ctx)
except:
    time.sleep(30)
" 2>/dev/null
        sleep 5
    done
}

# Start GPU keepalive in background
gpu_keepalive &
KEEPALIVE_PID=$!

# Cleanup on exit
cleanup() {
    kill $KEEPALIVE_PID 2>/dev/null
    kill $MINER_PID 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "[wrapper] Starting with auto-restart + GPU keepalive"
echo "[wrapper] PID: $$, keepalive PID: $KEEPALIVE_PID"

# Main restart loop
while true; do
    echo "[wrapper] $(date '+%H:%M:%S') Starting miner..."
    
    # Run original entrypoint
    /usr/local/bin/entrypoint.sh 2>&1 &
    MINER_PID=$!
    
    # Wait for miner to exit
    wait $MINER_PID
    EXIT_CODE=$?
    
    echo "[wrapper] $(date '+%H:%M:%S') Miner exited (code=$EXIT_CODE), restarting in ${RESTART_DELAY}s..."
    sleep $RESTART_DELAY
done
