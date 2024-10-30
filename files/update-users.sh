#!/bin/bash

# Scripts necesarios para actualizar usuarios. El primero es el que usa
# el propio SFTP al iniciar el contenedor.
while IFS= read -r user || [[ -n "$user" ]]; do
    create-sftp-user "$user"
done < <(grep -v -e '^#' -e '^$' /etc/sftp/users.conf)

# Ejecutar los otros scripts una vez que se haya terminado el bucle
[ "$USE_PUB" = "1" ] && create-pub-links.sh
