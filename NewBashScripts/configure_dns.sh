#!/bin/bash
# Настройка сети
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.1.10/24]
      routes:
        - to: 10.0.2.0/24
          via: 10.0.1.1
      nameservers:
        addresses: [127.0.0.1, 8.8.8.8]
        search: [example.com]
EOF
netplan apply

# Настройка BIND9
hostnamectl set-hostname dns01
cat > /etc/bind/named.conf.local <<EOF
zone "example.com" {
    type master;
    file "/etc/bind/db.example.com";
    allow-transfer { none; };
};

zone "2.0.10.in-addr.arpa" {
    type master;
    file "/etc/bind/db.10.0.2";
};
EOF

# Прямая зона
cat > /etc/bind/db.example.com <<EOF
\$TTL 86400
@   IN  SOA dns01.example.com. admin.example.com. (
    2023061701  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400 )     ; Minimum TTL

; NS Records
@       IN  NS  dns01.example.com.

; A Records
dns01   IN  A   10.0.1.10
web01   IN  A   10.0.1.11
mail01  IN  A   10.0.1.12

; Серверы в приватной сети
dc01    IN  A   10.0.2.12
db01    IN  A   10.0.2.10
fs01    IN  A   10.0.2.11

; MX Record
@       IN  MX  10 mail01.example.com.

; CNAME Records
www     IN  CNAME   web01.example.com.
smtp    IN  CNAME   mail01.example.com.
imap    IN  CNAME   mail01.example.com.
EOF

# Обратная зона (для приватной сети)
cat > /etc/bind/db.10.0.2 <<EOF
\$TTL 86400
@   IN  SOA dns01.example.com. admin.example.com. (
    2023061701  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400 )     ; Minimum TTL

@       IN  NS  dns01.example.com.

12      IN  PTR dc01.example.com.
10      IN  PTR db01.example.com.
11      IN  PTR fs01.example.com.
EOF

systemctl restart bind9
