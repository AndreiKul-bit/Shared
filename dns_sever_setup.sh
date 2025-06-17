#!/bin/bash
# dns_server_setup.sh

# Переменные
DNS_IP="10.0.1.10"
DOMAIN="example.com"
NETWORK="10.0.1.0/24"
GATEWAY="10.0.1.1"
INTERFACE="ens33"  # Уточните интерфейс (ip a)

echo "=== НАСТРОЙКА DNS-СЕРВЕРА ($DNS_IP) ==="

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка BIND
sudo apt install bind9 bind9utils dnsutils -y

# Настройка статического IP
sudo tee /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses: [$DNS_IP/24]
      nameservers:
        addresses: [127.0.0.1, 8.8.8.8]
      routes:
        - to: default
          via: $GATEWAY
EOF
sudo netplan apply

# Настройка BIND
sudo tee /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
    allow-query { any; };
    listen-on { any; };
    recursion yes;
    dnssec-validation no;  # Упрощение для тестов
};
EOF

# Конфигурация зон
sudo tee /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};

zone "1.0.10.in-addr.arpa" {
    type master;
    file "/etc/bind/db.10.0.1";
};
EOF

# Прямая зона
sudo tee /etc/bind/db.$DOMAIN <<EOF
\$TTL    86400
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                          2024061601 ; Serial
                          3600       ; Refresh
                          1800       ; Retry
                          604800     ; Expire
                          86400 )    ; Minimum TTL

@       IN      NS      ns1.$DOMAIN.
ns1     IN      A       $DNS_IP
@       IN      A       $DNS_IP
www     IN      A       10.0.1.12
mail    IN      A       10.0.1.11
@       IN      MX 10   mail.$DOMAIN.
@       IN      TXT     "v=spf1 mx -all"
EOF

# Обратная зона
sudo tee /etc/bind/db.10.0.1 <<EOF
\$TTL    86400
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                          2024061601 ; Serial
                          3600       ; Refresh
                          1800       ; Retry
                          604800     ; Expire
                          86400 )    ; Minimum TTL

@       IN      NS      ns1.$DOMAIN.
10      IN      PTR     ns1.$DOMAIN.
12      IN      PTR     www.$DOMAIN.
11      IN      PTR     mail.$DOMAIN.
EOF

# Проверка и перезапуск
sudo named-checkconf
sudo named-checkzone $DOMAIN /etc/bind/db.$DOMAIN
sudo named-checkzone 1.0.10.in-addr.arpa /etc/bind/db.10.0.1
sudo systemctl restart bind9

# Фаервол
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw reload

echo "=== DNS-СЕРВЕР НАСТРОЕН! ==="
echo "Проверка: nslookup www.$DOMAIN $DNS_IP"