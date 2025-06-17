#!/bin/bash
# mail_server_setup.sh

# Переменные
MAIL_IP="10.0.1.11"
DNS_IP="10.0.1.10"
DOMAIN="example.com"
GATEWAY="10.0.1.1"
INTERFACE="ens33"  # Уточните интерфейс

echo "=== НАСТРОЙКА MAIL-СЕРВЕРА ($MAIL_IP) ==="

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Настройка сети
sudo tee /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses: [$MAIL_IP/24]
      nameservers:
        addresses: [$DNS_IP]
      routes:
        - to: default
          via: $GATEWAY
EOF
sudo netplan apply

# Установка компонентов
sudo DEBIAN_FRONTEND=noninteractive apt install postfix dovecot-imapd dovecot-pop3d opendkim opendkim-tools -y

# Автонастройка Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string mail.$DOMAIN"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo dpkg-reconfigure -f noninteractive postfix

# Основная конфигурация Postfix
sudo tee /etc/postfix/main.cf <<EOF
myhostname = mail.$DOMAIN
mydomain = $DOMAIN
myorigin = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
mynetworks = 10.0.1.0/24, 127.0.0.0/8
relay_domains = \$mydomain
smtpd_use_tls = yes
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
EOF

# Настройка Dovecot
sudo tee /etc/dovecot/conf.d/10-mail.conf <<EOF
mail_location = mbox:~/mail:INBOX=/var/mail/%u
EOF

sudo tee /etc/dovecot/conf.d/10-auth.conf <<EOF
disable_plaintext_auth = no
auth_mechanisms = plain login
!include auth-system.conf.ext
EOF

# Настройка OpenDKIM
sudo mkdir -p /etc/opendkim/keys
sudo chown -R opendkim:opendkim /etc/opendkim

sudo tee /etc/opendkim.conf <<EOF
Domain    $DOMAIN
KeyFile   /etc/opendkim/keys/mail.private
Selector  mail
Socket    inet:8891@localhost
EOF

# Генерация DKIM ключа
sudo opendkim-genkey -b 2048 -d $DOMAIN -D /etc/opendkim/keys -s mail -v
sudo chown opendkim:opendkim /etc/opendkim/keys/mail.private
sudo mv /etc/opendkim/keys/mail.txt /etc/opendkim/keys/mail.dns

# Интеграция Postfix+OpenDKIM
sudo postconf -e "milter_default_action = accept"
sudo postconf -e "milter_protocol = 2"
sudo postconf -e "smtpd_milters = inet:localhost:8891"
sudo postconf -e "non_smtpd_milters = inet:localhost:8891"

# Перезапуск служб
sudo systemctl restart postfix dovecot opendkim

# Фаервол
sudo ufw allow 25,587,465,143,993,110,995/tcp
sudo ufw reload

# Создание тестового пользователя
echo "Создание тестового пользователя mailuser:"
sudo adduser mailuser --gecos "" --disabled-password
echo "mailuser:MailPass123" | sudo chpasswd

echo "=== MAIL-СЕРВЕР НАСТРОЕН! ==="
echo "Проверка: telnet $MAIL_IP 25"