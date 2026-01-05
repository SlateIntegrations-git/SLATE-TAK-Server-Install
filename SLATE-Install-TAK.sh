#!/bin/bash

# TAK Server Universal Installer (Rocky & Ubuntu)
# This script downloads necessary files from Google Drive and installs TAK Server.

# --- GOOGLE DRIVE CONFIGURATION ---
# Replace these IDs with your actual Google Drive File IDs
ROCKY_RPM_ID="1tKl55SqIi44pEmFtVnphfFIR5gW5F6uB"
UBUNTU_DEB_ID="1HvRZtqlxCt2Eouf-RPcMppd2bXMIvUSZ"

# Function to download large files from Google Drive
gdrive_download() {
    local fileid=$1
    local filename=$2
    echo "Downloading $filename from Google Drive..."
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id='$fileid -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$fileid" -O "$filename" && rm -rf /tmp/cookies.txt
}

echo "Which OS are you installing TAK Server on?"
echo "1) Rocky Linux"
echo "2) Ubuntu"
read -p "Selection [1-2]: " choice

case $choice in
    1)
        echo "Starting TAK Server Installation for Rocky Linux..."
        
        # Download files from Google Drive
        gdrive_download "1tKl55SqIi44pEmFtVnphfFIR5gW5F6uB" "takserver-5.6-RELEASE6.noarch.rpm"

        # [cite_start]Set system limits [cite: 1, 2]
        echo -e "* soft      nofile      32768\n* hard      nofile      32768\n" | sudo tee --append /etc/security/limits.conf
        
        # Configure Repositories and Dependencies
        sudo dnf config-manager --set-enabled crb
        sudo dnf install epel-release -y
        sudo rpm --import https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL
        sudo dnf install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
        sudo dnf -qy module disable postgresql
		sudo dnf install wget -y
        
        # Updates and Java
        sudo dnf update -y
        sudo dnf install java-17-openjdk-devel -y
        
        # TAK Server Installation
        sudo rpm --import takserver-public-gpg.key
        sudo dnf -y install takserver-5.6-RELEASE6.noarch.rpm
        
        # [cite_start]SELinux Configuration [cite: 3]
        sudo dnf -y install checkpolicy
        cd /opt/tak && sudo ./apply-selinux.sh && sudo semodule -l | grep takserver
        
        # SLATE Banner
        echo " "
        echo "  ____  _        _  _____  _____ "
        echo " / ___|| |      / \|_   _|| ____|"
        echo " \___ \| |     / _ \ | |  |  _|  "
        echo "  ___) | |___ / ___ \| |  | |___ "
        echo " |____/|_____/_/   \_\_|  |_____|"
        echo " "
        echo "Rocky Linux Installation Complete."
        ;;

    2)
        echo "Starting TAK Server Installation for Ubuntu..."
        
        # Download file from Google Drive
        gdrive_download "1HvRZtqlxCt2Eouf-RPcMppd2bXMIvUSZ" "takserver_5.6-RELEASE6_all.deb"

        # [cite_start]Set system limits [cite: 4, 5]
        echo -e "* soft      nofile      32768\n* hard      nofile      32768\n" | sudo tee --append /etc/security/limits.conf
        
        # Install basic utilities
        sudo apt install nano -y
        sudo apt update -y
        sudo apt install gnupg -y
        
        # [cite_start]PostgreSQL Repository Setup [cite: 6]
        sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        wget -O- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/postgresql.org.gpg > /dev/null
        
        # Updates and Java
        sudo apt update -y
        sudo apt install openjdk-17-jre -y
        
        # TAK Server Installation
        sudo apt install debsig-verify -y
        sudo apt install ./takserver_5.6-RELEASE6_all.deb -y
        
        # SLATE Banner
        echo " "
        echo "  ____  _        _  _____  _____ "
        echo " / ___|| |      / \|_   _|| ____|"
        echo " \___ \| |     / _ \ | |  |  _|  "
        echo "  ___) | |___ / ___ \| |  | |___ "
        echo " |____/|_____/_/   \_\_|  |_____|"
        echo " "
        echo "Ubuntu Installation Complete."
        ;;

    *)
        echo "Invalid selection. Please run the script again and choose 1 or 2."
        exit 1
        ;;
esac