#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${DISK_IO:="native"}"          # I/O Mode, can be set to 'native', 'threads' or 'io_turing'
: "${DISK_FMT:=""}"            # Disk file format, can be set to "raw" (default) or "qcow2"
: "${DISK_FLAGS:=""}"             # Specifies the options for use with the qcow2 disk format
: "${DISK_CACHE:="none"}"         # Caching mode, can be set to 'writeback' for better performance
: "${DISK_DISCARD:="on"}"         # Controls whether unmap (TRIM) commands are passed to the host.
: "${DISK_ROTATION:="1"}"         # Rotation rate, set to 1 for SSD storage and increase for HDD

DISK_OPTS="-object iothread,id=io2"
DISK_OPTS="$DISK_OPTS -device virtio-scsi-pci,id=scsi0,iothread=io2,addr=0x5"
DISK_OPTS="$DISK_OPTS -device scsi-cd,bus=scsi0.0,drive=cdrom0,bootindex=$BOOT_INDEX"

BOOT="$STORAGE/$BASE"

if [ -f "$BOOT" ]; then
  DISK_OPTS="$DISK_OPTS -drive id=cdrom0,if=none,format=raw,readonly=on,file=$BOOT"
else
  DISK_OPTS="$DISK_OPTS -drive id=cdrom0,if=none,format=raw,readonly=on,file=/dev/null"
fi

DRIVERS="$STORAGE/drivers.iso"
[ ! -f "$DRIVERS" ] && DRIVERS="/run/drivers.iso"

if [ -f "$DRIVERS" ]; then
  DISK_OPTS="$DISK_OPTS \
    -drive id=cdrom1,if=none,format=raw,readonly=on,file=$DRIVERS \
    -device ide-cd,drive=cdrom1"
fi

fmt2ext() {
  local DISK_FMT=$1

  case "${DISK_FMT,,}" in
    qcow2)
      echo "qcow2"
      ;;
    raw)
      echo "img"
      ;;
    *)
      error "Unrecognized disk format: $DISK_FMT" && exit 78
      ;;
  esac
}

ext2fmt() {
  local DISK_EXT=$1

  case "${DISK_EXT,,}" in
    qcow2)
      echo "qcow2"
      ;;
    img)
      echo "raw"
      ;;
    *)
      error "Unrecognized file extension: .$DISK_EXT" && exit 78
      ;;
  esac
}

getSize() {
  local DISK_FILE=$1
  local DISK_EXT DISK_FMT

  DISK_EXT=$(echo "${DISK_FILE//*./}" | sed 's/^.*\.//')
  DISK_FMT=$(ext2fmt "$DISK_EXT")

  case "${DISK_FMT,,}" in
    raw)
      stat -c%s "$DISK_FILE"
      ;;
    qcow2)
      qemu-img info "$DISK_FILE" -f "$DISK_FMT" | grep '^virtual size: ' | sed 's/.*(\(.*\) bytes)/\1/'
      ;;
    *)
      error "Unrecognized disk format: $DISK_FMT" && exit 78
      ;;
  esac
}

isCow() {
  local FS=$1

  if [[ "${FS,,}" == "xfs" || "${FS,,}" == "zfs" || "${FS,,}" == "btrfs" || "${FS,,}" == "bcachefs" ]]; then
    return 0
  fi

  return 1
}

