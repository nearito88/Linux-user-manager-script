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

# Function to modify an existing user's attributes
modify_user() {
    echo "--- Modify User Account ---"
    read -p "Enter username to modify: " USERNAME

    # Input Validation and Existence Check
    if ! getent passwd "$USERNAME" > /dev/null; then
        echo "❌ Error: User '$USERNAME' does not exist."
        read -r
        return
    fi

    while true; do
        clear
        echo "========================================="
        echo "⚙️ MODIFY USER: $USERNAME"
        echo "========================================="
        echo "1) Change User Shell (e.g., /bin/bash)"
        echo "2) Lock Account (Disable Login)"
        echo "3) Unlock Account (Enable Login)"
        echo "4) ↩️ Back to User Management"
        echo "-----------------------------------------"
        echo -n "Enter your choice [1-4]: "
        read mod_choice

        case "$mod_choice" in
            1)
                read -p "Enter new shell path (e.g., /bin/sh or /bin/bash): " NEW_SHELL
                usermod -s "$NEW_SHELL" "$USERNAME"
                if [ $? -eq 0 ]; then
                    echo "✅ Shell for $USERNAME changed to $NEW_SHELL."
                else
                    echo "❌ Failed to change shell."
                fi
                sleep 2
                ;;
            2)
                usermod -L "$USERNAME" # -L locks the account
                echo "✅ User $USERNAME account has been LOCKED (disabled)."
                sleep 2
                ;;
            3)
                usermod -U "$USERNAME" # -U unlocks the account
                echo "✅ User $USERNAME account has been UNLOCKED (enabled)."
                sleep 2
                ;;
            4)
                return
                ;;
            *)
                echo "⚠️ Invalid choice."
                sleep 2
                ;;
        esac
    done
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


# Function to create a new group
create_group() {
    echo "--- Create New Group ---"
    read -p "Enter new group name: " GROUPNAME
    groupadd "$GROUPNAME"
    if [ $? -eq 0 ]; then
        echo "✅ Group '$GROUPNAME' created successfully."
    else
        echo "❌ Failed to create group."
    fi
    echo "Press Enter to continue..."
    read -r
}

# Function to delete a group
delete_group() {
    echo "--- Delete Group ---"
    read -p "Enter group name to delete: " GROUPNAME
    groupdel "$GROUPNAME"
    if [ $? -eq 0 ]; then
        echo "✅ Group '$GROUPNAME' deleted successfully."
    else
        echo "❌ Failed to delete group. Ensure no primary users belong to it."
    fi
    echo "Press Enter to continue..."
    read -r
}

# Function to add a user to an existing group
add_user_to_group() {
    echo "--- Add User to Group ---"
    read -p "Enter username: " USERNAME
    read -p "Enter group name: " GROUPNAME

    # Check if user and group exist before adding
    if ! getent passwd "$USERNAME" > /dev/null; then
        echo "❌ Error: User '$USERNAME' does not exist."
        read -r
        return
    fi
    if ! getent group "$GROUPNAME" > /dev/null; then
        echo "❌ Error: Group '$GROUPNAME' does not exist."
        read -r
        return
    fi
    
    usermod -aG "$GROUPNAME" "$USERNAME" # -aG appends user to supplementary group
    if [ $? -eq 0 ]; then
        echo "✅ User '$USERNAME' added to group '$GROUPNAME' successfully."
    else
        echo "❌ Failed to add user to group."
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
	echo "2) Modify an Existing User"
        echo "3) Delete an Existing User"
        echo "4) List All Users"
        echo "5) ↩️ Back to Main Menu"
        echo "-----------------------------------------"
        echo -n "Enter your choice [1-5]: "
        read user_choice

        case "$user_choice" in
            1)
                create_user
                ;;
            2)
                modify_user
                ;;
            3)
                delete_user
                ;;
            4)
                list_users
                ;;
            5)
                return # Exits this function, returning to the main menu
                ;;
            *)
                echo "⚠️ Invalid choice. Please select 1, 2, 3, or 4."
                sleep 2
                ;;
        esac
    done
}


# Sub-Menu Display for Group Management
manage_groups_menu() {
    while true; do
        clear
        echo "========================================="
        echo "👥 GROUP MANAGEMENT"
        echo "========================================="
        echo "1) Create New Group"
        echo "2) Delete Group"
        echo "3) Add User to Group"
        echo "4) ↩️ Back to Main Menu"
        echo "-----------------------------------------"
        echo -n "Enter your choice [1-4]: "
        read group_choice

        case "$group_choice" in
            1)
                create_group
                ;;
            2)
                delete_group
                ;;
            3)
                add_user_to_group
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
    echo "2) 👥 Group Management"
    echo "2) 💾 System Backup"
    echo "3) 🚪 Exit Script"
    echo "-----------------------------------------"
    echo -n "Enter your choice [1-4]: "
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
            manage_groups_menu
            ;;
        3)
            system_backup
            ;;
        4)
            echo "Exiting Script. Goodbye!"
            exit 0
            ;;
        *)
            echo "⚠️ Invalid choice. Please select 1, 2, or 3."
            sleep 2
            ;;
    esac
done
