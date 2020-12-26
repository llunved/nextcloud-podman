ARG OS_RELEASE=33
ARG OS_IMAGE=fedora:$OS_RELEASE

FROM $OS_IMAGE as build

ARG OS_RELEASE
ARG OS_IMAGE
ARG HTTP_PROXY=""
#ARG USER="apache"
ARG DEVBUILD=""

LABEL MAINTAINER riek@llunved.net

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

# Set up systemd inside the container
RUN systemctl --root /sysimg mask systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount systemd-logind.service getty.target console-getty.service && systemctl --root /sysimg disable dnf-makecache.timer dnf-makecache.service
RUN /usr/bin/systemctl --root /sysimg enable php-fpm.service
 
# Move the nextcloud config, so we can mount it persistently from the host
RUN for CURF in /sysimg/etc/nextcloud /sysimg/var/lib/nextcloud ; do \
    mv -fv ${CURF} ${CURF}.default ;\
    done

ADD www.conf /sysimg/etc/php-fpm.d/www.conf
ADD 10-opcache.ini /sysimg/etc/nextcloud/php/php.d/10-opcache.ini

RUN mkdir /sysimg/etc/php && \
    for CURF in /etc/php-fpm.conf /etc/php-fpm.d /etc/php-zts.d /etc/php.d /etc/php.ini; do \
    mv -fv /sysimg${CURF} /sysimg/etc/php/$(basename ${CURF}) ; \
    ln -srfv /sysimg/etc/php/$(basename ${CURF}) /sysimg${CURF} ; \
    done ; \
    mv -fv /sysimg/etc/php /sysimg/etc/php.default

#mv -fv /sysimg/etc/nextcloud /sysimg/etc/nextcloud.default
#RUN mv -fv /sysimg/var/lib/nextcloud /sysimg/var/lib/nextcloud.default 

FROM scratch AS runtime

COPY --from=build /sysimg /

WORKDIR /var/lib/nextcloud

#ENV USER=$USER
#ENV CHOWN=true 
#ENV CHOWN_DIRS="/var/lib/nextcloud /etc/nextcloud" 
 
VOLUME /etc/nextcloud /var/lib/nextcloud

ADD ./install.sh \ 
    ./upgrade.sh \
    ./uninstall.sh /sbin
 
RUN chmod +x /sbin/install.sh \
    && chmod +x /sbin/upgrade.sh \
    && chmod +x /sbin/uninstall.sh 
  
# Using FPM
EXPOSE 80 443
CMD ["/sbin/init"]
STOPSIGNAL SIGRTMIN+3

LABEL RUN="podman run --rm -t -i --name ${NAME} -p 9000:9000 -v /var/lib/${NAME}:/var/lib/${NAME}:rw,z -v etc/${NAME}:/etc/${NAME}:rw,z -v /var/log/${NAME}:/var/log/${NAME}:rw,z ${IMAGE}"
LABEL INSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/install.sh"
LABEL UPGRADE="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/upgrade.sh"
LABEL UNINSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/uninstall.sh"

