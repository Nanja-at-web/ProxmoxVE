#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="ADQH"
ADQH_REPO_URL="${ADQH_REPO_URL:-https://github.com/Nanja-at-web/ADQH.git}"
ADQH_BRANCH="${ADQH_BRANCH:-main}"
PAYLOAD_FILE="adqh_source_payload.tar.gz.b64"

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

function install_from_payload() {
  local repo_dir="$1"
  if [[ ! -f "${repo_dir}/${PAYLOAD_FILE}" ]]; then
    msg_error "Payload file ${PAYLOAD_FILE} not found in ${repo_dir}!"
    exit 1
  fi

  msg_info "Extracting ADQH payload"
  mkdir -p /opt/adqh
  base64 -d "${repo_dir}/${PAYLOAD_FILE}" > /tmp/adqh_payload.tar.gz
  tar -xzf /tmp/adqh_payload.tar.gz -C /opt/adqh
  rm -f /tmp/adqh_payload.tar.gz
  msg_ok "Extracted ADQH payload"
}

function setup_python_env() {
  msg_info "Setting up Python virtual environment"
  python3 -m venv /opt/adqh/.venv
  /opt/adqh/.venv/bin/pip install --upgrade pip
  if [[ -f /opt/adqh/requirements.txt ]]; then
    /opt/adqh/.venv/bin/pip install -r /opt/adqh/requirements.txt
  else
    /opt/adqh/.venv/bin/pip install /opt/adqh
  fi
  msg_ok "Set up Python environment"
}

function install_units() {
  msg_info "Installing systemd units"
  install -D -m 0644 /opt/adqh/deploy/adqh.service /etc/systemd/system/adqh.service
  install -D -m 0644 /opt/adqh/deploy/adqh.timer /etc/systemd/system/adqh.timer
  systemctl daemon-reload
  systemctl enable --now adqh.timer
  msg_ok "Installed systemd units"
}

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/adqh ]]; then
    msg_error "No ${APP} installation found!"
    exit 1
  fi

  msg_info "Stopping ${APP}"
  systemctl stop adqh.service 2>/dev/null || true
  systemctl stop adqh.timer 2>/dev/null || true
  msg_ok "Stopped ${APP}"

  msg_info "Refreshing installer payload"
  rm -rf /opt/adqh_repo
  git clone --branch "$ADQH_BRANCH" "$ADQH_REPO_URL" /opt/adqh_repo
  rm -rf /opt/adqh/*
  install_from_payload /opt/adqh_repo
  msg_ok "Refreshed installer payload"

  setup_python_env

  msg_info "Refreshing config"
  install -d -m 0755 /etc/adqh /var/lib/adqh
  if [[ -f /opt/adqh/deploy/adqh.env.example ]] && [[ ! -f /etc/adqh/adqh.env ]]; then
    install -m 0640 /opt/adqh/deploy/adqh.env.example /etc/adqh/adqh.env
  fi
  msg_ok "Config checked"

  install_units

  msg_ok "Update completed successfully"
  exit
}

start
build_container

msg_info "Installing dependencies"
$STD apt-get update
$STD apt-get install -y curl git ca-certificates jq python3 python3-venv python3-pip
msg_ok "Installed dependencies"

msg_info "Cloning ADQH repository"
rm -rf /opt/adqh_repo /opt/adqh
mkdir -p /opt/adqh_repo /opt/adqh
rm -rf /opt/adqh_repo

git clone --branch "$ADQH_BRANCH" "$ADQH_REPO_URL" /opt/adqh_repo
msg_ok "Cloned ADQH repository"

install_from_payload /opt/adqh_repo
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
