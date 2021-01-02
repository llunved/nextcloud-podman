#!/bin/bash
##
# Copy default config files to mounted volumes

env

# Always export the docs dir to the volume mounted from the host.
cp -pRuv /usr/share/doc/nextcloud.default/* /usr/share/doc/nextcloud/

# Always update /usr/share/nextcloud after an update
cp -pRuv /usr/share/doc/nextcloud.default/config/usr/share/nextcloud/* /usr/share/nextcloud/

# Copy other config files if they are missing or an update is forced.
for CUR_DIR in ${VOLUMES} ; do
    if [ -f ${CUR_DIR}/.forceinit ] || [ ! "$(ls -A ${CUR_DIR}/)" ]; then
        if [ -d /usr/share/doc/nextcloud.default/config${CUR_DIR} ]; then
            cp -pRv /usr/share/doc/nextcloud.default/config${CUR_DIR}/* ${CUR_DIR}/
        fi
    fi
done

touch /etc/init_done

