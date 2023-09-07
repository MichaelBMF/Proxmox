#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y htop
msg_ok "Installed Dependencies"

msg_info "Updating Python3"
$STD apt-get install -y \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv
msg_ok "Updated Python3"

msg_info "Installing OOKLA Speedtest CLI"
## If migrating from prior bintray install instructions please first...
# sudo rm /etc/apt/sources.list.d/speedtest.list
# sudo apt-get update
# sudo apt-get remove speedtest
set +e
trap - ERR
$STD $(curl -fsSL  "https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh" | bash)
$STD apt-get -y install speedtest
msg_ok "Installed OOKLA Speedtest CLI"

RELEASE=$(curl -sX GET "https://api.github.com/repos/MiguelNdeCarvalho/speedtest-exporter/releases" | awk '/tag_name/{print $4;exit}' FS='[""]')

msg_info "Instaling Speedtest Exporter ${RELEASE}"

$STD curl --silent -o ${RELEASE}.tar.gz -L "https://github.com/MiguelNdeCarvalho/speedtest-exporter/archive/${RELEASE}.tar.gz"
$STD tar xvzf ${RELEASE}.tar.gz
VER=$(curl -s https://api.github.com/repos/MiguelNdeCarvalho/speedtest-exporter/releases/latest |
  grep "tag_name" |
  awk '{print substr($2, 3, length($2)-4) }')
mkdir -p /opt/internetmonitor/speedtest-exporter  
mv speedtest-exporter-${VER}/src/* /opt/internetmonitor/speedtest-exporter
cd /opt/internetmonitor/speedtest-exporter
python3 -m venv venv
yes | venv/bin/pip install -r requirements.txt  -q -q -q --exists-action i
cd /
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
msg_ok "Installed Speedtest Exporter ${RELEASE}"

msg_info "Creating Service"
service_path="/etc/systemd/system/speedtest-exporter.service"
echo "[Unit]
Description=SpeedtestExporter
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
User=root
WorkingDirectory=/opt/internetmonitor/speedtest-exporter
ExecStart=/opt/internetmonitor/speedtest-exporter/venv/bin/python3 /opt/internetmonitor/speedtest-exporter/exporter.py
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target" >$service_path
$STD sudo systemctl enable --now speedtest-exporter.service
msg_ok "Created Service"
##--
motd_ssh
customize

msg_info "Cleaning up"
rm -rf ${RELEASE}.tar.gz
rm -rf speedtest-exporter-${VER}
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
