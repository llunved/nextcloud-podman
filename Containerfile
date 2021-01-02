ARG OS_RELEASE=33
ARG OS_IMAGE=fedora:$OS_RELEASE

FROM $OS_IMAGE as build

ARG OS_RELEASE
ARG OS_IMAGE
ARG HTTP_PROXY=""
#ARG USER="apache"
ARG DEVBUILD=""
ARG VOLUMES_ARG="/etc/nextcloud /etc/php /etc/httpd /var/lib/nextcloud /usr/share/nextcloud /var/log/nextcloud /var/lib/php /var/log/php-fpm /run/php-fpm"
LABEL MAINTAINER riek@llunved.net

ENV VOLUMES=$VOLUMES_ARG
ENV LANG=C.UTF-8
USER root

RUN mkdir -p /nextcloud
WORKDIR /nextcloud

ADD ./rpmreqs-rt.txt ./rpmreqs-build.txt ./rpmreqs-dev.txt /nextcloud/

ENV http_proxy=$HTTP_PROXY
RUN dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$OS_RELEASE.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$OS_RELEASE.noarch.rpm \
    && dnf -y upgrade \
    && dnf -y install $(cat rpmreqs-build.txt) \
    && if [ ! -z "$DEVBUILD" ] ; then dnf -y install $(cat rpmreqs-dev.txt); fi 

# Create the minimal target environment
RUN mkdir /sysimg \
    && dnf install -y --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs coreutils-single glibc-minimal-langpack $(cat rpmreqs-rt.txt) \
    && if [ ! -z "$DEVBUILD" ] ; then dnf install -y --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodoc $(cat rpmreqs-dev.txt); fi \
    && rm -rf /sysimg/var/cache/*

#FIXME this needs to be more elegant
RUN ln -s /sysimg/usr/share/zoneinfo/America/New_York /sysimg/etc/localtime

# Move the nextcloud config to a deoc dir, so we can mount config from the host but export the defaults from the host
RUN if [ -d /sysimg/usr/share/doc/nextcloud ]; then \
       mv /sysimg/usr/share/doc/nextcloud /sysimg/usr/share/doc/nextcloud.default ; \
    else \
       mkdir -p /sysimg/usr/share/doc/nextcloud.default ; \
    fi ; \
    mkdir /sysimg/usr/share/doc/nextcloud.default/config

ADD www.conf /sysimg/etc/php-fpm.d/www.conf
ADD 10-opcache.ini /sysimg/etc/php.d/10-opcache.ini

RUN mkdir /sysimg/etc/php \
    && for CURF in /etc/php-fpm.conf /etc/php-fpm.d /etc/php-zts.d /etc/php.d /etc/php.ini; do \
        mv -fv /sysimg${CURF} /sysimg/etc/php/$(basename ${CURF}) ; \
        ln -srfv /sysimg/etc/php/$(basename ${CURF}) /sysimg${CURF} ; \
    done 
#    mv -fv /sysimg/etc/php /sysimg/usr/share/doc/nextcloud.default/config/etc/php
   
RUN for CURF in ${VOLUMES} ; do \
    if [ -d /sysimg${CURF} ]; then \
        if [ "$(ls -A /sysimg${CURF})" ]; then \
            mkdir -pv /sysimg/usr/share/doc/nextcloud.default/config${CURF} ; \
            mv -fv /sysimg${CURF}/* /sysimg/usr/share/doc/nextcloud.default/config${CURF}/ ;\
        fi ;\
    fi ; \
    done

# Set up systemd inside the container
RUN systemctl --root /sysimg mask systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount systemd-logind.service getty.target console-getty.service && systemctl --root /sysimg disable dnf-makecache.timer dnf-makecache.service
ADD nextcloud-cron.service nextcloud-cron.timer init_container.service /sysimg/etc/systemd/system
RUN systemctl daemon-reload && \
    systemctl --root /sysimg enable nextcloud-cron.timer init_container.service php-fpm.service



FROM scratch AS runtime

ARG VOLUMES_ARG="/etc/nextcloud /etc/php /etc/httpd /var/lib/nextcloud /usr/share/nextcloud /var/log/nextcloud /var/lib/php /var/log/php-fpm /run/php-fpm"

COPY --from=build /sysimg /

WORKDIR /var/lib/nextcloud

#ENV USER=$USER
#ENV CHOWN=true 
#ENV CHOWN_DIRS="/var/lib/nextcloud /etc/nextcloud" 
ENV VOLUMES=$VOLUMES_ARG
 
VOLUME $VOLUMES

ADD ./install.sh \ 
    ./upgrade.sh \
    ./uninstall.sh \
    ./init_container.sh /sbin
 
RUN chmod +x /sbin/install.sh \
             /sbin/upgrade.sh \
             /sbin/uninstall.sh \
             /sbin/init_container.sh
    
  
# Using FPM
EXPOSE 80 443
CMD ["/usr/sbin/init"]
STOPSIGNAL SIGRTMIN+3

# FIXME - BROKE THESE WITH PODS
#LABEL RUN="podman run --rm -t -i --name ${NAME} -p 9000:9000 -v /var/lib/${NAME}:/var/lib/${NAME}:rw,z -v etc/${NAME}:/etc/${NAME}:rw,z -v /var/log/${NAME}:/var/log/${NAME}:rw,z ${IMAGE}"
#LABEL INSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/install.sh"
#LABEL UPGRADE="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/upgrade.sh"
#LABEL UNINSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/uninstall.sh"

