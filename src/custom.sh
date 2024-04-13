#!/usr/bin/env bash
set -Eeuo pipefail

: "${CUSTOM_OPTS:=""}"
: "${CUSTOM_SCRIPT:="N"}"
: "${USER_DATA:="N"}"
: "${DOWNLOAD_DATA:="N"}"
: "${WIN_IP:=""}"
: "${VHOST_FD_CUSTOM:=""}"
: "${NET_UUID:=""}"
: "${FD:="50"}"
: "${NFS_UNMOUNT:="n"}"

# here is custom script for auto setting
# exucte network configuration to nat and 
# Docker environment variables

: "${MAC:=""}"
: "${DHCP:="N"}"
: "${HOST_PORTS:=""}"

: "${VM_NET_DEV:=""}"
: "${VM_NET_TAP:="qemu_host"}"
: "${VM_NET_MAC:="$MAC"}"
: "${VM_NET_HOST:="QEMU"}"

: "${DNSMASQ_OPTS:=""}"
: "${DNSMASQ:="/usr/sbin/dnsmasq"}"
: "${DNSMASQ_CONF_DIR:="/etc/dnsmasq.d"}"

VM_NET_TAP="qemu_host"
VM_NET_HOST="qemu_host"
ADD_ERR="Please add the following setting to your container:"

# ######################################
#  Functions
# ######################################

configureDNS() {

  # dnsmasq configuration:
  DNSMASQ_OPTS="$DNSMASQ_OPTS --dhcp-range=${VM_NET_IP%.*}.2,${VM_NET_IP%.*}.10 --dhcp-host=$VM_NET_MAC,,$VM_NET_IP,$VM_NET_HOST,infinite --dhcp-option=option:netmask,255.255.255.0"

  # Create lease file for faster resolve
  echo "0 $VM_NET_MAC $VM_NET_IP $VM_NET_HOST 01:$VM_NET_MAC" > /var/lib/misc/dnsmasq.leases
  chmod 644 /var/lib/misc/dnsmasq.leases

  # Set DNS server and gateway
  DNSMASQ_OPTS="$DNSMASQ_OPTS --dhcp-option=option:dns-server,${VM_NET_IP%.*}.1 --dhcp-option=option:router,${VM_NET_IP%.*}.1"

  # Add DNS entry for container
  DNSMASQ_OPTS="$DNSMASQ_OPTS --address=/host.lan/${VM_NET_IP%.*}.1"

  DNSMASQ_OPTS=$(echo "$DNSMASQ_OPTS" | sed 's/\t/ /g' | tr -s ' ' | sed 's/^ *//')
  [[ "$DEBUG" == [Yy1]* ]] && set -x

  if ! $DNSMASQ ${DNSMASQ_OPTS:+ $DNSMASQ_OPTS}; then
    error "Failed to start dnsmasq, reason: $?" && exit 29
  fi
  { set +x; } 2>/dev/null
  [[ "$DEBUG" == [Yy1]* ]] && echo

  return 0
}

configureNAT() {

  # Create the necessary file structure for /dev/net/tun
  if [ ! -c /dev/net/tun ]; then
    [ ! -d /dev/net ] && mkdir -m 755 /dev/net
    if mknod /dev/net/tun c 10 200; then
      chmod 666 /dev/net/tun
    fi
  fi

  if [ ! -c /dev/net/tun ]; then
    error "TUN device missing. $ADD_ERR --cap-add NET_ADMIN" && exit 25
  fi

  # Check port forwarding flag
  if [[ $(< /proc/sys/net/ipv4/ip_forward) -eq 0 ]]; then
    { sysctl -w net.ipv4.ip_forward=1 ; rc=$?; } || :
    if (( rc != 0 )); then
      error "IP forwarding is disabled. $ADD_ERR --sysctl net.ipv4.ip_forward=1" && exit 24
    fi
  fi

  # Create a bridge with a static IP for the VM guest
  VM_NET_IP='20.20.20.21'
  # VM_NET_HOST='127.0.1.1'

  { ip link add dev dockerbridge type bridge ; rc=$?; } || :

  if (( rc != 0 )); then
    ifconfig
    error "ret : $rc"
    error "Failed to create bridge. $ADD_ERR --cap-add NET_ADMIN" && exit 23
  fi

  ip address add ${VM_NET_IP%.*}.1/24 broadcast ${VM_NET_IP%.*}.255 dev dockerbridge

  while ! ip link set dockerbridge up; do
    info "Waiting for IP address to become available..."
    sleep 2
  done

  # QEMU Works with taps, set tap to the bridge created
  info "trying $VM_NET_TAP"
  ip tuntap add dev "$VM_NET_TAP" mode tap

  while ! ip link set "$VM_NET_TAP" up promisc on; do
    info "Waiting for TAP to become available..."
    sleep 2
  done

  ip link set dev "$VM_NET_TAP" master dockerbridge

  # Add internet connection to the VM
  update-alternatives --set iptables /usr/sbin/iptables-legacy > /dev/null
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy > /dev/null

  exclude=$(getPorts "$HOST_PORTS")

  iptables -t nat -A POSTROUTING -o "$VM_NET_DEV" -j MASQUERADE
  # shellcheck disable=SC2086
  iptables -t nat -A PREROUTING -i "$VM_NET_DEV" -d "$IP" -p tcp${exclude} -j DNAT --to "$VM_NET_IP"
  iptables -t nat -A PREROUTING -i "$VM_NET_DEV" -d "$IP" -p udp  -j DNAT --to "$VM_NET_IP"

  if (( KERNEL > 4 )); then
    # Hack for guest VMs complaining about "bad udp checksums in 5 packets"
    iptables -A POSTROUTING -t mangle -p udp --dport bootpc -j CHECKSUM --checksum-fill || true
  fi

  CUSTOM_OPTS="-netdev tap,ifname=$VM_NET_TAP,script=no,downscript=no,id=hostnet1"
  VHOST_FD_CUSTOM=$((FD + 1))
  info "CUSTOM VHOST_FD : $VHOST_FD_CUSTOM"

  # VHOST_FD_CUSTOM=50
  { eval "exec $VHOST_FD_CUSTOM>>/dev/vhost-net-custom;" rc=$?; } 2>/dev/null || :
  # { exec $VHOST_FD_CUSTOM>>/dev/vhost-net-custom; rc=$?; }
  (( rc == 0 )) && CUSTOM_OPTS="$CUSTOM_OPTS,vhost=on,vhostfd=$VHOST_FD_CUSTOM"
  # FD=$((VHOST_FD_CUSTOM + 2))

  configureDNS

  ifconfig

  return 0
}

