ARG OS_RELEASE=33
ARG OS_IMAGE=fedora-minimal:$OS_RELEASE

FROM $OS_IMAGE 

ARG OS_RELEASE
ARG OS_IMAGE
ARG HTTP_PROXY=""
ARG USER="apache"
ARG DEVBUILD=""
ARG VOLUMES_ARG="/etc/nextcloud /etc/php /etc/httpd /var/lib/nextcloud /usr/share/nextcloud /var/log/nextcloud /var/lib/php /var/log/php-fpm /run/php-fpm"
LABEL MAINTAINER riek@llunved.net

ENV VOLUMES=$VOLUMES_ARG
ENV LANG=C.UTF-8

ENV USER=$USER
ENV CHOWN=true 
ENV CHOWN_DIRS="/var/lib/nextcloud /etc/nextcloud" 

USER root

RUN mkdir -p /nextcloud
WORKDIR /nextcloud

ADD ./rpmreqs-rt.txt ./rpmreqs-build.txt ./rpmreqs-dev.txt /nextcloud/

ENV http_proxy=$HTTP_PROXY
RUN rpm -ivh  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$OS_RELEASE.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$OS_RELEASE.noarch.rpm  && \
    microdnf -y update && \
    microdnf install -y --setopt install_weak_deps=0 --nodocs $(cat rpmreqs-rt.txt) && \
    if [ ! -z "$DEVBUILD" ] ; then microdnf install -y --setopt install_weak_deps=0 --nodoc $(cat rpmreqs-dev.txt); fi && \
    rm -rf /var/cache/*

# Move the nextcloud config to a deoc dir, so we can mount config from the host but export the defaults from the host
RUN if [ -d /usr/share/doc/nextcloud ]; then \
       mv /usr/share/doc/nextcloud /usr/share/doc/nextcloud.default ; \
    else \
       mkdir -p /usr/share/doc/nextcloud.default ; \
    fi ; \
    mkdir /usr/share/doc/nextcloud.default/config

ADD www.conf /etc/php-fpm.d/www.conf
ADD 10-opcache.ini /etc/php.d/10-opcache.ini

RUN mkdir /etc/php \
    && for CURF in /etc/php-fpm.conf /etc/php-fpm.d /etc/php-zts.d /etc/php.d /etc/php.ini; do \
        mv -fv ${CURF} /etc/php/$(basename ${CURF}) ; \
        ln -srfv /etc/php/$(basename ${CURF}) ${CURF} ; \
    done 
   
RUN for CURF in ${VOLUMES} ; do \
    if [ -d ${CURF} ]; then \
        if [ "$(ls -A ${CURF})" ]; then \
            mkdir -pv /usr/share/doc/nextcloud.default/config${CURF} ; \
            mv -fv ${CURF}/* /usr/share/doc/nextcloud.default/config${CURF}/ ;\
        fi ;\
    fi ; \
    done

# Set up systemd inside the container
RUN systemctl --root / mask systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount systemd-logind.service getty.target console-getty.service && \
    systemctl --root / disable dnf-makecache.timer dnf-makecache.service
ADD nextcloud-cron.service nextcloud-cron.timer init_container.service /etc/systemd/system
RUN systemctl --root / enable nextcloud-cron.timer init_container.service php-fpm.service

WORKDIR /var/lib/nextcloud
RUN rm -rf /nextcloud

VOLUME $VOLUMES

#FIXME the old install scripts are probably obsolete
ADD ./install.sh \ 
    ./upgrade.sh \
    ./uninstall.sh \
    ./init_container.sh /sbin
 
RUN chmod +x /sbin/install.sh \
             /sbin/upgrade.sh \
             /sbin/uninstall.sh \
             /sbin/init_container.sh
    
# Using FPM
EXPOSE 9000
CMD ["/usr/sbin/init"]
STOPSIGNAL SIGRTMIN+3

# FIXME - BROKE THESE WITH PODS
#LABEL RUN="podman run --rm -t -i --name ${NAME} -p 9000:9000 -v /var/lib/${NAME}:/var/lib/${NAME}:rw,z -v etc/${NAME}:/etc/${NAME}:rw,z -v /var/log/${NAME}:/var/log/${NAME}:rw,z ${IMAGE}"
#LABEL INSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/install.sh"
#LABEL UPGRADE="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/upgrade.sh"
#LABEL UNINSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/uninstall.sh"

