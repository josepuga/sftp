#!/bin/bash
# Si no se activó systemd en Easy SFTP:
# EJECUTAR MANUALMENTE AL MODIFICAR users.conf CON EL CONTENEDOR EJECUTÁNDOSE
set -e

# Se encarga de sincronizar el users.conf del host con el del contenedor y
# volver a generar los nuevos usuarios

FILES_PATH="$(dirname "$(realpath "$0")")"/files
source "$FILES_PATH/config"

USERS_CONF_HOST_PATH="$FILES_PATH/users.conf"
USERS_CONF_CONTAINER_PATH="/etc/sftp/users.conf"

# Desmonta temporalmente el archivo para eliminar el bloqueo
podman exec "$CONTAINER_NAME" bash -c "umount $USERS_CONF_CONTAINER_PATH || true"

# Copia el archivo actualizado al contenedor
podman cp "$USERS_CONF_HOST_PATH" "$CONTAINER_NAME":"$USERS_CONF_CONTAINER_PATH"

# Reaplica el bind mount para actualizar el contenido en el contenedor sin reiniciar, 
# permitiendo que el servidor SFTP lo vuelva a leer.
podman exec "$CONTAINER_NAME" bash -c "mount --bind $USERS_CONF_CONTAINER_PATH $USERS_CONF_CONTAINER_PATH"

# Se ejecuta el scritp dentro del contenedor para actualizar los usuarios
podman exec "$CONTAINER_NAME" /usr/local/bin/update-users.sh

# Debido al OverlayFS, es necesario crear las cuotas desde el host.
MOUNT_POINT=$(stat -c %m $HOST_FTP_DIR)
if [ "$USE_QUOTAS" = "1" ]; then
    #TODO: Show log erros 
    # Se aplica la cuota al directorio pub. Como pub no es un usuario, no se
    # puede usar su uid como id. En su lugar voy a usar un id = a la velocidad
    # de la luz en m/s.

    if [[ $PUB_QUOTA =~ ^[0-9]+[gm]$ ]]; then
        PUB_ID=299792458
        sudo xfs_quota -x -c "project -s -p $HOST_FTP_DIR/pub $PUB_ID"  "$MOUNT_POINT"
        sudo xfs_quota -x -c "limit -p bhard=$PUB_QUOTA $PUB_ID" "$MOUNT_POINT"
    fi
    while IFS= read -r quota_info || [[ -n "$quota_info" ]]; do
        IFS=':' read -r _ user_name user_id size <<< "$quota_info"
        # Comprobar los diferentes campos
        [ -z "$user_name" ] && continue
        [[ ! "$user_id" =~ ^-?[0-9]+$ ]] && continue
        quota_id=$(($user_id + $QUOTA_ID_INC))
        [[ ! "$size" =~ ^[0-9]+[gm]$ ]] && continue

        # Aplicar la cuota
        sudo xfs_quota -x -c "project -s -p $HOST_FTP_DIR/$user_name $quota_id"  "$MOUNT_POINT"
        sudo xfs_quota -x -c "limit -p bhard=$size $quota_id" "$MOUNT_POINT"
    done < <(grep '^#q:' "$FILES_PATH/users.conf")
fi
echo "users.conf sincronizado y usuarios actualizados en el contenedor $CONTAINER_NAME"