closeNetworkCustom() {

  # Shutdown nginx
  nginx -s stop 2> /dev/null
  fWait "nginx"

  # exec 30<&- || true
  # exec 50<&- || true
  eval "exec $VHOST_FD_CUSTOM<&-" || true

  local pid="/var/run/dnsmasq.pid"
  [ -f "$pid" ] && pKill "$(<"$pid")"

  ip link set "$VM_NET_TAP" down promisc off || true
  ip link delete "$VM_NET_TAP" || true

  # ip link set dockerbridge down || true
  # ip link delete dockerbridge || true

  return 0
}

getInfo() {

  if [ -z "$VM_NET_DEV" ]; then
    # Automaticly detect the default network interface
    VM_NET_DEV=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
    [ -z "$VM_NET_DEV" ] && VM_NET_DEV="eth0"
  fi

  if [ ! -d "/sys/class/net/$VM_NET_DEV" ]; then
    error "Network interface '$VM_NET_DEV' does not exist inside the container!"
    error "$ADD_ERR -e \"VM_NET_DEV=NAME\" to specify another interface name." && exit 27
  fi

  # if [ -z "$WIN_IP" ]; then
  #   # Generate MAC address based on Docker container ID in hostname
  #   WIN_IP=$(date)
  # fi

  # if [ -z "$MAC" ]; then
    # Generate MAC address based on Docker container ID in hostname
    MAC=$(echo "$HOST""$WIN_IP" | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
    # MAC=$(echo "$HOST""$WIN_IP" | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
    # NET_UUID=$(echo "$HOST""$WIN_IP""$(date)" | md5sum)
  # fi

  VM_NET_MAC="${MAC^^}"
  VM_NET_MAC="${VM_NET_MAC//-/:}"

  if [[ ${#VM_NET_MAC} == 12 ]]; then
    m="$VM_NET_MAC"
    VM_NET_MAC="${m:0:2}:${m:2:2}:${m:4:2}:${m:6:2}:${m:8:2}:${m:10:2}"
  fi

  if [[ ${#VM_NET_MAC} != 17 ]]; then
    error "Invalid MAC address: '$VM_NET_MAC', should be 12 or 17 digits long!" && exit 28
  fi

  GATEWAY=$(ip r | grep default | awk '{print $3}')
  IP=$(ip address show dev "$VM_NET_DEV" | grep inet | awk '/inet / { print $2 }' | cut -f1 -d/)

  return 0
}


configureSMBLocal () {

  SHARE="/utils"

  mkdir -p "$SHARE"
  chmod -R 777 "$SHARE"

  SAMBA_CONF="/etc/samba/smb.conf"

  {      echo "[global]"
          echo "    server string = Dockur"
          echo "    netbios name = dockur"
          echo "    workgroup = WORKGROUP"
          echo "    interfaces = dockerbridge"
          echo "    bind interfaces only = yes"
          echo "    security = user"
          echo "    guest account = nobody"
          echo "    map to guest = Bad User"
          echo "    server min protocol = SMB2"
          echo ""
          echo "    # disable printing services"
          echo "    load printers = no"
          echo "    printing = bsd"
          echo "    printcap name = /dev/null"
          echo "    disable spoolss = yes"
          echo ""
          echo "[common]"
          echo "    path = $SHARE"
          echo "    comment = Shared"
          echo "    writable = yes"
          echo "    guest ok = yes"
          echo "    guest only = yes"
          echo "    force user = root"
          echo "    force group = root"
  } > "$SAMBA_CONF"

  if [[ "$USER_DATA" == [Yy1]* ]]; then
    {
      echo "[user]"
      echo "    path = /opt/data"
      echo "    comment = Shared"
      echo "    writable = yes"
      echo "    guest ok = yes"
      echo "    guest only = yes"
      echo "    force user = root"
      echo "    force group = root"
    }  >> "$SAMBA_CONF"

    {
      echo "[pcap]"
      echo "    path = /opt/pcap"
      echo "    comment = Pcap"
      echo "    writable = yes"
      echo "    guest ok = yes"
      echo "    guest only = yes"
      echo "    force user = root"
      echo "    force group = root"
    }  >> "$SAMBA_CONF"
  fi

  if [[ "$DOWNLOAD_DATA" == [Yy1]* ]]; then
    {
      echo "[download]"
      echo "    path = /opt/download"
      echo "    comment = DOWNLOAD_DATA"
      echo "    writable = yes"
      echo "    guest ok = yes"
      echo "    guest only = yes"
      echo "    force user = root"
      echo "    force group = root"
    }  >> "$SAMBA_CONF"

  fi

  # } | unix2dos > "$SHARE/auto_ip.bat"
  WIN_GW=${WIN_IP%.*}.1
  WIN_SN="255.255.255.0"
  sed -i "s/WIN_IP/$WIN_IP/g" $SHARE/auto_ip_set.bat
  sed -i "s/WIN_SN/$WIN_SN/g" $SHARE/auto_ip_set.bat
  sed -i "s/WIN_GW/$WIN_GW/g" $SHARE/auto_ip_set.bat

  sed -i "s/WIN_IP/$WIN_IP/g" $SHARE/auto_ip_set_win7.bat
  sed -i "s/WIN_SN/$WIN_SN/g" $SHARE/auto_ip_set_win7.bat
  sed -i "s/WIN_GW/$WIN_GW/g" $SHARE/auto_ip_set_win7.bat

  # { cat "$SHARE/auto_ip_rollback.bat" } | unix2dos > "$SHARE/auto_ip_rollback.bat"
  # { cat "$SHARE/startup.bat" } | unix2dos > "$SHARE/startup.bat"
  # { cat "$SHARE/auto_ip_set.bat" } | unix2dos > "$SHARE/auto_ip_set.bat"

  {
    echo "ping 1.1.1.1 -n 3"
  } | unix2dos > "$SHARE/ping.bat"

  # isXP="N"

  # if [ -f "$STORAGE/windows.old" ]; then
  #   MT=$(<"$STORAGE/windows.old")
  #   if [[ "${MT,,}" == "pc-q35-2"* ]]; then
  #     isXP="Y"
  #   fi
  # fi

  # if [[ "$isXP" == [Yy1]* ]]; then
  #   # Enable NetBIOS on Windows XP
  #   ! nmbd && nmbd --debug-stdout
  # else
  #   # Enable Web Service Discovery
  #   wsdd -i dockerbridge -p -n "host.lan" &
  # fi

  if [[ "$NFS_UNMOUNT" != [Yy1]* ]]; then

    info "starting smbd"
    ! smbd && smbd --debug-stdout
    info "started smbd"

    info "starting wsdd"
    wsdd -i dockerbridge -p -n "host.lan" & 
    info "started wsdd"

    info "set auto remove nfs"
  
  fi

  

  
}

# ######################################
#  Configure CUSTOM
# ######################################

if [ ! -c /dev/vhost-net-custom ]; then
  if mknod /dev/vhost-net-custom c 10 238; then
    chmod 660 /dev/vhost-net-custom
  fi
fi

getInfo
html "Initializing custom network..."

if [[ "$DEBUG" == [Yy1]* ]]; then
  info "Host: $HOST  IP: $IP  Gateway: $GATEWAY  Interface: $VM_NET_DEV  MAC: $VM_NET_MAC"
  [ -f /etc/resolv.conf ] && grep '^nameserver*' /etc/resolv.conf
  echo
fi

info "CUSTOM_SCRIPT : $CUSTOM_SCRIPT"

if [[ "$CUSTOM_SCRIPT" == [Yy1]* ]]; then
  # Configuration for static IP
  configureNAT
  configureSMBLocal

  # mapping
  CUSTOM_OPTS="$CUSTOM_OPTS -device virtio-net-pci,romfile=,netdev=hostnet1,mac=$VM_NET_MAC,id=net1"
  info "CUSTOM_OPTS: $CUSTOM_OPTS"
else
  info "CUSTOM_SCRIPT: Disabled"
fi

html "Initialized custom network successfully..."

return 0