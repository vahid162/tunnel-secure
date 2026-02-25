#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIZARD="$ROOT_DIR/scripts/tunnel-security-wizard.sh"
AUDIT="$ROOT_DIR/scripts/tunnel-security-audit.sh"
EMERGENCY="$ROOT_DIR/scripts/tunnel-security-emergency-ssh-recover.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; exit 1; }

bash -n "$WIZARD" || fail "wizard syntax check failed"
pass "wizard syntax"

bash -n "$AUDIT" || fail "audit syntax check failed"
pass "audit syntax"

bash -n "$EMERGENCY" || fail "emergency recover syntax check failed"
pass "emergency recover syntax"

# shellcheck disable=SC1090
source "$WIZARD"

validate_ipv4_or_cidr "1.2.3.4" || fail "validate_ipv4_or_cidr failed for IPv4"
validate_ipv4_or_cidr "1.2.3.4/32" || fail "validate_ipv4_or_cidr failed for CIDR"
! validate_ipv4_or_cidr "1.2.3.999" >/dev/null 2>&1 || fail "validate_ipv4_or_cidr accepted invalid IP"
pass "ipv4/cidr validation"

validate_ipv4_or_cidr_list "1.1.1.1,2.2.2.2/32" || fail "validate_ipv4_or_cidr_list failed"
! validate_ipv4_or_cidr_list "1.1.1.1,bad-ip" >/dev/null 2>&1 || fail "validate_ipv4_or_cidr_list accepted invalid input"
pass "ipv4 list validation"


validate_ipv4_list "1.2.3.4,5.6.7.8" || fail "validate_ipv4_list failed for IPv4 list"
! validate_ipv4_list "1.2.3.4/32" >/dev/null 2>&1 || fail "validate_ipv4_list accepted CIDR"
pass "ipv4-only list validation"

validate_port_list_csv "22335/tcp,443/tcp" || fail "validate_port_list_csv failed for valid list"
! validate_port_list_csv "bad-format" >/dev/null 2>&1 || fail "validate_port_list_csv accepted invalid format"
pass "port list csv validation"

[[ "$(normalize_csv_unique '1.1.1.1, 1.1.1.1,2.2.2.2')" == "1.1.1.1,2.2.2.2" ]] || fail "normalize_csv_unique did not deduplicate"
pass "csv normalization"

validate_permit_root_login_mode "yes" || fail "permit root login mode validation failed for yes"
validate_permit_root_login_mode "prohibit-password" || fail "permit root login mode validation failed for prohibit-password"
! validate_permit_root_login_mode "invalid" >/dev/null 2>&1 || fail "permit root login mode validation accepted invalid value"
pass "permit root login mode validation"


# Validate auto-detect tunnel mode decision matrix with controlled function overrides
has_gre_tunnel() { return 1; }
has_ssh_tunnel_signals() { return 1; }
has_repo_gre_signals() { return 1; }
has_repo_ssh_tunnel_signals() { return 1; }
[[ "$(auto_detect_tunnel_mode)" == "ssh" ]] || fail "auto_detect_tunnel_mode default fallback should be ssh"

has_gre_tunnel() { return 0; }
has_ssh_tunnel_signals() { return 1; }
has_repo_gre_signals() { return 1; }
has_repo_ssh_tunnel_signals() { return 1; }
[[ "$(auto_detect_tunnel_mode)" == "gre" ]] || fail "auto_detect_tunnel_mode should detect gre when only gre is present"

has_gre_tunnel() { return 1; }
has_ssh_tunnel_signals() { return 0; }
has_repo_gre_signals() { return 1; }
has_repo_ssh_tunnel_signals() { return 1; }
[[ "$(auto_detect_tunnel_mode)" == "ssh" ]] || fail "auto_detect_tunnel_mode should detect ssh when only ssh is present"

has_gre_tunnel() { return 0; }
has_ssh_tunnel_signals() { return 0; }
has_repo_gre_signals() { return 1; }
has_repo_ssh_tunnel_signals() { return 1; }
[[ "$(auto_detect_tunnel_mode)" == "both" ]] || fail "auto_detect_tunnel_mode should detect both when both are present"
pass "auto_detect_tunnel_mode decision matrix"

if ! grep -q 'Tunnel mode? (1=ssh-tunnel , 2=gre-4 , 3=both)' "$WIZARD"; then
  fail "tunnel mode prompt missing"
fi
pass "tunnel mode prompt present"

if ! grep -q 'SSH firewall mode? (1=restrict to management IP, 2=open SSH port and rely on Fail2ban)' "$WIZARD"; then
  fail "ssh firewall prompt missing"
fi
pass "ssh firewall prompt present"

if ! grep -q 'SSH PermitRootLogin mode? (yes | prohibit-password | no | forced-commands-only)' "$WIZARD"; then
  fail "ssh PermitRootLogin prompt missing"
fi
pass "ssh PermitRootLogin prompt present"

if ! grep -q '\[\[ -z "\$detected_permit_root_login" \]\] && detected_permit_root_login="prohibit-password"' "$WIZARD"; then
  fail "secure default for PermitRootLogin fallback missing"
fi
pass "secure default PermitRootLogin fallback present"

if ! grep -q 'if \[\[ "\$tunnel_mode" == "gre" || "\$tunnel_mode" == "both" \]\]; then' "$WIZARD"; then
  fail "gre/both branch missing"
fi
pass "gre/both branch present"

if ! grep -q 'if \[\[ "\$tunnel_mode" == "ssh" || "\$tunnel_mode" == "both" \]\]; then' "$WIZARD"; then
  fail "ssh/both branch missing"
fi
pass "ssh/both branch present"

if ! grep -q '^ignoreip = 127.0.0.1/8 ::1' "$WIZARD"; then
  fail "fail2ban ignoreip baseline missing"
fi
pass "fail2ban ignoreip baseline present"

if ! grep -q 'auto_detect_existing_ufw_admin_ips' "$WIZARD"; then
  fail "rerun safety auto-detect for ufw admin ips missing"
fi
pass "rerun safety checks present"
if ! grep -q 'auto_detect_existing_ufw_tunnel_ports' "$WIZARD"; then
  fail "auto-detect for ufw tunnel ports missing"
fi
if ! grep -q 'auto_detect_listening_service_ports' "$WIZARD"; then
  fail "auto-detect for listening service ports missing"
fi
if ! grep -q 'auto_detect_likely_tunnel_peer_ips' "$WIZARD"; then
  fail "auto-detect for likely tunnel peer ips missing"
fi
if ! grep -q 'has_repo_gre_signals' "$WIZARD"; then
  fail "repo-based gre detection missing"
fi
if ! grep -q 'has_repo_ssh_tunnel_signals' "$WIZARD"; then
  fail "repo-based ssh-tunnel detection missing"
fi
pass "tunnel auto-detection checks present"


if ! grep -q 'Select mode (1=apply/update security, 2=rollback to previous restore point)' "$WIZARD"; then
  fail "operation mode prompt missing"
fi
pass "operation mode prompt present"

if ! grep -q '^create_restore_point() {' "$WIZARD"; then
  fail "create_restore_point function missing"
fi
if ! grep -q '^run_rollback_flow() {' "$WIZARD"; then
  fail "run_rollback_flow function missing"
fi
if ! grep -q '^restore_or_remove_snapshot_file() {' "$WIZARD"; then
  fail "restore_or_remove_snapshot_file function missing"
fi
pass "rollback flow functions present"

printf '\nAll self-tests passed.\n'
