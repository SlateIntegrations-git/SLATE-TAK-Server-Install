#!/bin/bash

# ==============================================================================
# SLATE TAK Server Universal Installer - PKI & Data Package Edition
# Optimized for Rocky Linux 9 and Ubuntu
# ==============================================================================

# --- GLOBAL VARIABLES ---
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

# --- ROBUST OS DETECTION ---
if [ -f /etc/rocky-release ] || [ -f /etc/redhat-release ]; then
    distro="rocky"
elif [ -f /etc/debian_version ] || grep -q "Ubuntu" /etc/os-release; then
    distro="ubuntu"
else
    distro="rocky" # Fallback
fi

# --- WIZARD FUNCTIONS ---

install_deps() {
    echo -e "${YELLOW}Installing UI, Git, and Packaging components...${NC}"
    if [[ "$distro" == "rocky" ]]; then
        sudo dnf config-manager --set-enabled crb 2>/dev/null || sudo dnf config-manager --set-enabled powertools
        sudo dnf install epel-release -y [cite: 31, 33]
        sudo dnf install dialog zip uuid git git-lfs -y [cite: 80, 432]
    else
        sudo apt update
        sudo apt install dialog zip uuid-runtime git git-lfs -y [cite: 82, 434]
    fi
}

cert_wizard() {
    exec 3>&1
    
    # 1. Password Prompt 
    dialog --backtitle "SLATE TAK Setup" --title "TAK Server PKI Configuration" --defaultno \
        --yesno "By default the certificate password is 'atakatak'.\n\nWould you like to change it?" 7 60 2>&1 1>&3
    
    if [ $? = 0 ]; then
        CAPASSWD=$(dialog --clear --no-cancel --backtitle "SLATE TAK Setup" \
            --title "TAK Server PKI Configuration" \
            --inputbox "Enter new certificate password:" 8 60 2>&1 1>&3)
    else
        CAPASSWD="atakatak" [cite: 138]
    fi

    # 2. Metadata Form [cite: 130]
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
    sudo cp $exampleconfigxml $configxml
    
    # Update Truststore [cite: 151], Password [cite: 137], and Hostname JKS [cite: 155]
    sudo sed -i "s/truststore-root/truststore-$INT_CA_NAME/g" $configxml
    sudo sed -i "s/atakatak/$CAPASSWD/g" $configxml
    sudo sed -i "s/takserver.jks/${HOSTNAME}.jks/g" $configxml

    # Add CRL and QUIC Support [cite: 152, 400]
    sudo sed -i "119i <crl _name=\"TAKServer CA\" crlFile=\"certs/files/${INT_CA_NAME}.crl\"/>" $configxml
    sudo sed -i '7i <input _name="quic" protocol="quic" port="8090" coreVersion="2"/>' $configxml
}

generate_pki() {
    echo -e "${YELLOW}--- Generating Certificates ---${NC}"
    cd /opt/tak/certs || exit
    sudo sed -i "s/COUNTRY=.*/COUNTRY=\"$COUNTRY\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/STATE=.*/STATE=\"$STATE\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/CITY=.*/CITY=\"$CITY\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/ORGANIZATION=.*/ORGANIZATION=\"$ORGANIZATION\"/" cert-metadata.sh [cite: 132]
    sudo sed -i "s/ORGANIZATIONAL_UNIT=.*/ORGANIZATIONAL_UNIT=\"$ORG_UNIT\"/" cert-metadata.sh [cite: 132]
    
    sudo ./makeRootCa.sh --ca-name "$ROOT_CA_NAME" [cite: 143]
    echo y | sudo ./makeCert.sh ca "$INT_CA_NAME" [cite: 149]
    sudo ./makeCert.sh server "$HOSTNAME" [cite: 154]
    
    # User Management Commands [cite: 287]
    sudo java -jar /opt/tak/utils/UserManager.jar adduser admin admin
    sudo java -jar /opt/tak/utils/UserManager.jar usermod -A admin
    
    echo y | sudo ./makeCert.sh client webadmin [cite: 286]
    sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/webadmin.pem [cite: 287]
    echo y | sudo ./makeCert.sh client TAK-Client-01

    cp /opt/tak/certs/files/webadmin.p12 "$homeDir/"
    cp /opt/tak/certs/files/TAK-Client-01.p12 "$homeDir/"
    cp /opt/tak/certs/files/truststore-"$INT_CA_NAME".p12 "$homeDir/caCert.p12"
    sudo chown $curuser:$curuser "$homeDir"/*.p12
}

create_datapackages() {
    echo -e "${YELLOW}Creating SSL and QUIC Enrollment Data Packages...${NC}"
    mkdir -p /tmp/enrollmentDP
    cd /tmp/enrollmentDP || exit
    UUID=$(uuidgen -r) [cite: 265]

    build_pref() {
        local port_string=$1
        tee config.pref >/dev/null <<EOF
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">SLATE TAK ($2)</entry>
    <entry key="connectString0" class="class java.lang.String">$serverIP:$port_string</entry>
    <entry key="caLocation0" class="class java.lang.String">cert/caCert.p12</entry>
    <entry key="caPassword0" class="class java.lang.String">$CAPASSWD</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">true</entry>
  </preference>
</preferences>
EOF
    }

    echo "<MissionPackageManifest version=\"2\"><Configuration><Parameter name=\"uid\" value=\"$UUID\"/><Parameter name=\"name\" value=\"enrollmentDP.zip\"/><Parameter name=\"onReceiveDelete\" value=\"true\"/></Configuration><Contents><Content ignore=\"false\" zipEntry=\"config.pref\"/><Content ignore=\"false\" zipEntry=\"caCert.p12\"/></Contents></MissionPackageManifest>" > MANIFEST.xml
    cp /opt/tak/certs/files/truststore-"$INT_CA_NAME".p12 ./caCert.p12 [cite: 278]

    build_pref "8089:ssl" "SSL"
    zip -j "$homeDir/enrollmentDP-SSL.zip" ./* > /dev/null
    build_pref "8090:quic" "QUIC"
    zip -j "$homeDir/enrollmentDP-QUIC.zip" ./* > /dev/null

    sudo chown $curuser:$curuser "$homeDir"/*.zip
    rm -rf /tmp/enrollmentDP
}

# --- MAIN FLOW ---

install_deps
cert_wizard

# Git LFS Binary Retrieval
git lfs install
git lfs pull

# OS Specific Installation [cite: 59, 61, 68]
if [[ "$distro" == "rocky" ]]; then
    sudo dnf install java-17-openjdk-devel -y [cite: 59]
    sudo rpm --import takserver-public-gpg.key [cite: 12]
    sudo dnf -y install ./takserver-5.6-RELEASE6.noarch.rpm [cite: 66]
else
    sudo apt update && sudo apt install openjdk-17-jre debsig-verify gnupg2 curl -y [cite: 18, 55, 61]
    sudo apt-get install "$BASEDIR/takserver_5.6-RELEASE6_all.deb" -y [cite: 68]
fi

# Apply Config & Start 
if [ -f "$exampleconfigxml" ]; then
    apply_coreconfig
    sudo systemctl enable takserver && sudo systemctl start takserver
    ( tail -f -n0 /opt/tak/logs/takserver-messaging.log & ) | grep -q "Started TAK Server messaging Microservice" 
    sleep 5
    generate_pki
    create_datapackages
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
echo -e "Data Packages: ${YELLOW}$homeDir/enrollmentDP-SSL.zip & QUIC.zip${NC}"