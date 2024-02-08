#!/usr/bin/env bash
set -Eeuo pipefail


/etc/init.d/dbus start

# DISK_OPTS="$DISK_OPTS \
#   -object memory-backend-file,id=mem,size=4G,mem-path=/dev/shm,share=on \
#   -numa node,memdev=mem \
#   -chardev socket,id=char0,path=/tmp/virtiofsd.sock \
#   -device vhost-user-fs-pci,addr=0x6,id=fs,queue-size=1024,chardev=char0,tag=/opt"

# exute fs
# /etc/init.d/virtiofsd start

# DISK_OPTS="$DISK_OPTS \
#   -chardev spicevmc,id=charchannel0,name=vdagent \
#   -device virtserialport,chardev=charchannel0,id=channel0,name=com.redhat.spice.0"
  
  # -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
  # -device virtio-serial,bus=pcie.0,addr=0x6 \
  # -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"

  # -device virtio-serial-pci,addr=0x5 \
  # -chardev socket,id=ch0,path=/tmp/vhost-socket,server=on,wait=off \
  # -device virtserialport,name=org.example.ipinfo,id=ipinfo"

  # -device virtio-balloon-pci,id=balloon1,bus=pcie.0,addr=0x6 \
  # -chardev socket,id=ch0,path=/tmp/vhost-socket,server,nowait \
  # -device virtserialport,name=org.example.ipinfo,chardev=ch0,id=ipinfo"

  # -device virtio-serial \
  #   -chardev spicevmc,id=vdagent,name=vdagent \
  #   -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \

  # -device virtio-serial \

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