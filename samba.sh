#!/usr/bin/env bash
set -Eeuo pipefail

# This function adds a new user to samba user database
# Takes username and NTLM password hash as parameters 
add_samba_user() {
    local username="$1"
    local password="$2"

    tempPass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 128; echo)

    echo -e "$tempPass\n$tempPass" | pdbedit -a -u "$username" > /dev/null
    pdbedit -u "$username" --set-nt-hash="$password" > /dev/null
    echo "User $username has been added and password set."

    return 0
}

# This function checks for the existence of a specified Samba user and group. If the user does not exist, 
# it creates a new user with the provided username, user ID (UID), group name, group ID (GID), and password. 
# If the user already exists, it updates the user's UID and group association as necessary, 
# and updates the password in the Samba database. The function ensures that the group also exists, 
# creating it if necessary, and modifies the group ID if it differs from the provided value.
add_user() {
    local cfg="$1"
    local username="$2"
    local uid="$3"
    local password="$4"
    local groupname="$5"
    local gid="$6"

    # Check if the user already exists, if not, create it
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist, creating user..."
        adduser -S -D -h "/storage/$username" -s /sbin/nologin -u "$uid" "$username" || { echo "Failed to create user $username"; return 1; }
        if [[ -n "$groupname" && -n "$gid" ]]; then
            echo "Creating and applying group $groupname to $username..."
            # Create group if it doesn't exist yet.
            if ! getent group "$groupname" > /dev/null 2>&1; then
                groupadd -g $gid "$groupname" || { echo "Failed to create group $groupname"; return 1; }
            else
                echo "Group $groupname already exists. Skipping creation of $groupname group..."
            fi
            # Add group to user
            usermod -aG "$groupname" "$username" || { echo "Failed to apply group $groupname to $username"; return 1; }
        fi
    else
        # Check if the uid right,if not, change it
        local current_uid
        current_uid=$(id -u "$username")
        if [[ "$current_uid" != "$uid" ]]; then
            echo "User $username exists but UID differs, updating UID..."
            usermod -o -u "$uid" "$username" > /dev/null || { echo "Failed to update UID for user $username"; return 1; }
        fi

        # Update user's group
        usermod -g "$groupname" "$username" > /dev/null || { echo "Failed to update group for user $username"; return 1; }
    fi

    # Check if the user is not a samba user, set password of and enable user for samba if not a user yet
    # Prevents changed passwords from being overwritten 
    if ! (pdbedit -s "$cfg" -L | grep -q "^$username:"); then
        # If the user is not a samba user, create it and set a password
        # echo -e "$password\n$password" | smbpasswd -a -c "$cfg" -s "$username" > /dev/null || { echo "Failed to add Samba user $username"; return 1; }
        add_samba_user "$username" "$password"
    fi

    return 0
}

# This function creates a directory at given path with ownership of nobody:gid, where gid is the given group id.
# Parameters are path, gid
create_groupshare() {
    local path="$1"
    local gid="$2"
    
    if [ ! -d "$path" ]; then
        echo "$path does not exist. Creating group share directory at $path..."
        mkdir -p "$path" || { echo "Failed to create directory $path"; return 1; }
    fi
    echo "Setting ownership of $path to nobody:$gid..."
    chown "nobody:$gid" "$path" || { echo "Failed to change ownership of $path to nobody:$gid"; return 1; }

    return 0
}

# Set variables for group and share directory
share="/storage"
config="/etc/samba/smb.conf"

users=$(readlink -f /run/secrets/users)
groupshares=$(readlink -f /run/secrets/groupshares)
agent_secrets=$(readlink -f /run/secrets/agent)

if [ ! -f "/run/agent/agent_created" ]; then
    if [ -s "$agent_secrets" ]; then
        agent_user=$(grep -v "#" $agent_secrets) # remove any comments
        agent_username=$(echo "$agent_user" | cut -d':' -f1)
        agent_pass=$(echo "$agent_user" | cut -d':' -f2)
        
        echo "Agent secrets found! Creating healthcheck agent $agent_username..."

        useradd -N -s /sbin/nologin -r "$agent_username"
        echo -e "$agent_pass\n$agent_pass" | smbpasswd -a -c "$config" -s "$agent_username" > /dev/null
    else
        echo "Healthcheck agent secrets not found"; exit 1
    fi
    mkdir -p /run/agent
    touch /run/agent/agent_created
fi

# Create shared directory
mkdir -p "$share" || { echo "Failed to create directory $share"; exit 1; }

# Check if users file exists
if [ -s "$users" ]; then
    echo "Found users file! Creating users..."
    while read -r line; do
        # Skip lines that are comments or empty
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

        # Split each line by colon and assign to variables
        username=$(echo "$line" | cut -d':' -f1)
        uid=$(echo "$line" | cut -d':' -f2)
        password=$(echo "$line" | cut -d':' -f3)
        groupname=$(echo "$line" | cut -d':' -f4)
        gid=$(echo "$line" | cut -d':' -f5)

        # Check if all required fields are present
        if [[ -z "$username" || -z "$uid" || -z "$password" ]]; then
            echo "Skipping incomplete line: $line"
            continue
        fi

        add_user "$config" "$username" "$uid" "$password" "$groupname" "$gid"  || { echo "Failed to add user $username"; exit 1; }

    done < "$users"
else
    echo "Could not find users file. Skipping user creation..."
fi

# Create specified group shares if groupshares.conf is found
if [ -f "$groupshares" ] && [ -s "$groupshares" ]; then
    echo "Found groupshares file! Creating shares..."
    while read -r line; do

        # Skip lines that are comments or empty
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

        # Split each line by colon and assign to variables
        path=$(echo "$line" | cut -d':' -f1)
        gid=$(echo "$line" | cut -d':' -f2)

        # Check if all required fields are present
        if [[ -z "$path" || -z "$gid" ]]; then
            echo "Skipping incomplete line: $line"
            continue
        fi

        create_groupshare "$share/$path" "$gid"

    done < "$groupshares"
else
    echo "Could not find groupshares file. Skipping groupshare creation..."
fi

# Store configuration location for Healthcheck
ln -sf "$config" /etc/samba.conf

# Start the Samba daemon with the following options:
#  --configfile: Location of the configuration file.
#  --foreground: Run in the foreground instead of daemonizing.
#  --debug-stdout: Send debug output to stdout.
#  --debuglevel=1: Set debug verbosity level to 1.
#  --no-process-group: Don't create a new process group for the daemon.
exec smbd --configfile="$config" --foreground --debug-stdout --debuglevel=1 --no-process-group