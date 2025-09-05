#!/usr/bin/env bash

git pull && docker image build -t win:base .
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:2016
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:2022
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:win10
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:win11
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:win7
echo done!

# docker run -it --rm --name windows -h 3vi_windows -p 8006:8006 --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -e RAM_SIZE="16G" -e CPU_CORES="8" -e USERNAME="3vi" -e PASSWORD="3vi" -e LANGUAGE="KR" -e DISK_SIZE="50G" -e DISK_FMT="qcow2" -v "/data/win/base/11e:/storage" --stop-timeout 120 dockurr/windows
# docker commit windows harbor.donghwa.dev:4443/seo/windows:11e
# docker image tag win:base harbor.donghwa.dev:4443/seo/windows:11e


docker run -it --rm --name windows_11e \
-h 3vi_windows_11e \
--device=/dev/kvm \
--device=/dev/net/tun \
--cap-add NET_ADMIN \
-p 8006:8006 \
-e RAM_SIZE="16G" \
-e CPU_CORES="8" \
-e USERNAME="3vi" \
-e PASSWORD="3vi" \
-e LANGUAGE="KR" \
-e DISK_SIZE="50G" \
-e DISK_FMT="qcow2" \
-v "/data/win/base/11e:/storage" \
--stop-timeout 120 dockurr/windows


# NFS_LOCAL="1" # common

# Clean up any leftover network interfaces before running
echo "Cleaning up leftover network interfaces..."
sudo ip link show | grep -E "br[0-9]+|tap[0-9]+" | awk -F: '{print $2}' | tr -d ' ' | while read iface; do
  if [ -n "$iface" ]; then
    echo "Removing interface: $iface"
    sudo ip link delete "$iface" 2>/dev/null || true
  fi
done

docker run -it --rm --name windows_11e \
-h 3vi_windows_11e \
--device=/dev/kvm \
--device=/dev/net/tun \
--cap-add NET_ADMIN \
--cap-add SYS_ADMIN \
--privileged \
-p 8006:8006 \
-e RAM_SIZE="16G" \
-e CPU_CORES="8" \
-e USERNAME="3vi" \
-e PASSWORD="3vi" \
-e LANGUAGE="KR" \
-e DISK_SIZE="50G" \
-e DISK_FMT="qcow2" \
-e NFS_LOCAL="1" \
-e CUSTOM_SCRIPT="Y" \
-e WIN_IP="10.0.1.12" \
-v "/data/win/base/11e:/storage" \
--stop-timeout 120 harbor.donghwa.dev:4443/seo/windows:11e