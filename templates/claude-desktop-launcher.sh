#!/bin/bash

LOG_FILE="$HOME/.claude-desktop.log"

if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    OZONE_PLATFORM="--ozone-platform=wayland"
    WAYLAND_FLAGS="--enable-features=WaylandWindowDecorations,UseOzonePlatform"
else
    OZONE_PLATFORM="--ozone-platform=x11"
    WAYLAND_FLAGS=""
fi

exec electron /usr/lib64/claude-desktop/app.asar \
    $OZONE_PLATFORM \
    $WAYLAND_FLAGS \
    --enable-logging=file \
    --log-file="$LOG_FILE" \
    --log-level=INFO \
    --disable-gpu-sandbox \
    --no-sandbox \
    "$@" 2>&1 | tee -a "$LOG_FILE"