createDisk() {
  local DISK_FILE=$1
  local DISK_SPACE=$2
  local DISK_DESC=$3
  local DISK_FMT=$4
  local FS=$5
  local DATA_SIZE DIR SPACE FA

  DATA_SIZE=$(numfmt --from=iec "$DISK_SPACE")

  rm -f "$DISK_FILE"

  if [[ "$ALLOCATE" != [Nn]* ]]; then

    # Check free diskspace
    DIR=$(dirname "$DISK_FILE")
    SPACE=$(df --output=avail -B 1 "$DIR" | tail -n 1)

    if (( DATA_SIZE > SPACE )); then
      local SPACE_GB=$(( (SPACE + 1073741823)/1073741824 ))
      error "Not enough free space to create a $DISK_DESC of $DISK_SPACE in $DIR, it has only $SPACE_GB GB available..."
      error "Please specify a smaller ${DISK_DESC^^}_SIZE or disable preallocation by setting ALLOCATE=N." && exit 76
    fi
  fi

  html "Creating a $DISK_DESC image..."
  info "Creating a $DISK_SPACE $DISK_TYPE $DISK_DESC image in $DISK_FMT format..."

  local FAIL="Could not create a $DISK_TYPE $DISK_FMT $DISK_DESC image of $DISK_SPACE ($DISK_FILE)"

  case "${DISK_FMT,,}" in
    raw)

      if isCow "$FS"; then
        if ! touch "$DISK_FILE"; then
          error "$FAIL" && exit 77
        fi
        { chattr +C "$DISK_FILE"; } || :
      fi

      if [[ "$ALLOCATE" == [Nn]* ]]; then

        # Create an empty file
        if ! truncate -s "$DATA_SIZE" "$DISK_FILE"; then
          rm -f "$DISK_FILE"
          error "$FAIL" && exit 77
        fi

      else

        # Create an empty file
        if ! fallocate -l "$DATA_SIZE" "$DISK_FILE"; then
          if ! truncate -s "$DATA_SIZE" "$DISK_FILE"; then
            rm -f "$DISK_FILE"
            error "$FAIL" && exit 77
          fi
        fi

      fi
      ;;
    qcow2)

      local DISK_PARAM="$DISK_ALLOC"
      isCow "$FS" && DISK_PARAM="$DISK_PARAM,nocow=on"
      [ -n "$DISK_FLAGS" ] && DISK_PARAM="$DISK_PARAM,$DISK_FLAGS"

      if ! qemu-img create -f "$DISK_FMT" -o "$DISK_PARAM" -- "$DISK_FILE" "$DATA_SIZE" ; then
        rm -f "$DISK_FILE"
        error "$FAIL" && exit 70
      fi
      ;;
  esac

  if isCow "$FS"; then
    FA=$(lsattr "$DISK_FILE")
    if [[ "$FA" != *"C"* ]]; then
      error "Failed to disable COW for $DISK_DESC image $DISK_FILE on ${FS^^} filesystem (returned $FA)"
    fi
  fi

  return 0
}

resizeDisk() {
  local DISK_FILE=$1
  local DISK_SPACE=$2
  local DISK_DESC=$3
  local DISK_FMT=$4
  local FS=$5
  local CUR_SIZE DATA_SIZE DIR SPACE

  CUR_SIZE=$(getSize "$DISK_FILE")
  DATA_SIZE=$(numfmt --from=iec "$DISK_SPACE")
  local REQ=$((DATA_SIZE-CUR_SIZE))
  (( REQ < 1 )) && error "Shrinking disks is not supported yet, please increase ${DISK_DESC^^}_SIZE." && exit 71

  if [[ "$ALLOCATE" != [Nn]* ]]; then

    # Check free diskspace
    DIR=$(dirname "$DISK_FILE")
    SPACE=$(df --output=avail -B 1 "$DIR" | tail -n 1)

    if (( REQ > SPACE )); then
      local SPACE_GB=$(( (SPACE + 1073741823)/1073741824 ))
      error "Not enough free space to resize $DISK_DESC to $DISK_SPACE in $DIR, it has only $SPACE_GB GB available.."
      error "Please specify a smaller ${DISK_DESC^^}_SIZE or disable preallocation by setting ALLOCATE=N." && exit 74
    fi
  fi

  local GB=$(( (CUR_SIZE + 1073741823)/1073741824 ))
  MSG="Resizing $DISK_DESC from ${GB}G to $DISK_SPACE..."
  info "$MSG" && html "$MSG"

  local FAIL="Could not resize the $DISK_TYPE $DISK_FMT $DISK_DESC image from ${GB}G to $DISK_SPACE ($DISK_FILE)"

  case "${DISK_FMT,,}" in
    raw)

      if [[ "$ALLOCATE" == [Nn]* ]]; then

        # Resize file by changing its length
        if ! truncate -s "$DATA_SIZE" "$DISK_FILE"; then
          error "$FAIL" && exit 75
        fi

      else

        # Resize file by allocating more space
        if ! fallocate -l "$DATA_SIZE" "$DISK_FILE"; then
          if ! truncate -s "$DATA_SIZE" "$DISK_FILE"; then
            error "$FAIL" && exit 75
          fi
        fi

      fi
      ;;
    qcow2)

      if ! qemu-img resize -f "$DISK_FMT" "--$DISK_ALLOC" "$DISK_FILE" "$DATA_SIZE" ; then
        error "$FAIL" && exit 72
      fi

      ;;
  esac

  return 0
}

