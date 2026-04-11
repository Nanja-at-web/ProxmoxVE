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

fix_apt_sources() {
  msg_info "Fixing APT sources"

  find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.sources' | while read -r file; do
    if grep -q 'enterprise\.proxmox\.com' "$file" 2>/dev/null; then
      rm -f "$file"
    fi
  done

  find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list' | while read -r file; do
    sed -i '/enterprise\.proxmox\.com/d' "$file" || true
    if [[ ! -s "$file" ]]; then
      rm -f "$file"
    fi
  done

  if [[ -f /etc/apt/sources.list.d/proxmox.sources ]] && [[ -f /etc/apt/sources.list.d/pve-no-subscription.list ]]; then
    rm -f /etc/apt/sources.list.d/pve-no-subscription.list
  fi

  msg_ok "APT sources fixed"
}

setup_python_env() {
  msg_info "Setting up Python virtual environment"
  python3 -m venv /opt/adqh/.venv
  /opt/adqh/.venv/bin/pip install --upgrade pip setuptools wheel
  /opt/adqh/.venv/bin/pip install /opt/adqh
  msg_ok "Set up Python environment"
}

install_units() {
  msg_info "Installing systemd units"
  install -D -m 0644 /opt/adqh/deploy/adqh.service /etc/systemd/system/adqh.service
  install -D -m 0644 /opt/adqh/deploy/adqh.timer /etc/systemd/system/adqh.timer
  systemctl daemon-reload
  systemctl enable --now adqh.timer
  msg_ok "Installed systemd units"
}

update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/adqh/.git ]]; then
    msg_error "No ${APP} git installation found!"
    exit 1
  fi

  msg_info "Stopping ${APP}"
  systemctl stop adqh.service 2>/dev/null || true
  systemctl stop adqh.timer 2>/dev/null || true
  msg_ok "Stopped ${APP}"

  msg_info "Updating source"
  cd /opt/adqh || exit 1
  git fetch --all
  git reset --hard "origin/${ADQH_BRANCH}"
  msg_ok "Updated source"

  setup_python_env

  install -d -m 0755 /etc/adqh /var/lib/adqh
  if [[ -f /opt/adqh/deploy/adqh.env.example ]] && [[ ! -f /etc/adqh/adqh.env ]]; then
    install -m 0640 /opt/adqh/deploy/adqh.env.example /etc/adqh/adqh.env
  fi

  install_units
  msg_ok "Update completed successfully"
  exit
}

start
build_container

msg_info "Installing dependencies"
fix_apt_sources
$STD apt-get update
$STD apt-get install -y curl git ca-certificates python3 python3-venv python3-pip
msg_ok "Installed dependencies"

msg_info "Cloning ADQH repository"
rm -rf /opt/adqh

git clone --branch "$ADQH_BRANCH" "$ADQH_REPO_URL" /opt/adqh
msg_ok "Cloned ADQH repository"

setup_python_env

msg_info "Preparing directories"
install -d -m 0755 /etc/adqh /var/lib/adqh
if [[ -f /opt/adqh/deploy/adqh.env.example ]] && [[ ! -f /etc/adqh/adqh.env ]]; then
  install -m 0640 /opt/adqh/deploy/adqh.env.example /etc/adqh/adqh.env
fi
msg_ok "Prepared directories"

install_units

msg_ok "Completed successfully!"
echo -e "${INFO}${YW}ADQH Repo: ${ADQH_REPO_URL}${CL}"
echo -e "${INFO}${YW}Config: /etc/adqh/adqh.env${CL}"
echo -e "${INFO}${YW}Data: /var/lib/adqh${CL}"
echo -e "${INFO}${YW}Timer: systemctl status adqh.timer${CL}"
echo -e "${INFO}${YW}Run once: /opt/adqh/.venv/bin/python -m adqh.cli run-once --dry-run${CL}"
