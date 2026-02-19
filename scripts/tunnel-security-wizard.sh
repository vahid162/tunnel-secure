#!/usr/bin/env bash
set -euo pipefail

SCRIPT_VERSION="1.4.11"
BACKUP_DIR="/root/tunnel-secure-backups"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    red "This script must be run as root."
    echo "Suggested command: sudo bash $0"
    exit 1
  fi
}

is_valid_ipv4() {
  local ip="$1"
  local IFS='.'
  local -a octets
  read -r -a octets <<< "$ip"
  [[ ${#octets[@]} -eq 4 ]] || return 1
  for o in "${octets[@]}"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
}

validate_ipv4_or_cidr() {
  local input="$1"
  local ip="${input%%/*}"
  local cidr=""

  if [[ "$input" == */* ]]; then
    cidr="${input##*/}"
    [[ "$cidr" =~ ^[0-9]+$ ]] || return 1
    (( cidr >= 0 && cidr <= 32 )) || return 1
  fi

  is_valid_ipv4 "$ip"
}

validate_ipv4_or_cidr_list() {
  local input_csv="$1"
  local -a ip_list
  local item

  IFS=',' read -r -a ip_list <<< "$input_csv"
  [[ ${#ip_list[@]} -gt 0 ]] || return 1

  for item in "${ip_list[@]}"; do
    item="$(echo "$item" | xargs)"
    [[ -n "$item" ]] || return 1
    validate_ipv4_or_cidr "$item" || return 1
  done
}

normalize_csv_unique() {
  local input_csv="$1"
  awk -v RS=',' '
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 != "" && !seen[$0]++) out = out (out ? "," : "") $0
    }
    END {print out}
  ' <<< "$input_csv"
}

auto_detect_ssh_tunnel_peer_ip() {
  local ssh_port="$1"
  local admin_ip="$2"
  ss -tn state established "( sport = :${ssh_port} )" 2>/dev/null     | awk -v admin_ip="$admin_ip" 'NR>1 {split($5,a,":"); ip=a[1]; gsub(/\[|\]/,"",ip); if (ip != "" && ip != admin_ip) print ip}'     | awk '!seen[$0]++' | head -n1 || true
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

validate_iface_exists() {
  local iface="$1"
  ip link show "$iface" >/dev/null 2>&1
}

ask() {
  local prompt="$1"
  local default="${2:-}"
  local answer
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " answer
    answer="${answer:-$default}"
  else
    read -r -p "$prompt: " answer
  fi
  printf '%s' "$answer"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local answer
  while true; do
    read -r -p "$prompt (y/n) [${default}]: " answer
    answer="${answer:-$default}"
    case "$answer" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) yellow "Please enter only y or n." ;;
    esac
  done
}

backup_file() {
  local src="$1"
  mkdir -p "$BACKUP_DIR"
  if [[ -f "$src" ]]; then
    cp -a "$src" "$BACKUP_DIR/$(basename "$src").$(date +%F-%H%M%S).bak"
  fi
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    apt-get install -y "$pkg"
  fi
}

auto_detect_admin_ip() {
  if [[ -n "${SSH_CLIENT:-}" ]]; then
    awk '{print $1}' <<< "$SSH_CLIENT"
    return 0
  fi

  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    awk '{print $1}' <<< "$SSH_CONNECTION"
    return 0
  fi

  who am i 2>/dev/null | awk '{print $NF}' | tr -d '()' | awk 'NF{print; exit}' || true
}

auto_detect_ssh_access_mode() {
  local admin_ip="$1"
  if validate_ipv4_or_cidr "$admin_ip"; then
    echo "restricted"
  else
    echo "open"
  fi
}

auto_detect_ssh_port() {
  sshd -T 2>/dev/null | awk '/^port /{print $2; exit}' || true
}

auto_detect_mgmt_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}' || true
}

auto_detect_wan_iface() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' || true
}

auto_detect_gre_iface() {
  ip -br a 2>/dev/null | awk '{print $1}' | grep -Ei '^(gre[0-9]*|GRE(@NONE)?)$' | head -n1 || true
}

auto_detect_gre_peer() {
  local iface="$1"
  [[ -n "$iface" ]] || return 0
  ip tunnel show "$iface" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="remote") {print $(i+1); exit}}' || true
}

has_gre_tunnel() {
  ip -d link show 2>/dev/null | grep -Eiq '\bgre\b|\bgretap\b|\berspan\b' && return 0
  ip -br a 2>/dev/null | awk '{print $1}' | grep -Eiq '^(gre[0-9]*|GRE(@NONE)?)$'
}

has_ssh_tunnel_signals() {
  ip -br a 2>/dev/null | awk '{print $1}' | grep -Eiq '^(tun|tap)[0-9]+'
}

