#!/bin/sh
# /etc/init.d/virtiofsd: start or stop the virtiofsd daemon

case "$1" in
    start)
        echo "Starting virtiofsd..."
        /usr/libexec/virtiofsd --socket-path=/var/run/libvirt/libvirt-sock --shared-dir /opt --cache auto & 
        echo "Started virtiofsd..."
        # /usr/libexec/virtiofsd --socket-path=/var/run/virtiofsd.sock --source=/path/to/share --name=virtiofsd
        ;;
    stop)
        echo "Stopping virtiofsd..."
        killall virtiofsd
        ;;
    *)
        echo "Usage: /etc/init.d/virtiofsd {start|stop}"
        exit 1
        ;;
esac

exit 0