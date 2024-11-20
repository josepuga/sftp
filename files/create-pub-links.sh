#!/bin/bash
# Este script se encarga de crear enlaces simbólicos al directorio público pub
# para cada usuario en el sistema SFTP que tenga un directorio en /home.

# Si no existe el directorio público, se crea, le damos permisos para todos 
# y le ponemos el sticky bit (por defecto) para que actúe como si fuera un
# /tmp, sólo el usuario del fichero puede borrarlo/modificarlo
PUB_DIR="/home/pub"
if [ ! -d "$PUB_DIR" ]; then
   mkdir "$PUB_DIR" 
   chmod "$PUB_PERMISSIONS" "$PUB_DIR"
fi


# Se crean un pub/ dentro del home del usuario que apunta al público /home/pub
# LOS ENLACES SIMB. NO FUNCIONAN. Habria que agregar en /etc/ssh/sshd_config
# AllowSymlinks yes
# La otra opción es "bindear" (mount --bind) la unidad apuntando a /home/pub

# Busca todos los directorios en el raíz del direct. compartido del host
# (que en realidad es el /home del contenedor). Si encuentra un directorio,
# comprueba que su nombre coincida con un usuario registrado y crea el enlace.
# Esto permite tener directorios adicionales en el direct. que no interactúen
# con el contenedor. P.ej un directorio docs/, html/, etc.

# Se recorren el contenido de /home/* y se comprueba si un elemento es un 
# directorio y coincide con el nombre de un usuario registrado. 
# Estos /home/<user> son creados por SFTP a través de users.conf al inicio.
for user_home in /home/*; do
    user_name=$(basename "$user_home")
    group_name=$(id -gn $user_name 2>/dev/null || echo "") # Este echo deja limpio el log
    # Si es un directorio y coincide con un nombre de usuario (podríamos tener
    # otros directorios en el host para uso propio como docs/, html/, etc.).
    if [ -d "$user_home" ] &&  id -u "$user_name" &>/dev/null; then
        # Si no existe pub/ hay que crearlo y ponerle como propietario el usuario
        [ ! -d "$user_home/pub" ] && mkdir "$user_home/pub" && \
		chown $user_name:$group_name "$user_home/pub"

        # Si no existe un montaje previo, crear un nuevo montaje
        if ! mountpoint -q "$user_home/pub"; then
   	     mount --bind "$PUB_DIR" "$user_home/pub"
        fi

        # El usuario anonymous si existiera, se trataría de forma especial.
        # Se le quitan los permisos de escritura a su pub/. Es necesario usar ACL
        [[ "$user_name" == "anonymous" ]] && setfacl -R -m u:anonymous:rx -m m:rx "$user_home/pub"
    fi
done
# Este hack es porque al realizar mount --bind, se pierden los permisos de pub
# No quiero poner permisos 1777 a /home/usuario/pub, porque cuando se ve desde el
# host quiero que aparezca como un directorio con permisos normales.
chmod "$PUB_PERMISSIONS" "$PUB_DIR"

