#!/bin/bash

SERVER_IP="10.10.12.100"
WAZUH_VER="4.7.5-1"

echo "### Iniciando despliegue automático en $(hostname) ###"

# 1. DETECTAR EL SISTEMA OPERATIVO
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "No se pudo detectar el sistema operativo. Abortando."
    exit 1
fi

# 2. INSTALACIÓN DE REPOSITORIOS Y ZABBIX AGENT SEGÚN LA DISTRIBUCIÓN
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt-get update
    sudo apt-get install -y curl wget

    # Modificación para asegurar compatibilidad con Ubuntu 24.04 (noble) y 22.04 (jammy)
    if [ "$OS" = "ubuntu" ] && [ "$VER" = "24.04" ]; then
        wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
    elif [ "$OS" = "ubuntu" ]; then
        wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bubuntu${VER}_all.deb -O /tmp/zabbix-release.deb
    else
        wget https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bdebian${VER}_all.deb -O /tmp/zabbix-release.deb
    fi
    
    sudo dpkg -i /tmp/zabbix-release.deb
    sudo apt-get update
    sudo apt-get install -y zabbix-agent

elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
    sudo yum install -y curl wget
    
    # Agregar repositorio oficial de Zabbix para RedHat/CentOS/Alma/Rocky
    sudo rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/${VER%%.*}/x86_64/zabbix-release-6.0-4.el${VER%%.*}.noarch.rpm
    sudo yum clean all
    sudo yum install -y zabbix-agent
else
    echo "Distribución '$OS' no soportada por este script de automatización."
    exit 1
fi # <-- AQUÍ ESTABA EL ERROR, YA QUEDÓ CERRADO EL BLOQUE DE INSTALACIÓN

# 3. DESCARGAR E INSTALAR EL AGENTE DE WAZUH
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    # Usamos la variable WAZUH_VER de forma segura
    URL_WAZUH="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VER}_amd64.deb"
    wget -O /tmp/wazuh-agent.deb "$URL_WAZUH"
    sudo dpkg-deb -x /tmp/wazuh-agent.deb /
    sudo dpkg --force-all -i /tmp/wazuh-agent.deb 2>/dev/null || true
else
    # Instalación en RedHat/CentOS/Otros
    URL_WAZUH="https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VER}.x86_64.rpm"
    sudo rpm -ivh "$URL_WAZUH"
fi

# 4. CONFIGURAR AGENTE DE WAZUH
# Reemplazo universal: busca lo que haya entre <address> y </address> y pon la IP del servidor
sudo sed -i "s|<address>.*</address>|<address>$SERVER_IP</address>|" /var/ossec/etc/ossec.conf

# Registro limpio en Wazuh apuntando a tu servidor usando variables
sudo /var/ossec/bin/agent-auth -m "$SERVER_IP" -A "$(hostname)"

# 5. CONFIGURAR AGENTE DE ZABBIX
sudo sed -i "s/^Server=127.0.0.1/Server=$SERVER_IP/" /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^ServerActive=127.0.0.1/ServerActive=$SERVER_IP/" /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# 6. REGLAS DE FIREWALL Y ARRANQUE DE SERVICIOS
if command -v ufw >/dev/null; then
    sudo ufw allow 10050/tcp
fi

sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent zabbix-agent
sudo systemctl restart wazuh-agent zabbix-agent

echo "### Despliegue finalizado de forma exitosa en $(hostname) ###"
