#!/usr/bin/env bash
#
# dvwa_toggle.sh — flip the VM between a deliberately VULNERABLE lab
# configuration and a PATCHED configuration.
#
# USAGE:   sudo ./dvwa_toggle.sh  vuln   # open all the holes
#          sudo ./dvwa_toggle.sh  patch  # close them again
#
# NOTE:    Every change here is *intentional* for a teaching lab.
#          Do **NOT** run on anything that matters.

set -euo pipefail

############################  CONSTANTS  ######################################
PHP_INI="/etc/php/8.4/apache2/php.ini"          # adjust if PHP version differs
SSH_KEY="/home/kali/.ssh/id_rsa"                # key we deliberately expose
DVWA_PATH="/var/www/html"                       # web‑root of DVWA install
APACHE_CONF="/etc/apache2/sites-available/000-default.conf"
: "${ACCESS_LOG:=/var/log/apache2/access.log}"  # LFI helper drops shell here; ensure it is always set
###############################################################################

die() { echo "[-] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]]                || die "Run me with sudo/root."
[[ $# -eq 1 ]]                   || die "Usage: $0  vuln|patch"
[[ $1 =~ ^(vuln|patch)$ ]]       || die "Argument must be either 'vuln' or 'patch'"
MODE="$1"

echo "[*] Switching DVWA to $MODE mode …"

###############################################################################
# 1. PHP insecure settings (allow_url_include, display_errors)
###############################################################################
if [[ $MODE == vuln ]]; then
  sed -i 's/^allow_url_include.*/allow_url_include = On/'  "$PHP_INI"
  sed -i 's/^display_errors.*/display_errors = On/'        "$PHP_INI"
else
  sed -i 's/^allow_url_include.*/allow_url_include = Off/' "$PHP_INI"
  sed -i 's/^display_errors.*/display_errors = Off/'       "$PHP_INI"
fi

###############################################################################
# 2. Expose or hide a private SSH key in the web root
###############################################################################
if [[ $MODE == vuln ]]; then
  cp -f "$SSH_KEY" "$DVWA_PATH/id_rsa"
  chmod 644 "$DVWA_PATH/id_rsa"
else
  rm -f "$DVWA_PATH/id_rsa"
fi

###############################################################################
# 3. Apache‑log LFI helper: www-data ↔ adm group membership
###############################################################################
if [[ $MODE == vuln ]]; then
  usermod -aG adm www-data
else
  gpasswd -d www-data adm >/dev/null 2>&1 || true   # suppress "Removing user …" line
  # Clean any one‑liner PHP shell injected via access‑log LFI
  if [[ -f "$ACCESS_LOG" ]]; then
    sed -i '/<?php echo system(/d' "$ACCESS_LOG" || true
  fi
fi

###############################################################################
# 4. MariaDB FILE privilege (OUTFILE / LOAD_FILE) & rogue web‑shell cleanup
###############################################################################
if [[ $MODE == vuln ]]; then
  mysql -u root -e "GRANT FILE ON *.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
else
  mysql -u root -e "REVOKE FILE ON *.* FROM 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
  # Remove web‑shells dropped via INTO OUTFILE in the web root
  rm -f "$DVWA_PATH/shell.php"
fi

###############################################################################
# 5. Directory indexing (Apache) – reload after edits
###############################################################################
if [[ $MODE == vuln ]]; then
  sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/s/Options .*/Options Indexes FollowSymLinks/' "$APACHE_CONF"
else
  sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/s/Options .*/Options -Indexes FollowSymLinks/' "$APACHE_CONF"
fi
systemctl reload apache2

echo "[+] Done – DVWA is now in $MODE mode."
