#!/bin/bash
# Настройка сети
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.2.11/24]
      routes:
        - to: 10.0.1.0/24
          via: 10.0.2.1
      nameservers:
        addresses: [10.0.1.10]
        search: [example.com]
EOF
netplan apply

# Присоединение к домену
hostnamectl set-hostname fs01
cp /etc/krb5.conf{,.bak}
cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = EXAMPLE.COM
    dns_lookup_realm = false
    dns_lookup_kdc = true
EOF

echo "Secret123" | kinit administrator@EXAMPLE.COM
net ads join -U Administrator%Secret123

# Настройка Samba
cat > /etc/samba/smb.conf <<EOF
[global]
    workgroup = EXAMPLE
    realm = EXAMPLE.COM
    security = ads
    idmap config * : range = 10000-20000
    template shell = /bin/bash

[shared]
    path = /srv/shared
    read only = no
    browsable = yes
EOF

mkdir -p /srv/shared
chmod 777 /srv/shared
systemctl restart smbd nmbd winbind
w