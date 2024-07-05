#!/bin/bash

# create_users.sh
# This script creates users and groups based on the input file, sets up home directories with appropriate permissions and ownership, generates random passwords for the users, and logs all actions to a log file.

# Input file format: username;groups
# Example input file:
# light;sudo,dev,www-data
# idimma;sudo
# mayowa;dev,www-data

# Log file path
LOG_FILE="/var/log/user_management.log"
# Secure password file path
SECURE_PASS_FILE="/var/secure/user_passwords.txt"

# Check if input file is provided
if [ -z "$1" ]; then
    echo "Error: Input file not provided. Usage: $0 <input_file.txt>"
    exit 1
fi

# Check if log file directory exists, create it if not
if [ ! -d "/var/log" ]; then
    sudo mkdir -p /var/log
	sudo chmod 755 /var/log
fi

# Check if secure password file directory exists, create it if not
if [ ! -d "/var/secure" ]; then
    sudo mkdir -p /var/secure
	sudo chmod 700 /var/secure
fi


# Ensure log file exists and has correct permissions
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    sudo chown $USER "$LOG_FILE"
fi

# Ensure secure password file exists and has correct permissions
if [ ! -f "$SECURE_PASS_FILE" ]; then
    sudo touch "$SECURE_PASS_FILE"
    sudo chmod 600 "$SECURE_PASS_FILE"
    sudo chown $USER "$SECURE_PASS_FILE"
fi

# Function to generate a random password
generate_password() {
    # Generate a random password with a length of 12 characters
    local password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)
    echo "$password"
}

# Function to create a user and set up the home directory
create_user() {
    local username="$1"
    local groups="$2"

    # Create the user
    if id "$username" &>/dev/null; then
        echo "User '$username' already exists. Skipping user creation." | tee -a "$LOG_FILE"
    else
        sudo useradd -m -s /bin/bash "$username"
        echo "Created user '$username'." | tee -a "$LOG_FILE"
    fi

    # Create the user's personal group
    local personal_group="$username"
    if ! groupadd "$personal_group" &>/dev/null; then
        echo "Group '$personal_group' already exists. Skipping group creation." | tee -a "$LOG_FILE"
    else
        echo "Created group '$personal_group'." | tee -a "$LOG_FILE"
    fi

    # Add the user to the personal group
    sudo usermod -a -G "$personal_group" "$username"
    echo "Added user '$username' to group '$personal_group'." | tee -a "$LOG_FILE"

    # Add the user to additional groups
    for group in $(echo "$groups" | tr ',' ' '); do
        if ! groupadd "$group" &>/dev/null; then
            echo "Group '$group' already exists. Skipping group creation." | tee -a "$LOG_FILE"
        else
            echo "Created group '$group'." | tee -a "$LOG_FILE"
        fi
        sudo usermod -a -G "$group" "$username"
        echo "Added user '$username' to group '$group'." | tee -a "$LOG_FILE"
    done

    # Set up the home directory
    local home_dir="/home/$username"
    if [ ! -d "$home_dir" ]; then
        sudo mkdir "$home_dir"
    fi
    sudo chown "$username:$personal_group" "$home_dir"
    sudo chmod 750 "$home_dir"
    echo "Set up home directory for user '$username'." | tee -a "$LOG_FILE"

    # Generate a random password for the user
    local password=$(generate_password)
    echo "$username,$password" >> "$SECURE_PASS_FILE"
    sudo echo "$username:$password" | sudo chpasswd
    echo "Set password for user '$username'." | tee -a "$LOG_FILE"
}

# Process the input file
while IFS=";" read -r username groups; do
    create_user "$username" "$groups"
done < "$1"

echo "User management script completed. Logs are available at $LOG_FILE"
echo "Secure user passwords are stored in $SECURE_PASS_FILE"