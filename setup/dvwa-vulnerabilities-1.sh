#!/usr/bin/env bash
#
# dvwa_vulnerabilities_1.sh ― toggle the DVWA VM between
# “vulnerable-lab” and “patched” states in one shot.
#
# USAGE:   sudo ./dvwa_vulnerabilities.sh  vuln   # open all the holes
#          sudo ./dvwa_vulnerabilities.sh  patch  # close them again
#
# NOTE:    Every change here is **intentional** for a teaching lab.
#          Do NOT run on anything that matters.

set -euo pipefail

########## constants ###########################################################
PHP_INI="/etc/php/8.4/apache2/php.ini"        # adjust if your PHP version differs
SSH_KEY="/home/kali/.ssh/id_rsa"              # deliberately exposed private key
ACCESS_LOG="/var/log/apache2/access.log"      # Apache access log (LFI target)
DVWA_PATH="/var/www/html/DVWA"                # DVWA webroot
################################################################################

die() { echo "[-] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run me with sudo/root."
[[ $# -eq 1 ]]    || die "Usage: $0  vuln|patch"

case "$1" in
  vuln|patch) mode="$1" ;;
  *)          die "Argument must be either “vuln” or “patch”." ;;
esac

echo "[*] Switching to $mode state …"

###############################################################################
# 1. SSH-key permissions
###############################################################################
if [[ $mode == vuln ]]; then
  chmod 755 /home/kali /home/kali/.ssh
  chmod 644 "$SSH_KEY"
else
  chmod 700 /home/kali /home/kali/.ssh
  chmod 600 "$SSH_KEY"
fi

###############################################################################
# 2. /etc/passwd world-writable toggle  (+ cleanup of injected user)
###############################################################################
if [[ $mode == vuln ]]; then
  chmod 666 /etc/passwd
else
  sed -i '/^hacker:.*:0:0:/d' /etc/passwd      # drop the back-door account
  chmod 644 /etc/passwd
fi

###############################################################################
# 3. Apache-log LFI helper: www-data ↔ adm group membership
###############################################################################
if [[ $mode == vuln ]]; then
  usermod -aG adm www-data
else
  gpasswd -d www-data adm >/dev/null 2>&1 || true
  # Clean up any one-liner PHP shell injected via access-log LFI
  sed -i '/<?php echo system(/d' "$ACCESS_LOG" 2>/dev/null || true
fi

###############################################################################
# 4. MariaDB FILE privilege (OUTFILE / LOAD_FILE)
###############################################################################
if [[ $mode == vuln ]]; then
  mysql -u root -e "GRANT FILE ON *.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
else
  mysql -u root -e "REVOKE FILE ON *.* FROM 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
  # Remove web shell dropped via INTO OUTFILE
  rm -f "/var/www/html/sqlishell.php"
  rm -f "/var/www/html/DVWA/hackable/uploads/shell.php"
fi

###############################################################################
# 5. PHP RFI knobs
###############################################################################
if [[ $mode == vuln ]]; then
  sed -Ei.bak \
    -e 's/^\s*allow_url_include\s*=.*/allow_url_include = On/'  \
    -e 's/^\s*allow_url_fopen\s*=.*/allow_url_fopen   = On/'   "$PHP_INI"
else
  sed -Ei.bak \
    -e 's/^\s*allow_url_include\s*=.*/allow_url_include = Off/' \
    -e 's/^\s*allow_url_fopen\s*=.*/allow_url_fopen   = Off/'  "$PHP_INI"
fi

###############################################################################
# 6. House-keeping
###############################################################################
systemctl restart apache2   # needed for items 3 & 5

echo "[+] Done — system now in “$mode” state."
