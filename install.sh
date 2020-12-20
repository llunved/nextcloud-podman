#!/bin/bash


set -x

SERVICE=$IMAGE

env

# Make sure the host is mounted
if [ ! -d /host/etc -o ! -d /host/proc -o ! -d /host/var/run ]; then
	    echo "Host file system is not mounted at /host" >&2
	        exit 1
fi

# Make sure that we have required directories in the host
for CUR_DIR in /host${LOGDIR}/${NAME} /host${DATADIR}/${NAME} /host${CONFDIR}/${NAME}/nextcloud /host${CONFDIR}/${NAME}/php ; do
    if [ ! -d $CUR_DIR ]; then
        mkdir -p $CUR_DIR
	if [ "$CUR_DIR" == "/host${CONFDIR}/${NAME}/nextcloud" ] ; then
	    cp -Rv /etc/nextcloud.default/* /host${CONFDIR}/${NAME}/nextcloud/
       
	elif [ "$CUR_DIR" == "/host${CONFDIR}/${NAME}/php" ] ; then
	    cp -Rv /etc/php.default/* /host${CONFDIR}/${NAME}/php/
     
	elif [ "$CUR_DIR" == "/host${DATADIR}/${NAME}" ] ; then
	    cp -Rv ${DATADIR}/${NAME}.default/* /host${DATADIR}/${NAME}/
	fi
        chmod 775 $CUR_DIR
	chgrp -R 0 $CUR_DIR
    fi
done    


chroot /host /usr/bin/podman create --name ${NAME} -p 9000:9000 -v ${DATADIR}/${NAME}:/var/lib/${NAME}:rw,z -v ${CONFDIR}/${NAME}/nextcloud:/etc/nextcloud:rw,z -v ${CONFDIR}/${NAME}/php:/etc/php:rw,z -v ${LOGDIR}/${NAME}:/var/log/${NAME}:rw,z ${IMAGE}
chroot /host sh -c "/usr/bin/podman generate systemd --restart-policy=always -t 1 ${NAME} > /etc/systemd/system/${NAME}.service"

cat > /host/etc/systemd/system/${NAME}-cron.service <<EOF
[Unit]
Description=Cron for nextcloud background jobs

[Service]
Type=oneshot
ExecStart=/usr/bin/php -f /usr/share/nextcloud/cron.php
User=apache
EOF


cat > /host/etc/systemd/system/${NAME}-cron.timer <<EOF
[Unit]
Description=This triggers the nextcloud cron service

[Timer]
OnBootSec=5min
OnUnitInactiveSec=15min

[Install]
WantedBy=timers.target
EOF

chroot /host sh -c "systemctl daemon-reload \
                    && systemctl enable ${NAME} \
                    && systemctl enable ${NAME}-cron.timer"


