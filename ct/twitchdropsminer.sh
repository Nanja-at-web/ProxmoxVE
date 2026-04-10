#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Nanja-at-web/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2026 Nanja-at-web
# License: MIT
# Source: https://github.com/Nanja-at-web/TwitchDropsMiner

APP="TwitchDropsMiner"
var_tags="${var_tags:-twitchdropsminer}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
var_hostname="${var_hostname:-TwitchDropsMiner}"
var_nesting="${var_nesting:-1}"
var_keyctl="${var_keyctl:-1}"

header_info "$APP"
variables
color
catch_errors

# Keep the full build.func flow, but pull the app install script from this fork.
__tdm_build_container_def="$(declare -f build_container)"
__tdm_build_container_def="${__tdm_build_container_def//https:\/\/raw.githubusercontent.com\/community-scripts\/ProxmoxVE\/main\/install\/\$\{var_install\}.sh/https:\/\/raw.githubusercontent.com\/Nanja-at-web\/ProxmoxVE\/main\/install\/\$\{var_install\}.sh}"
eval "$__tdm_build_container_def"
unset __tdm_build_container_def

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Updating base system"
  $STD apt update
  $STD apt upgrade -y
  msg_ok "Base system updated"

  msg_info "Updating Docker Engine"
  $STD apt install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
  msg_ok "Docker Engine updated"

  msg_info "Updating ${APP}"
  cd /opt/twitchdropsminer || exit 1
  $STD git pull
  $STD docker compose up -d --build
  msg_ok "${APP} updated"

  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access the Web UI at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
