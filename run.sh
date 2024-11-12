#!/bin/bash

FILES_PATH="$(dirname "$(realpath "$0")")"/files
source "$FILES_PATH/config"

podman stop "$CONTAINER_NAME" 2>/dev/null && podman rm "$CONTAINER_NAME" 2>/dev/null

# Es necesario usar privileged para crear --bind en el directorio pub/ que
# realiza el script create-pub-links.sh
#        -v "$FILES_PATH"/users.conf:/etc/sftp/users.conf:Z \
# También para el uso de cuotas

podman run -it --privileged \
	-d --init \
	--name "$CONTAINER_NAME" \
	-e USE_PUB="${USE_PUB:-1}" \
    -e PUB_PERMISSIONS="${PUB_PERMISSIONS:-1777}" \
    -e USE_QUOTAS="${USE_QUOTAS:-0}" \
	-e PUB_QUOTA="${PUB_QUOTA}" \
	-p "${HOST_PORT:-2222}":22 \
	-v "${HOST_FTP_DIR:-/please_set_the_host_ftp_dir}":/home:Z \
	"$IMAGE_TAG"
