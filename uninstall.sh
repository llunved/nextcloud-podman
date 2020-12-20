#!/bin/bash


set -x

SERVICE=$IMAGE

env

# Make sure the host is mounted
if [ ! -d /host/etc -o ! -d /host/proc -o ! -d /host/var/run ]; then
	    echo "Host file system is not mounted at /host" >&2
	        exit 1
fi

# Remove the container and unit file

chroot /host systemctl --wait stop ${NAME}
chroot /host systemctl disable ${NAME}
chroot /host systemctl disable ${NAME}-cron.service
chroot /host systemctl disable ${NAME}-cron.timer
chroot /host rm -fv /etc/systemd/system/${NAME}*.service
chroot /host rm -fv /etc/systemd/system/${NAME}*.timer
chroot /host /usr/bin/podman rm ${NAME}