convertDisk() {
  local SOURCE_FILE=$1
  local SOURCE_FMT=$2
  local DST_FILE=$3
  local DST_FMT=$4
  local DISK_BASE=$5
  local DISK_DESC=$6
  local FS=$7

  [ -f "$DST_FILE" ] && error "Conversion failed, destination file $DST_FILE already exists?" && exit 79
  [ ! -f "$SOURCE_FILE" ] && error "Conversion failed, source file $SOURCE_FILE does not exists?" && exit 79

  local TMP_FILE="$DISK_BASE.tmp"
  rm -f "$TMP_FILE"

  if [[ "$ALLOCATE" != [Nn]* ]]; then

    local DIR CUR_SIZE SPACE

    # Check free diskspace
    DIR=$(dirname "$TMP_FILE")
    CUR_SIZE=$(getSize "$SOURCE_FILE")
    SPACE=$(df --output=avail -B 1 "$DIR" | tail -n 1)

    if (( CUR_SIZE > SPACE )); then
      local SPACE_GB=$(( (SPACE + 1073741823)/1073741824 ))
      error "Not enough free space to convert $DISK_DESC to $DST_FMT in $DIR, it has only $SPACE_GB GB available..."
      error "Please free up some disk space or disable preallocation by setting ALLOCATE=N." && exit 76
    fi
  fi

  html "Converting $DISK_DESC to $DST_FMT..."
  info "Converting $DISK_DESC to $DST_FMT, please wait until completed..."

  local CONV_FLAGS="-p"
  local DISK_PARAM="$DISK_ALLOC"
  isCow "$FS" && DISK_PARAM="$DISK_PARAM,nocow=on"

  if [[ "$DST_FMT" != "raw" ]]; then
      if [[ "$ALLOCATE" == [Nn]* ]]; then
        CONV_FLAGS="$CONV_FLAGS -c"
      fi
      [ -n "$DISK_FLAGS" ] && DISK_PARAM="$DISK_PARAM,$DISK_FLAGS"
  fi

  # shellcheck disable=SC2086
  if ! qemu-img convert -f "$SOURCE_FMT" $CONV_FLAGS -o "$DISK_PARAM" -O "$DST_FMT" -- "$SOURCE_FILE" "$TMP_FILE"; then
    rm -f "$TMP_FILE"
    error "Failed to convert $DISK_TYPE $DISK_DESC image to $DST_FMT format in $DIR, is there enough space available?" && exit 79
  fi

  if [[ "$DST_FMT" == "raw" ]]; then
      if [[ "$ALLOCATE" != [Nn]* ]]; then
        # Work around qemu-img bug
        CUR_SIZE=$(stat -c%s "$TMP_FILE")
        if ! fallocate -l "$CUR_SIZE" "$TMP_FILE"; then
            error "Failed to allocate $CUR_SIZE bytes for $DISK_DESC image $TMP_FILE"
        fi
      fi
  fi

  rm -f "$SOURCE_FILE"
  mv "$TMP_FILE" "$DST_FILE"

  if isCow "$FS"; then
    FA=$(lsattr "$DST_FILE")
    if [[ "$FA" != *"C"* ]]; then
      error "Failed to disable COW for $DISK_DESC image $DST_FILE on ${FS^^} filesystem (returned $FA)"
    fi
  fi

  html "Conversion of $DISK_DESC completed..."
  info "Conversion of $DISK_DESC to $DST_FMT completed succesfully!"

  return 0
}

