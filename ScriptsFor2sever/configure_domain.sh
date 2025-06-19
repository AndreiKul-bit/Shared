#!/bin/bash
# Настройка сети
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.2.12/24]
      routes:
        - to: 10.0.1.0/24
          via: 10.0.2.1
      nameservers:
        addresses: [10.0.1.10]
        search: [example.com]
EOF
netplan apply

# Настройка Samba AD
hostnamectl set-hostname dc01
samba-tool domain provision \
  --use-rfc2307 \
  --realm=EXAMPLE.COM \
  --domain=EXAMPLE \
  --adminpass=Secret123 \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
systemctl restart smbd nmbd winbind
samba-tool dns add 10.0.1.10 example.com db01 A 10.0.2.10 -U Administrator%Secret123
samba-tool dns add 10.0.1.10 example.com fs01 A 10.0.2.11 -U Administrator%Secret123
