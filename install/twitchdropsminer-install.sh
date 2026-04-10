#!/usr/bin/env bash

# Copyright (c) 2026 Nanja-at-web
# License: MIT
# Source: https://github.com/Nanja-at-web/TwitchDropsMiner

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APP_REPO_URL="https://github.com/Nanja-at-web/TwitchDropsMiner.git"
APP_REPO_REF="main"
APP_DIR="/opt/twitchdropsminer"

msg_info "Installing required packages"
$STD apt-get install -y git ca-certificates curl gnupg jq
msg_ok "Installed required packages"

if ! command -v docker >/dev/null 2>&1; then
  msg_info "Installing Docker Engine"
  DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
  mkdir -p "$(dirname "$DOCKER_CONFIG_PATH")"
  echo -e '{\n  "log-driver": "journald"\n}' > /etc/docker/daemon.json
  $STD sh <(curl -fsSL https://get.docker.com)
  msg_ok "Installed Docker Engine"
else
  msg_ok "Docker already installed"
fi

msg_info "Preparing application directory"
mkdir -p /opt
rm -rf "$APP_DIR"
$STD git clone "$APP_REPO_URL" "$APP_DIR"
cd "$APP_DIR"
$STD git fetch --all --tags
$STD git checkout "$APP_REPO_REF"
mkdir -p "$APP_DIR/data" "$APP_DIR/logs"
msg_ok "Repository prepared"

if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
  msg_error "docker-compose.yml not found in $APP_DIR"
  exit 1
fi

msg_info "Building and starting TwitchDropsMiner"
$STD docker compose -f "$APP_DIR/docker-compose.yml" up -d --build
msg_ok "TwitchDropsMiner started"

msg_info "Installing helper aliases"
cat <<'EOF_ALIAS' >/etc/profile.d/twitchdropsminer.sh
alias tdm-logs='cd /opt/twitchdropsminer && docker compose logs -f'
alias tdm-update='cd /opt/twitchdropsminer && git pull && docker compose up -d --build'
alias tdm-restart='cd /opt/twitchdropsminer && docker compose restart'
EOF_ALIAS
chmod 644 /etc/profile.d/twitchdropsminer.sh
msg_ok "Helper aliases installed"

motd_ssh
customize
cleanup_lxc
