#!/bin/bash

# ==============================================================================
# SLATE TAK Server Universal Installer - COMPLETE PRODUCTION EDITION
# ==============================================================================

# --- GLOBAL VARIABLES & DETECTION ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
curuser=$(printenv SUDO_USER)
homeDir=$(getent passwd "$curuser" | cut -d: -f6)
serverIP=$(hostname -I | awk '{print $1}')
BASEDIR=$(pwd)
exampleconfigxml="/opt/tak/CoreConfig.example.xml"
configxml="/opt/tak/CoreConfig.xml"

# --- SYSTEM PRE-CHECKS --- [cite: 6, 7]
memTotal=$(awk -F': ' '/^MemTotal/ {print $2}' /proc/meminfo | tr -d ' kB')
if [[ $memTotal -lt 7500000 ]]; then
    echo -e "${RED}ERR: TAK Server requires at least 8GB of RAM.${NC}"
    exit 1
fi

# --- ROBUST OS DETECTION ---
if [ -f /etc/rocky-release ] || [ -f /etc/redhat-release ]; then
    distro="rocky"
else
    distro="ubuntu"
fi

# --- WIZARD FUNCTIONS ---
install_deps() {
    echo -e "${YELLOW}Installing UI, Git, and Packaging components...${NC}"
    if [[ "$distro" == "rocky" ]]; then
        sudo dnf config-manager --set-enabled crb 2>/dev/null || sudo dnf config-manager --set-enabled powertools [cite: 31, 33]
        sudo dnf install epel-release -y [cite: 31, 33]
        sudo dnf install dialog zip uuid git git-lfs checkpolicy -y 2>/dev/null [cite: 75, 80]
    else
        sudo apt update
        sudo apt install dialog zip uuid-runtime git git-lfs -y 2>/dev/null [cite: 82]
    fi
}

cert_wizard() {
    exec 3>&1
    # Password Prompt [cite: 134]
    dialog --backtitle "SLATE TAK Setup" --title "TAK Server PKI Configuration" --defaultno \
        --yesno "By default the certificate password is 'atakatak'.\n\nWould you like to change it?" 7 60 2>&1 1>&3
    
    if [ $? = 0 ]; then
        CAPASSWD=$(dialog --clear --no-cancel --backtitle "SLATE TAK Setup" \
            --title "TAK Server PKI Configuration" \
            --inputbox "Enter new certificate password:" 8 60 2>&1 1>&3) [cite: 134]
    else
        CAPASSWD="atakatak"
    fi

    # Metadata Form [cite: 130]
    VALUES=$(dialog --backtitle "SLATE TAK Setup" --title "Certificate Configuration" \
        --form "Enter the metadata for your TAK PKI infrastructure:" 15 60 0 \
        "Country (2 letters):" 1 1 "US" 1 25 30 0 \
        "State:"               2 1 "NC" 2 25 30 0 \
        "City:"                3 1 "VASS" 3 25 30 0 \
        "Organization:"        4 1 "SLATE" 4 25 30 0 \
        "Org Unit:"           5 1 "TAK" 5 25 30 0 \
        "Root CA Name:"        6 1 "SLATE-ROOT-CA" 6 25 30 0 \
        "Intermediate CA Name:" 7 1 "SLATE-INT-CA" 7 25 30 0 \
        2>&1 1>&3)
    exec 3>&-
    clear

    COUNTRY=$(echo "$VALUES" | sed -n '1p')
    STATE=$(echo "$VALUES" | sed -n '2p')
    CITY=$(echo "$VALUES" | sed -n '3p')
    ORGANIZATION=$(echo "$VALUES" | sed -n '4p')
    ORG_UNIT=$(echo "$VALUES" | sed -n '5p')
    ROOT_CA_NAME=$(echo "$VALUES" | sed -n '6p')
    INT_CA_NAME=$(echo "$VALUES" | sed -n '7p')
}

