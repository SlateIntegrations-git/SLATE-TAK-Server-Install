SLATE TAK Server Universal Installer
This repository contains a unified bash script for installing TAK Server 5.6 on Rocky Linux 9 and Ubuntu. It leverages Git LFS to manage the large installation binaries and includes automated repository configuration and security setup.

📋 Prerequisites
Git LFS: This repository uses Git Large File Storage. Ensure you have git-lfs installed on your local machine before cloning.

Credentials: You will need a GitHub Personal Access Token (PAT) with repo scopes to clone this repository to your server.

Architecture: Designed for Rocky Linux 9 (x86_64) and Ubuntu (latest LTS).

🚀 Quick Start
1. Clone the Repository
On your target server, install Git and Git LFS, then clone the repository:

# For Rocky Linux
sudo dnf install git git-lfs -y

# For Ubuntu
sudo apt update && sudo apt install git git-lfs -y

# Clone (Use your PAT as the password)
git clone https://github.com/SlateIntegrations-git/SLATE-TAK-Server-Install.git
cd SLATE-TAK-Server-Install

2. Run the Installer
The script must be executed with root privileges to configure system limits and install dependencies:


chmod +x SLATE-Install-TAK.sh
sudo ./SLATE-Install-TAK.sh


🛠️ What the Script Does
Dependency Management: Automatically installs wget, java-17-openjdk, and gnupg.

Database Setup: Configures the official PostgreSQL repositories and prepares the system for the TAK database.

System Optimization: Increases system nofile limits to 32768 to handle high-volume TAK traffic.

Security:

      Rocky Linux: Automatically installs checkpolicy and applies required SELinux modules for TAK Server.

      Ubuntu: Sets up debsig-verify for package integrity.

LFS Handling: Includes a prepare_lfs function to ensure large binaries are fully pulled from GitHub rather than remaining as small pointer files.


📂 Repository Structure


SLATE-Install-TAK.sh: The universal installation script.

takserver-5.6-RELEASE6.noarch.rpm: Rocky Linux installation package (Managed via LFS).

takserver_5.6-RELEASE6_all.deb: Ubuntu installation package (Managed via LFS).

takserver-public-gpg.key: Public GPG key for package verification.




⚠️ Troubleshooting


Authentication Failed: Ensure you are using a Personal Access Token instead of your GitHub password.

File Too Small Error: If the installation fails with a size error, run git lfs pull manually to ensure the binaries were downloaded completely.

Permission Denied: Ensure you run the script with sudo and have executed chmod +x on the .sh file.
