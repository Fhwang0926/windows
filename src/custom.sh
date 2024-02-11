#!/usr/bin/env bash
set -Eeuo pipefail

: "${CUSTOM_OPTS:=""}"

# start service
mkdir -p /run/dbus
dbus-daemon --system

# CUSTOM_OPTS="$CUSTOM_OPTS \
#   -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
#   -device virtio-serial \
#   -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
#   -qmp tcp:localhost:4444,server=on,wait=off"


CUSTOM_OPTS="$CUSTOM_OPTS \
  -netdev user,id=usernet -device virtio-net,netdev=usernet"

# virsh --connect qemu:///system
# libvirtd
# virtlogd
# virsh net-autostart default
# virsh net-start default
return 0