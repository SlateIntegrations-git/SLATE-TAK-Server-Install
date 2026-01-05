#!/bin/bash

# TAK Server Universal Installer (Rocky & Ubuntu)
# Ensure your .rpm or .deb files are in the same directory as this script.

echo "Which OS are you installing TAK Server on?"
echo "1) Rocky Linux"
echo "2) Ubuntu"
read -p "Selection [1-2]: " choice

case $choice in
    1)
        echo "Starting TAK Server Installation for Rocky Linux..."
        # Set system limits [cite: 1, 2]
        echo -e "* soft      nofile      32768\n* hard      nofile      32768\n" | sudo tee --append /etc/security/limits.conf
        
        # Configure Repositories and Dependencies
        sudo dnf config-manager --set-enabled crb
        sudo dnf install epel-release -y
        sudo rpm --import https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL
        sudo dnf install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
        sudo dnf -qy module disable postgresql
        
        # Updates and Java
        sudo dnf update -y
        sudo dnf install java-17-openjdk-devel -y
        
        # TAK Server Installation
        sudo rpm --import takserver-public-gpg.key
        sudo dnf -y install takserver-5.6-RELEASE6.noarch.rpm
        
        # SELinux Configuration [cite: 3]
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
        # Set system limits [cite: 4, 5]
        echo -e "* soft      nofile      32768\n* hard      nofile      32768\n" | sudo tee --append /etc/security/limits.conf
        
        # Install basic utilities
        sudo apt install nano -y
        sudo apt update -y
        sudo apt install gnupg -y
        
        # PostgreSQL Repository Setup [cite: 6]
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