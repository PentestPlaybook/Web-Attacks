#!/usr/bin/env bash
# dvwa_full_setup.sh  •  One-shot DVWA installer for Kali
# ──────────────────────────────────────────────────────────────────────────────
#  ▸ Updates system packages
#  ▸ Installs/starts Apache, MariaDB & PHP
#  ▸ Deploys DVWA under /var/www/html/DVWA
#  ▸ Creates DB + user, wires credentials
#  ▸ Locks Apache to 0.0.0.0:80
#  ▸ Enables key-only SSH for the **calling user** (no root SSH!)
#  ▸ Generates an SSH key protected by passphrase “dragon”
#
# USAGE:  sudo bash dvwa_full_setup.sh
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

### ────────────────  tweakables  ────────────────
DB_NAME="dvwa"
DB_USER="dvwa"
DB_PASS="dvwapass"
APACHE_LISTEN="0.0.0.0:80"
GIT_REPO="https://github.com/digininja/DVWA.git"
SSH_KEY_NAME="id_rsa"
SSH_KEY_PASSPHRASE="dragon"
### ───────────────────────────────────────────────

# Require sudo *from* a non-root account
if [[ $EUID -ne 0 || -z "${SUDO_USER:-}" ]]; then
  echo "Run this script with sudo from your normal user account:"
  echo "    sudo bash $0"
  exit 1
fi

RUN_USER="${SUDO_USER}"
USER_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
SSH_DIR="${USER_HOME}/.ssh"

echo "[+] Updating system …"
apt update -y && apt -y upgrade

echo "[+] Installing LAMP stack & helpers …"
apt install -y apache2 mariadb-server php php-gd php-xml php-mysql git vim \
               pv rsync socat

echo "[+] Enabling & starting Apache + MariaDB …"
systemctl enable --now apache2 mariadb

echo "[+] Creating DVWA database & user …"
mysql <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "[+] Pulling DVWA …"
cd /var/www/html
[[ -d DVWA ]] || git clone --depth 1 "$GIT_REPO" DVWA
chown -R www-data:www-data DVWA

echo "[+] Configuring DVWA credentials …"
cd DVWA/config
cp -n config.inc.php.dist config.inc.php
sed -i -E \
  -e "s#('db_password'.*?= ).*;#\1 getenv('DB_PASSWORD') ?: '${DB_PASS}';#" \
  -e "s#('db_user'.*?= ).*;#\1 getenv('DB_USER') ?: '${DB_USER}';#" \
  -e "s#('db_database'.*?= ).*;#\1 getenv('DB_DATABASE') ?: '${DB_NAME}';#" \
  config.inc.php
chown www-data:www-data config.inc.php
chmod 640 config.inc.php

echo "[+] Binding Apache to ${APACHE_LISTEN} …"
sed -i -E "s/^Listen .*/Listen ${APACHE_LISTEN}/" /etc/apache2/ports.conf
systemctl restart apache2

echo "[+] Enabling OpenSSH server …"
systemctl enable --now ssh

echo "[+] Generating SSH key for ${RUN_USER} (passphrase: '${SSH_KEY_PASSPHRASE}') …"
install -d -m 700 -o "$RUN_USER" -g "$RUN_USER" "$SSH_DIR"
if [[ ! -f "${SSH_DIR}/${SSH_KEY_NAME}" ]]; then
  sudo -u "$RUN_USER" ssh-keygen \
       -t rsa -b 4096 \
       -f "${SSH_DIR}/${SSH_KEY_NAME}" \
       -N "${SSH_KEY_PASSPHRASE}" \
       -q
  cat "${SSH_DIR}/${SSH_KEY_NAME}.pub" >> "${SSH_DIR}/authorized_keys"
  chmod 600 "${SSH_DIR}/authorized_keys"
  chown "$RUN_USER:$RUN_USER" "${SSH_DIR}/authorized_keys"   # ← FIX
fi

echo "[+] Hardening sshd_config (key-only auth, no root) …"
sed -i -E \
  -e 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' \
  -e 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' \
  -e 's/^#?UsePAM .*/UsePAM no/' \
  -e 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' \
  -e 's/^#?PermitRootLogin .*/PermitRootLogin no/' \
  /etc/ssh/sshd_config
systemctl restart ssh

# ── Show access instructions ────────────────────────────────────────────────
ETH0_IP=$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)

echo -e "\n✅  DVWA stack ready."
echo "1. Browse to   http://${ETH0_IP}/DVWA"
echo "2. Login: admin / password"
echo "3. Click “Create/Reset Database”, then set DVWA Security → Low."
echo "4. SSH available for user '${RUN_USER}' on port 22 (key-only)."
