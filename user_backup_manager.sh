#!/bin/bash

# =========================================================================
# GLOBAL VARIABLES
# =========================================================================

# The user management part requires root privileges (UID 0)
BACKUP_DEST="/opt/backups"


# =========================================================================
# 1. ROOT CHECK AND INITIAL SETUP
# =========================================================================

# Check for root privileges
if [ "$UID" -ne 0 ]; then
    echo "🚨 ERROR: This script must be run as root or with sudo."
    echo "Usage: sudo ./user_backup_manager.sh"
    exit 1
fi

echo "Root check successful. Starting User/Backup Manager..."


# =========================================================================
# 2. CORE FUNCTIONS: USER MANAGEMENT
# =========================================================================

# Function to list users (excluding system accounts)
list_users() {
    echo "--- Active User Accounts ---"
    # Filter users with UID >= 1000 (standard user accounts)
    cat /etc/passwd | awk -F: '$3 >= 1000 {printf "  %s\n", $1}'
    echo "----------------------------"
    echo "Press Enter to continue..."
    read -r
}

# Function to create a new user account
create_user() {
    echo "--- Create New User Account ---"
    
    # 1. Prompt for username
    read -p "Enter username for new account: " USERNAME

    # 2. Input Validation (check if input is empty)
    if [ -z "$USERNAME" ]; then
        echo "❌ Error: Username cannot be empty."
        read -r
        return
    fi

    # 3. Check if user already exists (using getent for quiet reliability)
    if getent passwd "$USERNAME" > /dev/null; then
        echo "❌ Error: User '$USERNAME' already exists. Aborting."
        read -r
        return
    fi

    # 4. Create the user and set password (with verbose error capture)
    echo "Attempting to create user '$USERNAME'..."
    
    # useradd command: -m (create home), -s /bin/bash (set shell)
    # We redirect standard output (1>) to /dev/null, but allow standard error (2>&1) 
    # to print if something goes wrong.
    useradd -m -s /bin/bash "$USERNAME" 1>/dev/null 2>&1 
    
    LAST_EXIT_CODE=$?

    # Check the exit status of useradd command
    if [ $LAST_EXIT_CODE -eq 0 ]; then
        echo "✅ User '$USERNAME' created successfully."
        # Force set password immediately
        passwd "$USERNAME"
        echo "Password for '$USERNAME' set."
    else
        echo "❌ FATAL ERROR ($LAST_EXIT_CODE): Failed to create user '$USERNAME'."
        echo "Check if necessary packages (like 'passwd') are installed or for disk errors."
    fi
    echo "Press Enter to continue..."
    read -r
}

# Function to delete an existing user account
delete_user() {
    echo "--- Delete User Account ---"
    
    # 1. Prompt for username to delete
    read -p "Enter username to delete: " USERNAME

    # 2. Input Validation (check if input is empty)
    if [ -z "$USERNAME" ]; then
        echo "❌ Error: Username cannot be empty."
        read -r
        return
    fi

    # 3. Prevent deletion of critical users (e.g., 'root' or the current WSL user)
    # $(whoami) gets the effective username running the script (root, because of sudo)
    if [ "$USERNAME" == "root" ] || [ "$USERNAME" == "$(logname)" ]; then 
        echo "❌ Error: Cannot delete critical system user or your own login user."
        read -r
        return
    fi
    
    # 4. Check if user exists (using getent for quiet reliability)
    if ! getent passwd "$USERNAME" > /dev/null; then
        echo "❌ Error: User '$USERNAME' does not exist. Aborting."
        read -r
        return
    fi

    # 5. Confirmation and Deletion
    read -r -p "⚠️ WARNING: Permanently delete user '$USERNAME' AND their home directory? (y/N) " CONFIRM
    
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        # userdel -r: Deletes the user AND removes their home directory
        userdel -r "$USERNAME"
        
        if [ $? -eq 0 ]; then
            echo "✅ User '$USERNAME' and their home directory deleted successfully."
        else
            echo "❌ Error: Failed to delete user '$USERNAME'. Check system logs."
        fi
    else
        echo "Action cancelled."
    fi
    echo "Press Enter to continue..."
    read -r
}


# =========================================================================
# 3. CORE FUNCTIONS: BACKUP
# =========================================================================

# Function to run a full system backup
system_backup() {
    echo "--- Initiating System Backup ---"
    
    # 1. Ensure the destination directory exists
    if [ ! -d "$BACKUP_DEST" ]; then
        echo "Creating backup destination directory: $BACKUP_DEST"
        mkdir -p "$BACKUP_DEST"
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to create backup directory."
            read -r
            return
        fi
    fi

    # 2. Define the backup filename using a timestamp for uniqueness
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DEST/system_backup_$TIMESTAMP.tar.gz"
    
    # 3. Define directories to include in the backup
    BACKUP_DIRS="/etc /home"
    
    echo "Archiving directories: $BACKUP_DIRS"
    echo "Destination: $BACKUP_FILE"
    
    # 4. Create the compressed tar archive (c: create, z: gzip, v: verbose, f: file)
    tar -czvf "$BACKUP_FILE" $BACKUP_DIRS
    
    # 5. Check the exit status of the tar command
    if [ $? -eq 0 ]; then
        echo "✅ Backup successfully created and saved to $BACKUP_FILE"
        echo "Archive size: $(du -sh "$BACKUP_FILE" | awk '{print $1}')"
    else
        echo "❌ Backup failed. Check permissions or disk space."
    fi
    
    echo "Press Enter to continue..."
    read -r
}


# =========================================================================
# 4. MENU STRUCTURES
# =========================================================================

# Sub-Menu Display for User Management
user_management_menu() {
    while true; do
        clear
        echo "========================================="
        echo "👤 USER MANAGEMENT"
        echo "========================================="
        echo "1) Create a New User"
        echo "2) Delete an Existing User"
        echo "3) List All Users"
        echo "4) ↩️ Back to Main Menu"
        echo "-----------------------------------------"
        echo -n "Enter your choice [1-4]: "
        read user_choice

        case "$user_choice" in
            1)
                create_user
                ;;
            2)
                delete_user
                ;;
            3)
                list_users
                ;;
            4)
                return # Exits this function, returning to the main menu
                ;;
            *)
                echo "⚠️ Invalid choice. Please select 1, 2, 3, or 4."
                sleep 2
                ;;
        esac
    done
}

# Main Menu Display
show_menu() {
    clear
    echo "========================================="
    echo "📜 Shell Script User/Backup Manager"
    echo "========================================="
    echo "1) 👤 User Management"
    echo "2) 💾 System Backup"
    echo "3) 🚪 Exit Script"
    echo "-----------------------------------------"
    echo -n "Enter your choice [1-3]: "
}

# =========================================================================
# 5. MAIN LOGIC LOOP
# =========================================================================

while true; do
    show_menu
    read choice

    case "$choice" in
        1)
            user_management_menu
            ;;
        2)
            system_backup
            ;;
        3)
            echo "Exiting Script. Goodbye!"
            exit 0
            ;;
        *)
            echo "⚠️ Invalid choice. Please select 1, 2, or 3."
            sleep 2
            ;;
    esac
done
