# 📜 Linux System Administrator Automation Script

## 🎯 Project Goal

This project implements a comprehensive Bash shell script designed to automate essential Linux system administration tasks, focusing on user/group management and data backup operations. It was developed to reinforce security, ensure operational efficiency, and streamline repetitive administrative duties.

## ✨ Features

The `user_backup_manager.sh` script provides a user-friendly, interactive command-line menu with the following capabilities:

### 👤 User & Group Management
* **Create Users:** Add new users with immediate password setting and home directory creation.
* **Modify Users:** Lock, unlock, or change the default shell for existing accounts.
* **Delete Users:** Permanently remove user accounts along with their home directories, with critical user protection checks.
* **Group Management:** Create, delete, and add users to supplementary groups.

### 💾 System Backup
* **Automated Backup:** Creates a compressed `tar.gz` archive of specified critical directories (`/etc` and `/home`).
* **Secure Storage:** Backups are timestamped for uniqueness and stored securely in the root-owned directory `/opt/backups`.

## ⚙️ Requirements

* **Operating System:** Any modern Linux distribution (e.g., Ubuntu, Fedora, Debian).
* **Shell:** Bash (standard).
* **Permissions:** Root/`sudo` access is required to run the script.

## 🚀 Installation and Usage

To get started, clone the repository and execute the script:

### 1. Clone the Repository
```bash
git clone [https://github.com/nearito88/Linux-user-manager-script.git](https://github.com/nearito88/Linux-user-manager-script.git)
cd Linux-user-manager-script