checkFS () {
  local FS=$1
  local DISK_FILE=$2
  local DISK_DESC=$3
  local DIR FA

  DIR=$(dirname "$DISK_FILE")
  [ ! -d "$DIR" ] && return 0

  if [[ "${FS,,}" == "overlay"* ]]; then
    info "Warning: the filesystem of $DIR is OverlayFS, this usually means it was binded to an invalid path!"
  fi

  if [[ "${FS,,}" == "fuse"* ]]; then
    info "Warning: the filesystem of $DIR is FUSE, this extra layer will negatively affect performance!"
  fi

  if isCow "$FS"; then
    if [ -f "$DISK_FILE" ]; then
      FA=$(lsattr "$DISK_FILE")
      if [[ "$FA" != *"C"* ]]; then
        info "Warning: COW (copy on write) is not disabled for $DISK_DESC image file $DISK_FILE, this is recommended on ${FS^^} filesystems!"
      fi
    fi
  fi

  return 0
}

addDisk () {
  local DISK_ID=$1
  local DISK_BASE=$2
  local DISK_EXT=$3
  local DISK_DESC=$4
  local DISK_SPACE=$5
  local DISK_INDEX=$6
  local DISK_ADDRESS=$7
  local DISK_FMT=$8
  local DISK_FILE="$DISK_BASE.$DISK_EXT"
  local DIR DATA_SIZE FS PREV_FMT PREV_EXT CUR_SIZE

  DIR=$(dirname "$DISK_FILE")
  [ ! -d "$DIR" ] && return 0

  [ -z "$DISK_SPACE" ] && DISK_SPACE="16G"
  DISK_SPACE=$(echo "${DISK_SPACE^^}" | sed 's/MB/M/g;s/GB/G/g;s/TB/T/g')
  DATA_SIZE=$(numfmt --from=iec "$DISK_SPACE")

  if (( DATA_SIZE < 1 )); then
    error "Invalid value for ${DISK_DESC^^}_SIZE: $DISK_SPACE" && exit 73
  fi

  FS=$(stat -f -c %T "$DIR")
  checkFS "$FS" "$DISK_FILE" "$DISK_DESC" || exit $?

  if ! [ -f "$DISK_FILE" ] ; then

    if [[ "${DISK_FMT,,}" != "raw" ]]; then
      PREV_FMT="raw"
    else
      PREV_FMT="qcow2"
    fi
    PREV_EXT=$(fmt2ext "$PREV_FMT")

    if [ -f "$DISK_BASE.$PREV_EXT" ] ; then
      convertDisk "$DISK_BASE.$PREV_EXT" "$PREV_FMT" "$DISK_FILE" "$DISK_FMT" "$DISK_BASE" "$DISK_DESC" "$FS" || exit $?
    fi
  fi

  if [ -f "$DISK_FILE" ]; then

    CUR_SIZE=$(getSize "$DISK_FILE")

    if (( DATA_SIZE > CUR_SIZE )); then
      resizeDisk "$DISK_FILE" "$DISK_SPACE" "$DISK_DESC" "$DISK_FMT" "$FS" || exit $?
    fi

  else

    createDisk "$DISK_FILE" "$DISK_SPACE" "$DISK_DESC" "$DISK_FMT" "$FS" || exit $?

  fi

  DISK_OPTS="$DISK_OPTS \
    -device virtio-scsi-pci,id=hw-$DISK_ID,iothread=io2,bus=pcie.0,addr=$DISK_ADDRESS \
    -drive file=$DISK_FILE,if=none,id=drive-$DISK_ID,format=$DISK_FMT,cache=$DISK_CACHE,aio=$DISK_IO,discard=$DISK_DISCARD,detect-zeroes=on \
    -device scsi-hd,bus=hw-$DISK_ID.0,channel=0,scsi-id=0,lun=0,drive=drive-$DISK_ID,id=$DISK_ID,rotation_rate=$DISK_ROTATION,bootindex=$DISK_INDEX \"
    -drive file=/opt/data/file.img,format=raw"

  return 0
}

