#!/bin/bash

export VOL_PREFIX=/var/lib/pod-web_ext

podman pod create --name web_ext -p 443:443 -p 80:80 -p 8443:8443 --share net,ipc

mkdir -p $VOL_PREFIX/etc/nextcloud $VOL_PREFIX/etc/php $VOL_PREFIX/etc/php $VOL_PREFIX/var/log/nextcloud $VOL_PREFIX/var/lib/nextcloud $VOL_PREFIX/usr/share/doc/nextcloud $VOL_PREFIX/usr/share/nextcloud

podman run --pod=web_ext -ti --rm --name nextcloud -v $VOL_PREFIX/etc/nextcloud:/etc/nextcloud:rw,Z -v $VOL_PREFIX/etc/php:/etc/php:rw,Z -v $VOL_PREFIX/var/lib/nextcloud:/var/lib/nextcloud:rw,Z -v $VOL_PREFIX/var/log/nextcloud:/var/log/nextcloud:rw,Z -v $VOL_PREFIX/usr/share/doc/nextcloud:/usr/share/doc/nextcloud:rw,Z -v $VOL_PREFIX/usr/share/nextcloud:/usr/share/nextcloud:rw,Z x86_64/httpd /sbin/init_container.sh

mkdir -p $VOL_PREFIX/etc/httpd $VOL_PREFIX/var/www $VOL_PREFIX/var/www  $VOL_PREFIX/usr/share/doc/httpd $VOL_PREFIX/usr/share/httpd $VOL_PREFIX/var/log/httpd

podman run --pod=web_ext -ti --rm --name httpd -v $VOL_PREFIX/etc/httpd:/etc/httpd:rw,Z -v $VOL_PREFIX/var/www:/var/www:rw,Z -v $VOL_PREFIX/var/log/httpd:/var/log/httpd:rw,Z -v $VOL_PREFIX/usr/share/doc/httpd:/usr/share/doc/httpd:rw,Z -v $VOL_PREFIX/usr/share/httpd:/usr/share/httpd:rw,Z x86_64/httpd /sbin/init_container.sh 

podman run --pod=web_ext -d --name nextcloud --label "io.containers.autoupdate=image" -v $VOL_PREFIX/etc/nextcloud:/etc/nextcloud:ro,Z -v $VOL_PREFIX/etc/php:/etc/php:ro,Z -v $VOL_PREFIX/var/lib/nextcloud:/var/lib/nextcloud:rw,Z -v $VOL_PREFIX/var/log/nextcloud:/var/log/nextcloud:rw,Z -v $VOL_PREFIX/usr/share/doc/nextcloud:/usr/share/doc/nextcloud:ro,Z -v $VOL_PREFIX/usr/share/nextcloud:/usr/share/nextcloud:ro,Z x86_64/nextcloud

podman run --pod=web_ext -d --name httpd --label "io.containers.autoupdate=image" -v $VOL_PREFIX/etc/httpd:/etc/httpd:ro,Z -v $VOL_PREFIX/var/www:/var/www:rw,Z -v $VOL_PREFIX/var/log/httpd:/var/log/httpd:rw,Z -v $VOL_PREFIX/usr/share/doc/httpd:/usr/share/doc/httpd:ro,Z -v $VOL_PREFIX/usr/share/httpd:/usr/share/httpd:ro,Z -v $VOL_PREFIX/usr/share/nextcloud:/usr/share/nextcloud:ro,Z -v $VOL_PREFIX/var/lib/nextcloud:/var/lib/nextcloud:rw,Z x86_64/httpd 

podman generate systemd --restart-policy=always -t 1 --files --name web_ext

for CURS in container-httpd.service container-nextcloud.service pod-web_ext.service; do
    cp ${CURS} /etc/systemd/system
    systemctl enable ${CURS}
done



