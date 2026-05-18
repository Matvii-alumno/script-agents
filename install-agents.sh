#!/bin/bash

SERVER_IP="10.10.12.100"
WAZUH_VER="4.7.5-1"
URL_WAZUH="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VER}_amd64.deb"

echo "### Iniciando despliegue automático en $(hostname) ###"

sudo apt-get update
sudo apt-get install -y curl wget zabbix-agent

wget -O /tmp/wazuh-agent.deb "$URL_WAZUH"

sudo dpkg-deb -x /tmp/wazuh-agent.deb /

sudo dpkg --force-all -i /tmp/wazuh-agent.deb 2>/dev/null || true

sudo sed -i "s/<address>MANAGER_IP<\/address>/<address>$SERVER_IP<\/address>/" /var/ossec/etc/ossec.conf

sudo /var/ossec/bin/agent-auth -m "10.10.12.100" -m "$(hostname)"

sudo sed -i "s/^Server=127.0.0.1/Server=$SERVER_IP/" /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^ServerActive=127.0.0.1/ServerActive=$SERVER_IP/" /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

sudo ufw allow 10050/tcp
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent zabbix-agent
sudo systemctl restart wazuh-agent zabbix-agent

echo "### Despliegue finalizado. Revisa el Dashboard de Wazuh y Zabbix ###"
