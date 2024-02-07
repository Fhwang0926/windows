#!/usr/bin/env bash
set -Eeuo pipefail

APP="Windows"
BOOT_MODE="windows"
SUPPORT="https://github.com/dockur/windows"

cd /run

. reset.sh      # Initialize system
echo reset.sh init
. install.sh    # Run installation
echo install.sh init
. disk.sh       # Initialize disks
echo disk.sh init
. display.sh    # Initialize graphics
echo display.sh init
. network.sh    # Initialize network
echo network.sh init
. boot.sh       # Configure boot
echo boot.sh init
. proc.sh       # Initialize processor
echo proc.sh init
. custom.sh     # Configure custom
echo custom.sh init
. power.sh      # Configure shutdown
echo power.sh init
. config.sh     # Configure arguments
echo config.sh init

trap - ERR

info "Booting $APP using $VERS..."
[[ "$DEBUG" == [Yy1]* ]] && echo "Arguments: $ARGS" && echo

{ qemu-system-x86_64 ${ARGS:+ $ARGS} >"$QEMU_OUT" 2>"$QEMU_LOG"; rc=$?; } || :
(( rc != 0 )) && error "$(<"$QEMU_LOG")" && exit 15

terminal
tail -fn +0 "$QEMU_LOG" 2>/dev/null &
cat "$QEMU_TERM" 2> /dev/null | tee "$QEMU_PTY" &
wait $! || :

sleep 1 && finish 0
