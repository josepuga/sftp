# Dockerfile para crear una imagen personalizada basada en atmoz/sftp

FROM atmoz/sftp

# ACL es necesario para el usuario anonymous...
RUN apt-get update && apt-get install -y acl

# Contiene la lista de usuarios, que autom. sftp se encargará de crear
COPY users.conf /etc/sftp/users.conf

# Para crear los "binds" a /home/pub  dentro del home de cada usuario
COPY create-pub-links.sh /usr/local/bin/create-pub-links.sh
RUN chmod +x /usr/local/bin/create-pub-links.sh

# Este entrypoint es un wrap que llama a /entrypoint y luego a
# create-pub-links.sh para crear los directorios pub/ si no existieran
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Llamado desde el host con "podman exec" para actualizar los usuarios si se
# modifica users.conf
COPY update-users.sh /usr/local/bin/update-users.sh
RUN chmod +x /usr/local/bin/update-users.sh

# Claves SSH "fijas" para que no las genere cada vez que se lanza
COPY ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
COPY ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
COPY ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
RUN chmod 600 /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_rsa_key
RUN chmod 644 /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key.pub

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
