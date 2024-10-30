#!/bin/bash

set -Eeo pipefail

/entrypoint "$@" &

# Esperar a que se ejecute el entrypoint. Como lanza una instrucción  
# "sshd -D -e" se queda en espera y nunca regresa a este script. Lo que hacemos
# es lanzarlo en segundo plano y esperar a que esté sshd ejecutándose, lo que
# indica que /entrypoint ya terminó

while ! pgrep -x sshd 2> /dev/null; do
	sleep 0.4
done

# Creamos los enlaces a pub/. Las quotas no pueden crearse en el contenedor
[ "$USE_PUB" = "1" ] && create-pub-links.sh

sleep infinity
