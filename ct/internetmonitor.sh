#!/usr/bin/env bash
# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

GITHUB_REPO="tteck/Proxmox"
GIT_BRANCH="main"

GITHUB_REPO="MichaelBMF/Proxmox"
GIT_BRANCH="internet-monitor/"
#bash -c "$(curl -fsSL "https://github.com/MichaelBMF/Proxmox/raw/internet-monitor/ct/internetmonitor.sh")"
source <(curl -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/${GIT_BRANCH}/misc/build.func")

function header_info {
clear
cat <<"EOF"
    ____      __                       __  __  ___            _ __            
   /  _/___  / /____  _________  ___  / /_/  |/  /___  ____  (_) /_____  _____
   / // __ \/ __/ _ \/ ___/ __ \/ _ \/ __/ /|_/ / __ \/ __ \/ / __/ __ \/ ___/
 _/ // / / / /_/  __/ /  / / / /  __/ /_/ /  / / /_/ / / / / / /_/ /_/ / /    
/___/_/ /_/\__/\___/_/  /_/ /_/\___/\__/_/  /_/\____/_/ /_/_/\__/\____/_/     
                                                                              
EOF
}

header_info
echo -e "Loading..."
APP="InternetMonitor"
var_disk="2"
var_cpu="1"
var_ram="512"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="YES"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /opt/internetmonitor ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Stopping ${APP}"
systemctl disable speedtest-exporter.service &>/dev/null
systemctl stop speedtest-exporter
sleep 1
msg_ok "Stopped ${APP}"

msg_info "Backing up Data"
# if [ -d "/opt/internetmonitor-3.5.4" ]; then
#   cp -R /opt/internetmonitor-3.5.4/data data-backup
# else
#   cp -R /opt/internetmonitor/data data-backup
# fi
sleep 1
msg_ok "Backed up Data"

msg_info "Updating OOKLA Speedtest CLI"
set +e
trap - ERR
## If migrating from prior bintray install instructions please first...
rm /etc/apt/sources.list.d/speedtest.list
apt-get update
apt-get -y remove speedtest
curl -fsSL "https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh" | bash
apt-get -y install speedtest
msg_ok "Updated OOKLA Speedtest CLI"

RELEASE=$(curl -sX GET "https://api.github.com/repos/MiguelNdeCarvalho/speedtest-exporter/releases" | awk '/tag_name/{print $4;exit}' FS='[""]')
msg_info "Updating Speedtest Exporter to ${RELEASE}"

curl --silent -o ${RELEASE}.tar.gz -L "https://github.com/MiguelNdeCarvalho/speedtest-exporter/archive/${RELEASE}.tar.gz" &>/dev/null
tar xvzf ${RELEASE}.tar.gz &>/dev/null
VER=$(curl -s https://api.github.com/repos/MiguelNdeCarvalho/speedtest-exporter/releases/latest |
  grep "tag_name" |
  awk '{print substr($2, 3, length($2)-4) }')

if [ ! -d "/opt/internetmonitor" ]; then
  mkdir -p /opt/internetmonitor/speedtest-exporter  
  mv speedtest-exporter-${VER}/src/* /opt/internetmonitor/speedtest-exporter
else
  cp -R speedtest-exporter-${VER}/src* /opt/internetmonitor/speedtest-exporter
fi
cd /opt/internetmonitor/speedtest-exporter
python3 -m venv venv
yes | venv/bin/pip install -r requirements.txt  -q -q -q --exists-action i
cd /
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
msg_ok "Updated Speedtest Exporter ${RELEASE}"

msg_info "Restoring Data"
# cp -R data-backup/* /opt/internetmonitor/data 
# sleep 1
msg_ok "Restored Data"

msg_info "Cleanup"
rm -rf ${RELEASE}.tar.gz
rm -rf speedtest-exporter-${VER}
#rm -rf data-backup
sleep 1
msg_ok "Cleaned"

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

msg_info "Starting ${APP}"
systemctl enable --now speedtest-exporter.service &>/dev/null
sleep 2
msg_ok "Started ${APP}"
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:9798${CL} \n"
