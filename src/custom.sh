#!/usr/bin/env bash
set -Eeuo pipefail

# DISK_OPTS="$DISK_OPTS \
#   -object memory-backend-file,id=mem,size=4G,mem-path=/dev/shm,share=on \
#   -numa node,memdev=mem \
#   -chardev socket,id=char0,path=/tmp/virtiofsd.sock \
#   -device vhost-user-fs-pci,addr=0x6,id=fs,queue-size=1024,chardev=char0,tag=/opt"

# exute fs
# /etc/init.d/virtiofsd start

DISK_OPTS="$DISK_OPTS \
  -device virtio-serial \
  -device virtio-serial-pci \
  -chardev socket,id=ch0,path=/tmp/vhost-socket,server,nowait \
  -device virtserialport,name=org.example.ipinfo,chardev=ch0,id=ipinfo"


# if [ -n "$DATA_PATH" ]; then

#   # if [ ! -d "$DATA_PATH/data.img" ]; then
#   #   # create
#   #   qemu-img create $DATA_PATH/data.img 4G
#   # fi
#   # DISK_OPTS="$DISK_OPTS \
#   #     -nic user,smb=$DATA_PATH \"
#   #     -net nic,model=virtio"

#   # info "check opt $DISK_OPTS"
# fi

info "Initialized custom successfully..."

return 0