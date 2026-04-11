#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="ADQH"
ADQH_REPO_URL="${ADQH_REPO_URL:-https://github.com/Nanja-at-web/ADQH.git}"
ADQH_BRANCH="${ADQH_BRANCH:-main}"

var_tags="${var_tags:-automation;gaming}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

get_ctid() {
  if [[ -n "${CTID:-}" ]]; then
    echo "$CTID"
    return
  fi
  if [[ -n "${CONTAINERID:-}" ]]; then
    echo "$CONTAINERID"
    return
  fi
  pct list | awk 'NR>1 {print $1}' | tail -n1
}

exec_ct() {
  local ctid="$1"
  shift
  pct exec "$ctid" -- bash -lc "$*"
}

write_ct_file() {
  local ctid="$1"
  local target="$2"
  local content="$3"
  pct exec "$ctid" -- bash -lc "cat > '$target' <<'EOF'
$content
EOF"
}

fix_apt_sources_ct() {
  local ctid="$1"
  msg_info "Fixing APT sources in CT ${ctid}"
  exec_ct "$ctid" "find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.sources' | while read -r file; do if grep -q 'enterprise\\.proxmox\\.com' \"\$file\" 2>/dev/null; then rm -f \"\$file\"; fi; done"
  exec_ct "$ctid" "find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list' | while read -r file; do sed -i '/enterprise\\.proxmox\\.com/d' \"\$file\" || true; if [[ ! -s \"\$file\" ]]; then rm -f \"\$file\"; fi; done"
  exec_ct "$ctid" "if [[ -f /etc/apt/sources.list.d/proxmox.sources ]] && [[ -f /etc/apt/sources.list.d/pve-no-subscription.list ]]; then rm -f /etc/apt/sources.list.d/pve-no-subscription.list; fi"
  msg_ok "APT sources fixed in CT ${ctid}"
}

install_app_in_ct() {
  local ctid="$1"

  msg_info "Installing dependencies in CT ${ctid}"
  fix_apt_sources_ct "$ctid"
  exec_ct "$ctid" "apt-get update"
  exec_ct "$ctid" "apt-get install -y curl git ca-certificates python3 python3-venv python3-pip build-essential"
  msg_ok "Installed dependencies in CT ${ctid}"

  msg_info "Cloning ADQH repository in CT ${ctid}"
  exec_ct "$ctid" "rm -rf /opt/adqh && git clone --branch '$ADQH_BRANCH' '$ADQH_REPO_URL' /opt/adqh"
  msg_ok "Cloned ADQH repository in CT ${ctid}"

  msg_info "Setting up Python virtual environment in CT ${ctid}"
  exec_ct "$ctid" "python3 -m venv /opt/adqh/.venv"
  exec_ct "$ctid" "/opt/adqh/.venv/bin/pip install --upgrade pip setuptools wheel"
  exec_ct "$ctid" "if [[ -f /opt/adqh/requirements.txt ]]; then /opt/adqh/.venv/bin/pip install -r /opt/adqh/requirements.txt; fi"
  exec_ct "$ctid" "/opt/adqh/.venv/bin/pip install /opt/adqh"
  msg_ok "Set up Python environment in CT ${ctid}"

  msg_info "Preparing directories in CT ${ctid}"
  exec_ct "$ctid" "install -d -m 0755 /etc/adqh /var/lib/adqh"
  exec_ct "$ctid" "if [[ -f /opt/adqh/deploy/adqh.env.example ]] && [[ ! -f /etc/adqh/adqh.env ]]; then install -m 0640 /opt/adqh/deploy/adqh.env.example /etc/adqh/adqh.env; fi"
  msg_ok "Prepared directories in CT ${ctid}"

  msg_info "Installing systemd units in CT ${ctid}"
  exec_ct "$ctid" "install -D -m 0644 /opt/adqh/deploy/adqh.service /etc/systemd/system/adqh.service"
  exec_ct "$ctid" "install -D -m 0644 /opt/adqh/deploy/adqh.timer /etc/systemd/system/adqh.timer"
  exec_ct "$ctid" "systemctl daemon-reload && systemctl enable --now adqh.timer"
  msg_ok "Installed systemd units in CT ${ctid}"
}

update_script() {
  header_info
  local ctid
  ctid="$(get_ctid)"
  if [[ -z "$ctid" ]]; then
    msg_error "Unable to determine CTID"
    exit 1
  fi
  check_container_storage
  check_container_resources
  install_app_in_ct "$ctid"
  msg_ok "Update completed successfully in CT ${ctid}"
  exit
}

start
build_container

CTID_NOW="$(get_ctid)"
if [[ -z "$CTID_NOW" ]]; then
  msg_error "Unable to determine CTID after build_container"
  exit 1
fi

install_app_in_ct "$CTID_NOW"

description
msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized in CT ${CTID_NOW}!${CL}"
echo -e "${INFO}${YW} Config: /etc/adqh/adqh.env${CL}"
echo -e "${INFO}${YW} Data: /var/lib/adqh${CL}"
echo -e "${INFO}${YW} Run once in CT: pct exec ${CTID_NOW} -- bash -lc '/opt/adqh/.venv/bin/python -m adqh.cli run-once --dry-run'${CL}"