auto_detect_tunnel_mode() {
  local has_gre="no"
  local has_ssh="no"

  if has_gre_tunnel; then
    has_gre="yes"
  fi

  if has_ssh_tunnel_signals; then
    has_ssh="yes"
  fi

  if [[ "$has_gre" == "yes" && "$has_ssh" == "yes" ]]; then
    echo "both"
  elif [[ "$has_gre" == "yes" ]]; then
    echo "gre"
  elif [[ "$has_ssh" == "yes" ]]; then
    echo "ssh"
  else
    echo "ssh"
  fi
}

configure_sshd() {
  local ssh_port="$1"
  local disable_password="$2"
  local allow_users="$3"
  local ssh_dropin="/etc/ssh/sshd_config.d/00-tunnel-secure.conf"

  blue "\n[SSH] Applying secure SSH settings..."
  mkdir -p /etc/ssh/sshd_config.d
  backup_file "$ssh_dropin"

  {
    echo "# Generated by tunnel-security-wizard"
    echo "Port ${ssh_port}"
    echo "PermitRootLogin prohibit-password"
    if [[ "$disable_password" == "yes" ]]; then
      echo "PasswordAuthentication no"
      echo "KbdInteractiveAuthentication no"
      echo "ChallengeResponseAuthentication no"
    else
      echo "PasswordAuthentication yes"
    fi

    if [[ -n "$allow_users" ]]; then
      echo "AllowUsers ${allow_users}"
    fi
  } > "$ssh_dropin"

  if sshd -t; then
    systemctl restart ssh || systemctl restart sshd
    green "SSH settings applied successfully."
  else
    red "Invalid SSH config detected. Attempting rollback..."
    rm -f "$ssh_dropin"
    latest_backup="$(ls -1t "$BACKUP_DIR"/00-tunnel-secure.conf.*.bak 2>/dev/null | head -n1 || true)"
    if [[ -n "${latest_backup:-}" ]]; then
      cp -a "$latest_backup" "$ssh_dropin"
    fi
    exit 1
  fi
}

configure_fail2ban() {
  local ssh_port="$1"
  local fail2ban_ignoreip_csv="${2:-}"
  blue "\n[Fail2ban] Enabling brute-force protection..."
  ensure_package fail2ban
  backup_file /etc/fail2ban/jail.local

  cat > /etc/fail2ban/jail.local <<EOC
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ${ssh_port}
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOC

  if [[ -n "$fail2ban_ignoreip_csv" ]]; then
    normalized_ignoreip="$(normalize_csv_unique "$fail2ban_ignoreip_csv")"
    if [[ -n "$normalized_ignoreip" ]]; then
      sed -i "s|^ignoreip = .*|ignoreip = 127.0.0.1/8 ::1 ${normalized_ignoreip//,/ }|" /etc/fail2ban/jail.local
    fi
  fi

  systemctl enable --now fail2ban
  green "Fail2ban enabled successfully."
}

configure_ufw() {
  local mgmt_ip_csv="$1"
  local ssh_port="$2"
  local tunnel_mode="$3"
  local gre_peer_ip="$4"
  local extra_ports_csv="$5"
  local gre_iface="$6"
  local enable_forwarding="$7"
  local wan_iface="$8"
  local ssh_access_mode="$9"

  blue "\n[Firewall/UFW] Applying firewall rules while preserving tunnel access..."
  ensure_package ufw
  backup_file /etc/default/ufw
  mkdir -p "$BACKUP_DIR"
  tar -czf "$BACKUP_DIR/ufw.$(date +%F-%H%M%S).tar.gz" /etc/ufw >/dev/null 2>&1 || true

  ufw --force disable
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  if [[ "$ssh_access_mode" == "open" ]]; then
    ufw allow "$ssh_port"/tcp comment 'ssh open with fail2ban'
  else
    IFS="," read -r -a mgmt_ip_list <<< "$mgmt_ip_csv"
    for admin_ip in "${mgmt_ip_list[@]}"; do
      admin_ip="$(echo "$admin_ip" | xargs)"
      [[ -z "$admin_ip" ]] && continue
      ufw allow from "$admin_ip" to any port "$ssh_port" proto tcp comment 'admin ssh restricted'
    done
  fi

  IFS=',' read -r -a extra_ports <<< "$extra_ports_csv"
  for p in "${extra_ports[@]}"; do
    p="$(echo "$p" | xargs)"
    [[ -z "$p" ]] && continue
    ufw allow "$p" comment 'tunnel service'
  done

  if [[ "$tunnel_mode" == "gre" || "$tunnel_mode" == "both" ]]; then
    ufw allow proto gre from "$gre_peer_ip" to any comment 'gre peer'
  fi

  if [[ "$enable_forwarding" == "yes" && -n "$gre_iface" && -n "$wan_iface" ]]; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw || true
    if ! grep -q '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw; then
      echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> /etc/default/ufw
    fi
    ufw route allow in on "$gre_iface" out on "$wan_iface" comment 'gre forward out'
    ufw route allow in on "$wan_iface" out on "$gre_iface" comment 'gre forward back'
  fi

  ufw --force enable
  ufw status verbose
  green "UFW enabled successfully."
}

