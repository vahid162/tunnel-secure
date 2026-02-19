#!/usr/bin/env bash
set -euo pipefail

blue() { printf '\033[34m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  red "Please run as root: sudo bash $0"
  exit 1
fi

blue "=== Tunnel Secure Audit (read-only) ==="

blue "[1/8] SSH service status"
if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
  green "SSH service is active."
else
  red "SSH service is not active."
fi

blue "[2/8] Effective SSH port(s)"
sshd -T 2>/dev/null | awk '/^port /{print "- "$2}' || yellow "Could not read sshd effective config."

blue "[3/8] SSH hardening drop-in"
if [[ -f /etc/ssh/sshd_config.d/00-tunnel-secure.conf ]]; then
  green "Found /etc/ssh/sshd_config.d/00-tunnel-secure.conf"
  sed -n '1,120p' /etc/ssh/sshd_config.d/00-tunnel-secure.conf
else
  yellow "Drop-in file not found."
fi

blue "[4/8] UFW status (verbose)"
if command -v ufw >/dev/null 2>&1; then
  ufw status verbose || true
  echo
  blue "UFW numbered rules"
  ufw status numbered || true
else
  yellow "ufw is not installed."
fi

blue "[5/8] Fail2ban service/jail status"
if systemctl is-active --quiet fail2ban; then
  green "fail2ban service is active."
  if command -v fail2ban-client >/dev/null 2>&1; then
    fail2ban-client status || true
    echo
    fail2ban-client status sshd || true
  else
    yellow "fail2ban-client command not found."
  fi
else
  yellow "fail2ban service is not active."
fi

blue "[6/8] Listening TCP ports"
ss -lntp || true

blue "[7/8] Tunnel interfaces"
ip -br a | awk '{print $1, $2, $3}' | grep -Ei '^(gre|GRE|tun|tap)' || yellow "No GRE/TUN/TAP interface found."

blue "[8/8] Recent backups"
if [[ -d /root/tunnel-secure-backups ]]; then
  ls -1t /root/tunnel-secure-backups | head -n 20
else
  yellow "/root/tunnel-secure-backups directory not found."
fi

green "Audit completed. This script made no configuration changes."