apply_coreconfig() {
    echo -e "${YELLOW}Applying CoreConfiguration based on $INT_CA_NAME...${NC}"
    sudo cp $exampleconfigxml $configxml [cite: 84]
    
    sudo sed -i "s/truststore-root/truststore-$INT_CA_NAME/g" $configxml [cite: 151, 152]
    sudo sed -i "s/atakatak/$CAPASSWD/g" $configxml [cite: 137]
    sudo sed -i "s/takserver.jks/${HOSTNAME}.jks/g" $configxml [cite: 155]

    sudo sed -i "119i <crl _name=\"TAKServer CA\" crlFile=\"certs/files/${INT_CA_NAME}.crl\"/>" $configxml [cite: 152]
    sudo sed -i '7i <input _name="quic" protocol="quic" port="8090" coreVersion="2"/>' $configxml [cite: 243]
}

generate_pki() {
    echo -e "${YELLOW}--- Generating Certificates ---${NC}"
    cd /opt/tak/certs || exit
    sudo sed -i "s/COUNTRY=.*/COUNTRY=\"$COUNTRY\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/STATE=.*/STATE=\"$STATE\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/CITY=.*/CITY=\"$CITY\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/ORGANIZATION=.*/ORGANIZATION=\"$ORGANIZATION\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/ORGANIZATIONAL_UNIT=.*/ORGANIZATIONAL_UNIT=\"$ORG_UNIT\"/" cert-metadata.sh [cite: 132]
    
    sudo ./makeRootCa.sh --ca-name "$ROOT_CA_NAME" [cite: 146]
    echo y | sudo ./makeCert.sh ca "$INT_CA_NAME" [cite: 150]
    sudo ./makeCert.sh server "$HOSTNAME" [cite: 154]
    
    # User Management [cite: 287]
    sudo java -jar /opt/tak/utils/UserManager.jar adduser admin admin
    sudo java -jar /opt/tak/utils/UserManager.jar usermod -A admin
    
    echo y | sudo ./makeCert.sh client webadmin [cite: 286]
    sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/webadmin.pem [cite: 287]
    echo y | sudo ./makeCert.sh client TAK-Client-01

    cp /opt/tak/certs/files/webadmin.p12 "$homeDir/" [cite: 288]
    cp /opt/tak/certs/files/TAK-Client-01.p12 "$homeDir/"
    cp /opt/tak/certs/files/truststore-"$INT_CA_NAME".p12 "$homeDir/caCert.p12" [cite: 278]
    sudo chown $curuser:$curuser "$homeDir"/*.p12 [cite: 278]
}

# --- MAIN FLOW ---
install_deps
cert_wizard

# System Limits [cite: 29]
echo -e "* soft nofile 32768\n* hard nofile 32768" | sudo tee --append /etc/security/limits.conf > /dev/null

# LFS Pull
git lfs install && git lfs pull

if [[ "$distro" == "rocky" ]]; then
    sudo dnf install java-17-openjdk-devel -y [cite: 59]
    sudo rpm --import takserver-public-gpg.key [cite: 12]
    sudo dnf -y install ./takserver-5.6-RELEASE6.noarch.rpm [cite: 66]
    cd /opt/tak && sudo ./apply-selinux.sh [cite: 78]
else
    sudo apt update && sudo apt install openjdk-17-jre debsig-verify gnupg2 curl -y [cite: 18, 55, 61]
    sudo apt-get install "$BASEDIR/takserver_5.6-RELEASE6_all.deb" -y [cite: 68]
fi

# Configure & Start
if [ -f "$exampleconfigxml" ]; then
    apply_coreconfig
    echo -e "${YELLOW}Starting TAK Server...${NC}"
    sudo systemctl enable takserver && sudo systemctl start takserver
    ( tail -f -n0 /opt/tak/logs/takserver-messaging.log & ) | grep -q "Started TAK Server messaging Microservice" [cite: 323]
    sleep 5
    generate_pki
fi

# --- THE SLATE BANNER ---
echo -e "${GREEN}
  ____  _        _  _____  _____ 
 / ___|| |      / \|_   _|| ____|
 \___ \| |     / _ \ | |  |  _|  
  ___) | |___ / ___ \| |  | |___ 
 |____/|_____/_/   \_\_|  |_____|
${NC}"
echo -e "Success! Access Dashboard: ${YELLOW}https://$serverIP:8443${NC}"
echo -e "User: ${YELLOW}admin / admin${NC}"