#!/bin/bash

FILES_PATH="$(dirname "$(realpath "$0")")"/files
source "$FILES_PATH/config"

[[ "$HOST_FTP_DIR" == "" ]] && echo "Asigna el directorio FTP en $FILES_PATH/config" && exit 1

# Construye la imagen. Indicando el directorio de los diferentes ficheros necesarios

### IMPORTANTE: CREACIÓN DE LAS CLAVES SSH ###
# Cada vez que se lanza el contenedor genera nuevas claves ssh, lo que hace que 
# el cliente ftp (según cómo este programdo) nos termine la sesión o nos diga que 
# hay un conflicto de claves. Sería necesario borrar la key ssh con 
#    ssh-keygen -R "[localhost]:2222"
# Esto habría que hacerlo cada vez que nos conectemos si el contendor se ha 
# reiniciado. 
# Las claves se generan sólo una vez.
[ -d "$FILES_PATH/ssh" ] || mkdir -p "$FILES_PATH/ssh"
[ ! -d "$FILES_PATH"/ssh ] && echo Error creando "$FILES_PATH"/ssh && exit 1
if [[ ! -f "$FILES_PATH/ssh/ssh_host_ed25519_key" || ! -f "$FILES_PATH/ssh/ssh_host_rsa_key" ]]; then
   ssh-keygen -t ed25519 -f "$FILES_PATH/ssh/ssh_host_ed25519_key" -N ''
   ssh-keygen -t rsa -b 4096 -f "$FILES_PATH/ssh/ssh_host_rsa_key" -N ''
fi

podman build -t "$IMAGE_TAG" "$FILES_PATH"

# Si no se quiere usar systemd, terminar aquí
[[ "$USE_SYSTEMD" != "1" ]] && exit

echo "Configurando systemd como usuario..."
[[ "$USER" == "root" ]] && 2> echo "La parte de systemd no es configurable como root" && exit 1

#Directorio local del usuario
SYSTEMD_DIR="$HOME/.config/systemd/user"
[ -d "$SYSTEMD_DIR" ] || mkdir -p "$SYSTEMD_DIR"
[ ! -d "$SYSTEMD_DIR" ] && echo "Error creando $SYSTEMD_DIR" && exit 1

#El linger debe activarse como root
has_linger=$(loginctl show-user -p Linger admin 2>/dev/null | cut -d= -f2)
[[ "$has_linger" != "yes" ]] && echo "AVISO: Linger no está activo, hay que ejecutar sudo loginctl enable-linger $USER"

# Unidades necesarias
watcher_path="sftp-watcher-users.path"
watcher_service="sftp-watcher-users.service"
run_service="sftp-run.service"

# Creación de los ficheros de systemd.
# Watcher Path: Monitorea cambios en users.conf
cat <<EOF > "$SYSTEMD_DIR/$watcher_path"
[Unit]
Description=Watcher for Easy SFTP

[Path]
PathChanged=${FILES_PATH}/users.conf

[Install]
WantedBy=multi-user.target
EOF

# Watcher Service: Ejecuta update-users.sh cuando el .path detecta un cambio
cat <<EOF > "$SYSTEMD_DIR/$watcher_service"
[Unit]
Description=Run Update users script for SFTP Server

[Service]
Type=oneshot
ExecStart=${FILES_PATH}/update-users.sh
EOF
chmod +x ${FILES_PATH}/update-users.sh # Para asegurarnos...

# Run Service: Ejecuta el contenedor al iniciar el sistema
# NOTA: La forma más ortodoxa de hacerlo es mediante
#       podman generate systemd --name sftp-run.service --files --new
#       Pero para tener una coherencia en el código uso el cat EOF
cat <<EOF > "$SYSTEMD_DIR/$run_service"
[Unit]
Description=Run SFTP Server Container

[Service]
ExecStart=${FILES_PATH%/*}/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [[ "$SYSTEMD_AUTOACTIVATE" == "1" ]]; then
    echo "Activando las unidades systemd..."
    # TODO: Check for errors
    #systemctl --user enable "$watcher_unit" && systemctl --user start "$watcher_unit"
    #systemctl --user enable "$service_unit" && systemctl --user start "$service_unit"
else
    echo "Recuerda que debes activar manualmente $watcher_unit y $service con systemctl --user"
fi

