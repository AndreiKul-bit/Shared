#!/bin/bash
# Настройка сети
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.2.10/24]
      routes:
        - to: 10.0.1.0/24
          via: 10.0.2.1
      nameservers:
        addresses: [10.0.1.10]
        search: [example.com]
EOF
netplan apply

# Настройка MariaDB
hostnamectl set-hostname db01
sed -i 's/^bind-address.*/bind-address = 10.0.2.10/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mysql

# Создание БД и пользователя
mysql -e "CREATE DATABASE webapp;"
mysql -e "CREATE USER 'webuser'@'10.0.1.11' IDENTIFIED BY 'webpass';"
mysql -e "GRANT ALL PRIVILEGES ON webapp.* TO 'webuser'@'10.0.1.11';"
