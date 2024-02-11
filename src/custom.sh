#!/usr/bin/env bash
set -Eeuo pipefail

: "${CUSTOM_OPTS:=""}"

CUSTOM_OPTS="$CUSTOM_OPTS \
  -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
  -device virtio-serial \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -qmp tcp:localhost:4444,server=on,wait=off"


return 0