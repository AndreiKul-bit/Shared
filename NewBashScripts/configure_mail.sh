#!/bin/bash
# Настройка сети
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.1.12/24]
      routes:
        - to: 10.0.2.0/24
          via: 10.0.1.1
      nameservers:
        addresses: [10.0.1.10]
        search: [example.com]
EOF
netplan apply

# Настройка Postfix и Dovecot
hostnamectl set-hostname mail01

# Postfix main.cf
postconf -e "myhostname = mail01.example.com"
postconf -e "mydomain = example.com"
postconf -e "myorigin = \$mydomain"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "mynetworks = 127.0.0.0/8, 10.0.1.0/24, 10.0.2.0/24"
postconf -e "relay_domains = example.com"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_security_options = noanonymous"
postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem"
postconf -e "smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key"
postconf -e "smtpd_use_tls = yes"
postconf -e "virtual_mailbox_domains = example.com"
postconf -e "virtual_mailbox_base = /var/mail/vmail"
postconf -e "virtual_mailbox_maps = hash:/etc/postfix/vmailbox"
postconf -e "virtual_minimum_uid = 100"
postconf -e "virtual_uid_maps = static:5000"
postconf -e "virtual_gid_maps = static:5000"

# Mailbox mapping
cat > /etc/postfix/vmailbox <<EOF
@example.com   example.com/
EOF
postmap /etc/postfix/vmailbox

# Создание пользователя для почты
groupadd -g 5000 vmail
useradd -g vmail -u 5000 vmail -d /var/mail/vmail -m

# Dovecot config
cat > /etc/dovecot/conf.d/10-auth.conf <<EOF
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-system.conf.ext
EOF

cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
mail_location = maildir:/var/mail/vmail/%d/%n
mail_privileged_group = vmail
EOF

cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service auth {
    unix_listener /var/spool/postfix/private/auth {
        mode = 0660
        user = postfix
        group = postfix
    }
}
EOF

systemctl restart postfix dovecot