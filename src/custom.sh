#!/usr/bin/env bash
set -Eeuo pipefail

: "${CUSTOM_OPTS:=""}"

# start service

# CUSTOM_OPTS="$CUSTOM_OPTS \
#   -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
#   -device virtio-serial \
#   -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
#   -qmp tcp:localhost:4444,server=on,wait=off"


# Docker environment variables

: "${MAC:=""}"
: "${DHCP:="N"}"
: "${HOST_PORTS:=""}"

: "${VM_NET_DEV:=""}"
: "${VM_NET_TAP:="qemu"}"
: "${VM_NET_MAC:="$MAC"}"
: "${VM_NET_HOST:="QEMU"}"

: "${DNSMASQ_OPTS:=""}"
: "${DNSMASQ:="/usr/sbin/dnsmasq"}"
: "${DNSMASQ_CONF_DIR:="/etc/dnsmasq.d"}"

ADD_ERR="Please add the following setting to your container:"

# ######################################
#  Functions
# ######################################

configureDNS() {

  # dnsmasq configuration:
  DNSMASQ_OPTS="$DNSMASQ_OPTS --dhcp-range=$VM_NET_IP,$VM_NET_IP --dhcp-host=$VM_NET_MAC,,$VM_NET_IP,$VM_NET_HOST,infinite --dhcp-option=option:netmask,255.255.255.0"

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
  VM_NET_IP='127.0.1.2'
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
  ifconfig
  ip tuntap add dev "$VM_NET_TAP" mode tap

  while ! ip link set "$VM_NET_TAP" up promisc on; do
    info "Waiting for TAP to become available..."
    sleep 2
  done

  ip link set dev "$VM_NET_TAP" master dockerbridge

  # Add internet connection to the VM
  update-alternatives --set iptables /usr/sbin/iptables-legacy > /dev/null
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy > /dev/null

  exclude=$("$HOST_PORTS")

  iptables -t nat -A POSTROUTING -o "$VM_NET_DEV" -j MASQUERADE
  # shellcheck disable=SC2086
  iptables -t nat -A PREROUTING -i "$VM_NET_DEV" -d "$IP" -p tcp${exclude} -j DNAT --to "$VM_NET_IP"
  iptables -t nat -A PREROUTING -i "$VM_NET_DEV" -d "$IP" -p udp  -j DNAT --to "$VM_NET_IP"

  if (( KERNEL > 4 )); then
    # Hack for guest VMs complaining about "bad udp checksums in 5 packets"
    iptables -A POSTROUTING -t mangle -p udp --dport bootpc -j CHECKSUM --checksum-fill || true
  fi

  CUSTOM_OPTS="-netdev tap,ifname=$VM_NET_TAP,script=no,downscript=no,id=hostnet1"

  { exec 40>>/dev/vhost-net; rc=$?; } 2>/dev/null || :
  (( rc == 0 )) && CUSTOM_OPTS="$CUSTOM_OPTS,vhost=on,vhostfd=50"

  configureDNS

  return 0
}

closeNetworkCustom() {

  # Shutdown nginx
  nginx -s stop 2> /dev/null
  fWait "nginx"

  exec 30<&- || true
  exec 40<&- || true

  local pid="/var/run/dnsmasq.pid"
  [ -f "$pid" ] && pKill "$(<"$pid")"

  ip link set "$VM_NET_TAP" down promisc off || true
  ip link delete "$VM_NET_TAP" || true

  ip link set dockerbridge down || true
  ip link delete dockerbridge || true

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

  if [ -z "$MAC" ]; then
    # Generate MAC address based on Docker container ID in hostname
    MAC=$(echo "$HOST""$(date)" | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
  fi

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

# ######################################
#  Configure Network
# ######################################

if [ ! -c /dev/vhost-net ]; then
  if mknod /dev/vhost-net c 10 238; then
    chmod 660 /dev/vhost-net
  fi
fi

getInfo
html "Initializing custom network..."

if [[ "$DEBUG" == [Yy1]* ]]; then
  info "Host: $HOST  IP: $IP  Gateway: $GATEWAY  Interface: $VM_NET_DEV  MAC: $VM_NET_MAC"
  [ -f /etc/resolv.conf ] && grep '^nameserver*' /etc/resolv.conf
  echo
fi

# Configuration for static IP
configureNAT

CUSTOM_OPTS="$CUSTOM_OPTS -device virtio-net-pci,romfile=,netdev=hostnet1,mac=$VM_NET_MAC,id=net1"

info "$CUSTOM_OPTS"

html "Initialized custom network successfully..."

# CUSTOM_OPTS="$CUSTOM_OPTS \
#   -netdev user,id=usernet -device virtio-net,netdev=usernet"

# libvirtd OPTION

# CUSTOM_OPTS="$CUSTOM_OPTS \
#   -netdev user,id=usernet -device virtio-net,netdev=usernet"

# mkdir -p /run/dbus
# dbus-daemon --system
# virsh --connect qemu:///system
# libvirtd
# virtlogd
# virsh net-autostart default
# virsh net-start default

# virsh net-list --all
return 0