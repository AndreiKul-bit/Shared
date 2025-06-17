#!/bin/bash
# web_server_setup.sh

# Переменные
WEB_IP="10.0.1.12"
DNS_IP="10.0.1.10"
DOMAIN="example.com"
GATEWAY="10.0.1.1"
INTERFACE="ens33"  # Уточните интерфейс

echo "=== НАСТРОЙКА WEB-СЕРВЕРА ($WEB_IP) ==="

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Настройка сети
sudo tee /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses: [$WEB_IP/24]
      nameservers:
        addresses: [$DNS_IP]
      routes:
        - to: default
          via: $GATEWAY
EOF
sudo netplan apply

# Установка Apache
sudo apt install apache2 -y
sudo systemctl enable apache2

# Создание сайта
sudo mkdir -p /var/www/$DOMAIN/html
sudo tee /var/www/$DOMAIN/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>$DOMAIN</title>
</head>
<body>
    <h1>Работает! WEB-сервер $WEB_IP</h1>
</body>
</html>
EOF
sudo chown -R www-data:www-data /var/www/$DOMAIN

# Настройка виртуального хоста
sudo tee /etc/apache2/sites-available/$DOMAIN.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAIN
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/$DOMAIN/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Активация сайта
sudo a2ensite $DOMAIN.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2

# Фаервол
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

echo "=== WEB-СЕРВЕР НАСТРОЕН! ==="
echo "Проверка: curl http://$WEB_IP"