configure_sysctl_for_gre() {
  local gre_iface="$1"
  local enable_forwarding="$2"
  blue "\n[Sysctl] Applying GRE-compatible kernel settings..."
  backup_file /etc/sysctl.d/99-tunnel-secure.conf

  cat > /etc/sysctl.d/99-tunnel-secure.conf <<EOC
# Generated by tunnel-security-wizard
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.${gre_iface}.rp_filter=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
EOC

  if [[ "$enable_forwarding" == "yes" ]]; then
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-tunnel-secure.conf
  fi

  sysctl --system >/dev/null
  green "Sysctl settings applied successfully."
}

main() {
  need_root

  blue "============================================"
  blue " Tunnel Security Wizard v${SCRIPT_VERSION}"
  blue "============================================"
  yellow "This wizard can auto-detect SSH/GRE tunnel signals and suggest safe defaults."
  yellow "Before applying final changes, make sure you have emergency console access."

  if ! ask_yes_no "Do you want to continue?" "y"; then
    echo "Exit."
    exit 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update >/dev/null

  detected_admin_ip="$(auto_detect_admin_ip)"
  detected_mgmt_ip="$detected_admin_ip"
  [[ -z "$detected_mgmt_ip" ]] && detected_mgmt_ip="$(auto_detect_mgmt_ip)"
  detected_ssh_port="$(auto_detect_ssh_port)"
  detected_tunnel_mode="$(auto_detect_tunnel_mode)"
  detected_gre_iface="$(auto_detect_gre_iface)"
  detected_gre_peer="$(auto_detect_gre_peer "$detected_gre_iface")"
  detected_wan_iface="$(auto_detect_wan_iface)"
  detected_ssh_access_mode="$(auto_detect_ssh_access_mode "$detected_mgmt_ip")"
  detected_ssh_tunnel_peer_ip="$(auto_detect_ssh_tunnel_peer_ip "$detected_ssh_port" "$detected_admin_ip")"

  [[ -z "$detected_mgmt_ip" ]] && detected_mgmt_ip="1.2.3.4"
  [[ -z "$detected_ssh_port" ]] && detected_ssh_port="22"
  [[ -z "$detected_gre_iface" ]] && detected_gre_iface="gre1"

  yellow "Auto-detected defaults:"
  echo "  Management IP: $detected_mgmt_ip"
  echo "  SSH Port: $detected_ssh_port"
  echo "  Tunnel Mode: $detected_tunnel_mode"
  echo "  GRE Interface: $detected_gre_iface"
  echo "  GRE Peer IP: ${detected_gre_peer:-not-detected}"
  echo "  WAN Interface: ${detected_wan_iface:-not-detected}"
  echo "  SSH Firewall Mode: $detected_ssh_access_mode"
  echo "  SSH Tunnel Peer IP (auto): ${detected_ssh_tunnel_peer_ip:-not-detected}"

  mgmt_ip_csv="$(ask 'Management IP/CIDR list for SSH allow (comma-separated, example: 1.2.3.4/32,5.6.7.8)' "$detected_mgmt_ip")"
  if ! validate_ipv4_or_cidr_list "$mgmt_ip_csv"; then
    red "Invalid management IP list format. Use comma-separated IPv4 or CIDR values only."
    exit 1
  fi

  ssh_port="$(ask 'Current SSH port' "$detected_ssh_port")"
  if ! validate_port "$ssh_port"; then
    red "Invalid SSH port. Must be a number between 1 and 65535."
    exit 1
  fi

  case "$detected_tunnel_mode" in
    ssh) mode_default="1" ;;
    gre) mode_default="2" ;;
    both) mode_default="3" ;;
    *) mode_default="3" ;;
  esac

  tunnel_mode_choice="$(ask 'Tunnel mode? (1=ssh-tunnel , 2=gre-4 , 3=both)' "$mode_default")"
  tunnel_mode="both"
  gre_peer_ip=""
  gre_iface="$detected_gre_iface"
  enable_forwarding="no"
  wan_iface="$detected_wan_iface"

  case "$tunnel_mode_choice" in
    1) tunnel_mode="ssh" ;;
    2) tunnel_mode="gre" ;;
    3) tunnel_mode="both" ;;
    *) yellow "Invalid option; defaulting to detected mode ($detected_tunnel_mode)."; tunnel_mode="$detected_tunnel_mode" ;;
  esac

  ssh_access_mode_default="2"
  yellow "Default is set to open + Fail2ban (option 2) to reduce accidental SSH lockout risk for beginners."

  ssh_access_mode="restricted"
  yellow "WARNING: If you select restricted mode (option 1), only the Management IP list can SSH. If current/backup admin IP is missing, you may lose SSH access (lockout). Keep console/KVM access ready."
  ssh_access_mode_choice="$(ask 'SSH firewall mode? (1=restrict to management IP, 2=open SSH port and rely on Fail2ban)' "$ssh_access_mode_default")"
  case "$ssh_access_mode_choice" in
    1) ssh_access_mode="restricted" ;;
    2) ssh_access_mode="open" ;;
    *)
      yellow "Invalid option; defaulting to detected SSH firewall mode ($detected_ssh_access_mode)."
      ssh_access_mode="$detected_ssh_access_mode"
      ;;
  esac

  trusted_tunnel_peer_ip=""
  if [[ "$tunnel_mode" == "ssh" || "$tunnel_mode" == "both" ]]; then
    trusted_tunnel_peer_ip="$(ask 'Trusted SSH tunnel peer IP for allowlist/Fail2ban ignore (leave empty to skip)' "${detected_ssh_tunnel_peer_ip:-}")"
    if [[ -n "$trusted_tunnel_peer_ip" ]] && ! validate_ipv4_or_cidr "$trusted_tunnel_peer_ip"; then
      red "Invalid trusted SSH tunnel peer IP format."
      exit 1
    fi

    if [[ -n "$trusted_tunnel_peer_ip" ]]; then
      mgmt_ip_csv="$(normalize_csv_unique "$mgmt_ip_csv,$trusted_tunnel_peer_ip")"
      yellow "Trusted SSH tunnel peer IP added to management allowlist automatically: $trusted_tunnel_peer_ip"
    fi
  fi

  extra_ports_csv=""
  if [[ "$tunnel_mode" == "ssh" || "$tunnel_mode" == "both" ]]; then
    extra_ports_csv="$(ask 'SSH tunnel service port(s), comma-separated (example: 443/tcp,80/tcp)' '')"
  fi

  if [[ "$tunnel_mode" == "gre" || "$tunnel_mode" == "both" ]]; then
    gre_peer_ip="$(ask 'GRE peer IP (remote tunnel endpoint)' "${detected_gre_peer:-}")"
    if ! validate_ipv4_or_cidr "$gre_peer_ip"; then
      red "Invalid GRE peer IP format."
      exit 1
    fi

    gre_iface="$(ask 'GRE interface name (example: gre1)' "$gre_iface")"
    if ! validate_iface_exists "$gre_iface"; then
      red "GRE interface not found: $gre_iface"
      echo "Use this command to list interfaces: ip -br link"
      exit 1
    fi

    if ask_yes_no "Is GRE used for traffic forwarding/routing?" "n"; then
      enable_forwarding="yes"
      wan_iface="$(ask 'WAN interface name (example: eth0)' "$wan_iface")"
      if ! validate_iface_exists "$wan_iface"; then
        red "WAN interface not found: $wan_iface"
        echo "Use this command to list interfaces: ip -br link"
        exit 1
      fi
    fi
  fi

  disable_password="no"
  if ask_yes_no "Disable SSH password login? (answer y only if SSH key auth is ready)" "n"; then
    disable_password="yes"
  fi

  allow_users=""
  if ask_yes_no "Limit SSH access to specific user(s)?" "n"; then
    allow_users="$(ask 'Username(s) separated by spaces (example: admin deploy)')"
  fi

  if ask_yes_no "Apply SSH hardening settings now?" "y"; then
    configure_sshd "$ssh_port" "$disable_password" "$allow_users"
  fi

  if ask_yes_no "Install and enable Fail2ban now?" "y"; then
    configure_fail2ban "$ssh_port" "$trusted_tunnel_peer_ip"
  fi

  if [[ "$tunnel_mode" == "gre" || "$tunnel_mode" == "both" ]]; then
    if ask_yes_no "Apply GRE-compatible sysctl settings now?" "y"; then
      configure_sysctl_for_gre "$gre_iface" "$enable_forwarding"
    fi
  fi

  if ask_yes_no "Apply and enable UFW firewall now?" "y"; then
    configure_ufw "$mgmt_ip_csv" "$ssh_port" "$tunnel_mode" "$gre_peer_ip" "$extra_ports_csv" "$gre_iface" "$enable_forwarding" "$wan_iface" "$ssh_access_mode"
  fi

  green "\nDone. Backups were saved in: $BACKUP_DIR"
  yellow "Recommendation: open a new SSH session and verify connectivity before closing this one."
}

main "$@"