addDevice () {

  local DISK_ID=$1
  local DISK_DEV=$2
  local DISK_DESC=$3
  local DISK_INDEX=$4
  local DISK_ADDRESS=$5

  [ -z "$DISK_DEV" ] && return 0
  [ ! -b "$DISK_DEV" ] && error "Device $DISK_DEV cannot be found! Please add it to the 'devices' section of your compose file." && exit 55

  DISK_OPTS="$DISK_OPTS \
    -device virtio-scsi-pci,id=hw-$DISK_ID,iothread=io2,bus=pcie.0,addr=$DISK_ADDRESS \
    -drive file=$DISK_DEV,if=none,id=drive-$DISK_ID,format=raw,cache=$DISK_CACHE,aio=$DISK_IO,discard=$DISK_DISCARD,detect-zeroes=on \
    -device scsi-hd,bus=hw-$DISK_ID.0,channel=0,scsi-id=0,lun=0,drive=drive-$DISK_ID,id=$DISK_ID,rotation_rate=$DISK_ROTATION,bootindex=$DISK_INDEX"

  return 0
}

html "Initializing disks..."

DISK1_FILE="$STORAGE/data"
DISK2_FILE="/storage2/data2"
DISK3_FILE="/storage3/data3"
DISK4_FILE="/storage4/data4"

if [ -z "$DISK_FMT" ]; then
  if [ -f "$DISK1_FILE.qcow2" ]; then
    DISK_FMT="qcow2"
  else
    DISK_FMT="raw"
  fi
fi

DISK_EXT=$(fmt2ext "$DISK_FMT")

if [ -z "$ALLOCATE" ]; then
  ALLOCATE="N"
fi

if [[ "$ALLOCATE" == [Nn]* ]]; then
  DISK_TYPE="growable"
  DISK_ALLOC="preallocation=off"
else
  DISK_TYPE="preallocated"
  DISK_ALLOC="preallocation=falloc"
fi

: "${DISK2_SIZE:=""}"
: "${DISK3_SIZE:=""}"
: "${DISK4_SIZE:=""}"

: "${DEVICE:=""}"        # Docker variables to passthrough a block device, like /dev/vdc1.
: "${DEVICE2:=""}"
: "${DEVICE3:=""}"
: "${DEVICE4:=""}"

if [ -n "$DEVICE" ]; then
  addDevice "userdata" "$DEVICE" "device" "3" "0xa" || exit $?
else
  addDisk "userdata" "$DISK1_FILE" "$DISK_EXT" "disk" "$DISK_SIZE" "3" "0xa" "$DISK_FMT" || exit $?
fi

if [ -n "$DEVICE2" ]; then
  addDevice "userdata2" "$DEVICE2" "device2" "4" "0xb" || exit $?
else
  addDisk "userdata2" "$DISK2_FILE" "$DISK_EXT" "disk2" "$DISK2_SIZE" "4" "0xb" "$DISK_FMT" || exit $?
fi

if [ -n "$DEVICE3" ]; then
  addDevice "userdata3" "$DEVICE3" "device3" "5" "0xc" || exit $?
else
  addDisk "userdata3" "$DISK3_FILE" "$DISK_EXT" "disk3" "$DISK3_SIZE" "5" "0xc" "$DISK_FMT" || exit $?
fi

if [ -n "$DEVICE4" ]; then
  addDevice "userdata4" "$DEVICE4" "device4" "6" "0xd" || exit $?
else
  addDisk "userdata4" "$DISK4_FILE" "$DISK_EXT" "disk4" "$DISK4_SIZE" "6" "0xd" "$DISK_FMT" || exit $?
fi

html "Initialized disks successfully..."
return 0