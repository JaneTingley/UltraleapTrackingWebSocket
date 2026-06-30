#!/usr/bin/env sh
BINARY="./Ultraleap-Tracking-WS"
LOGFILE="${HOME}/Library/Logs/UltraleapTrackingWebSocket.log"

: > "$LOGFILE"

"$BINARY" > "$LOGFILE" 2>&1 &
CHILD_PID=$!

cleanup() {
    if kill -0 "$CHILD_PID" 2>/dev/null; then
        printf 'Shutting down Ultraleap‑Tracking‑WS (PID %s)…\n' "$CHILD_PID"
        kill "$CHILD_PID"
        sleep 2
        if kill -0 "$CHILD_PID" 2>/dev/null; then
            printf 'Force‑killing PID %s\n' "$CHILD_PID"
            kill -9 "$CHILD_PID"
        fi
    fi
}
trap cleanup EXIT

while :; do
    sleep 30
done
