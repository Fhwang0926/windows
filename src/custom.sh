#!/usr/bin/env bash
set -Eeuo pipefail

# DISK_OPTS="$DISK_OPTS \
#     -chardev socket,id=char0,path=/tmp/virtiofs_socket \"
#     -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=my_virtiofs \
#     -m 4G -object memory-backend-file,id=mem,size=4G,mem-path=/dev/shm,share=on -numa node,memdev=mem"

DISK_OPTS="$DISK_OPTS \
  -object memory-backend-file,id=mem,size=4G,mem-path=/dev/shm,share=on \
  -numa node,memdev=mem \
  -chardev socket,id=char0,path=/tmp/virtiofsd.sock \
  -device vhost-user-fs-pci,addr=0x6,id=fs,queue-size=1024,chardev=char0,tag=/opt"

# DISK_OPTS="-kernel path/to/bzImage $DISK_OPTS \
#   -append rootfstype=virtiofs /tmp/virtiofsd.sock rw"

# exute fs
/usr/libexec/virtiofsd --socket-path=/tmp/virtiofsd.sock --shared-dir /opt --cache auto --name=virtiofsd

# bash -c "/usr/libexec/virtiofsd --socket-path=/tmp/virtiofsd.sock --shared-dir /opt --cache auto" &


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

html "Initialized custom successfully..."

return 0