#!/bin/bash
# Настройка сети
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.1.11/24]
      routes:
        - to: 10.0.2.0/24
          via: 10.0.1.1
      nameservers:
        addresses: [10.0.1.10]
        search: [example.com]
EOF
netplan apply

# Настройка Apache и PHP
hostnamectl set-hostname web01
a2enmod ssl rewrite
systemctl restart apache2

# Создание тестового сайта
cat > /var/www/html/index.php <<EOF
<?php
\$servername = "db01.example.com";
\$username = "webuser";
\$password = "StrongPassword123!";
\$dbname = "webapp";

// Проверка подключения к БД
\$conn = new mysqli(\$servername, \$username, \$password, \$dbname);

if (\$conn->connect_error) {
    die("Connection failed: " . \$conn->connect_error);
}
echo "Database connection successful!";

// Проверка подключения к файловому серверу
\$smb = @file_get_contents('smb://fs01.example.com/shared/test.txt');
if (\$smb === false) {
    echo "<br>File server connection failed";
} else {
    echo "<br>File server connection successful! Content: " . htmlspecialchars(\$smb);
}
?>
EOF

# Настройка прав
chown -R www-data:www-data /var/www/html/
