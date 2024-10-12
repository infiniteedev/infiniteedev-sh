#!/bin/bash

# Function to install PM2 if not installed
install_pm2() {
    if ! command -v pm2 &> /dev/null; then
        echo "PM2 is not installed. Installing PM2..."
        npm install -g pm2
        if [ $? -ne 0 ]; then
            echo "Failed to install PM2."
            exit 1
        fi
        echo "PM2 installed successfully."
    else
        echo "PM2 is already installed."
    fi
}

# Function to check and install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing Docker..."

        # Update package index and install prerequisites
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release

        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

        # Set up the Docker stable repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io

        # Add current user to the Docker group
        sudo usermod -aG docker $USER

        if [ $? -ne 0 ]; then
            echo "Failed to install Docker."
            exit 1
        fi

        echo "Docker installed successfully. Please log out and log in again for the group changes to take effect."
    else
        echo "Docker is already installed."
    fi
}

# Function to add Node.js repository and install Node.js and Git
install_node_git() {
    echo "Setting up Node.js 20.x repository and installing Node.js and Git..."

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    if [ $? -ne 0 ]; then
        echo "Failed to fetch the GPG key for Node.js repository."
        exit 1
    fi

    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

    sudo apt update
    sudo apt install -y nodejs git

    if [ $? -ne 0 ]; then
        echo "Failed to install Node.js or Git."
        exit 1
    fi
}

# Function to clone and set up the Skyport Panel
setup_skyport_panel() {
    echo "Choose an option for cloning Skyport Panel:"
    echo "1. Clone latest build"
    echo "2. Clone a specific version"

    read -p "Enter your choice for Panel (1 or 2): " panel_choice

    cd /etc || { echo "Failed to change directory to /etc"; exit 1; }

    case $panel_choice in
        1)
            echo "Cloning the latest build of Skyport Panel..."
            git clone https://github.com/skyportlabs/panel
            ;;
        2)
            read -p "Enter the version of Skyport Panel to clone (e.g., v0.2.2): " panel_version
            echo "Cloning Skyport Panel version $panel_version..."
            git clone --branch "$panel_version" https://github.com/skyportlabs/panel
            ;;
        *)
            echo "Invalid option for Panel. Please enter 1 or 2."
            exit 1
            ;;
    esac

    if [ $? -ne 0 ]; then
        echo "Failed to clone the Skyport Panel repository."
        exit 1
    fi

    mv panel skyport
    cd skyport || { echo "Failed to change directory to /etc/skyport"; exit 1; }

    echo "Installing dependencies for Skyport Panel..."
    npm install

    if [ $? -ne 0 ]; then
        echo "Failed to install dependencies for Skyport Panel."
        exit 1
    fi

    echo "Seeding the database for Skyport Panel..."
    npm run seed

    echo "Creating a user for Skyport Panel..."
    npm run createUser

    echo "Starting Skyport Panel with PM2..."
    pm2 start index.js -n skyport_panel
}

# Function to clone and set up the Skyport Daemon
setup_skyport_daemon() {
    echo "Choose an option for cloning Skyport Daemon:"
    echo "1. Clone latest build"
    echo "2. Clone a specific version"

    read -p "Enter your choice for Daemon (1 or 2): " daemon_choice

    cd /etc || { echo "Failed to change directory to /etc"; exit 1; }

    case $daemon_choice in
        1)
            echo "Cloning the latest build of Skyport Daemon..."
            git clone https://github.com/skyportlabs/skyportd
            ;;
        2)
            read -p "Enter the version of Skyport Daemon to clone (e.g., v0.2.2): " daemon_version
            echo "Cloning Skyport Daemon version $daemon_version..."
            git clone --branch "$daemon_version" https://github.com/skyportlabs/skyportd
            ;;
        *)
            echo "Invalid option for Daemon. Please enter 1 or 2."
            exit 1
            ;;
    esac

    if [ $? -ne 0 ]; then
        echo "Failed to clone the Skyport Daemon repository."
        exit 1
    fi

    cd skyportd || { echo "Failed to change directory to /etc/skyportd"; exit 1; }

    echo "Installing dependencies for Skyport Daemon..."
    npm install

    if [ $? -ne 0 ]; then
        echo "Failed to install dependencies for Skyport Daemon."
        exit 1
    fi

    # Prompt for command to run after installation
    read -p "Enter the command to run after configuring the daemon: " daemon_command
    eval "$daemon_command"

    echo "Starting Skyport Daemon with PM2..."
    pm2 start index.js -n skyport_daemon
}

# Function to update the Skyport Panel
update_skyport_panel() {
    echo "Updating Skyport Panel..."
    cd /etc/skyport || { echo "Skyport Panel directory not found."; exit 1; }
    git pull

    echo "Installing updated dependencies for Skyport Panel..."
    npm install

    echo "Restarting Skyport Panel with PM2..."
    pm2 restart skyport_panel
}

# Function to update the Skyport Daemon
update_skyport_daemon() {
    echo "Updating Skyport Daemon..."
    cd /etc/skyportd || { echo "Skyport Daemon directory not found."; exit 1; }
    git pull

    echo "Installing updated dependencies for Skyport Daemon..."
    npm install

    echo "Restarting Skyport Daemon with PM2..."
    pm2 restart skyport_daemon
}

# Function to backup Skyport Panel and Daemon
backup_installations() {
    echo "Backing up Skyport Panel and Daemon..."
    
    # Create backup directory
    backup_dir="/etc/skyport_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir "$backup_dir"
    
    cp -r /etc/skyport "$backup_dir/skyport"
    cp -r /etc/skyportd "$backup_dir/skyportd"

    echo "Backup completed. Backup stored in $backup_dir."
}

# Function to remove Skyport Panel and Daemon
remove_installation() {
    echo "Choose an option to remove:"
    echo "1. Remove Skyport Panel"
    echo "2. Remove Skyport Daemon"
    echo "3. Remove both Skyport Panel and Daemon"

    read -p "Enter your choice (1, 2, or 3): " remove_choice

    case $remove_choice in
        1)
            echo "Removing Skyport Panel..."
            rm -rf /etc/skyport
            ;;
        2)
            echo "Removing Skyport Daemon..."
            rm -rf /etc/skyportd
            ;;
        3)
            echo "Removing both Skyport Panel and Daemon..."
            rm -rf /etc/skyport /etc/skyportd
            ;;
        *)
            echo "Invalid choice for removal. Please enter 1, 2, or 3."
            exit 1
            ;;
    esac

    echo "Removal completed successfully!"
}

# Main script execution
install_node_git
install_docker
install_pm2

echo "Choose an option:"
echo "1. Install Skyport Panel"
echo "2. Install Skyport Daemon"
echo "3. Install both Skyport Panel and Daemon"
echo "4. Update Skyport Panel"
echo "5. Update Skyport Daemon"
echo "6. Backup installations"
echo "7. Remove installations"

read -p "Enter your choice (1-7): " choice

case $choice in
    1)
        setup_skyport_panel
        ;;
    2)
        setup_skyport_daemon
        ;;
    3)
        setup_skyport_panel
        setup_skyport_daemon
        ;;
    4)
        update_skyport_panel
        ;;
    5)
        update_skyport_daemon
        ;;
    6)
        backup_installations
        ;;
    7)
        remove_installation
        ;;
    *)
        echo "Invalid choice. Please enter a number between 1 and 7."
        exit 1
        ;;
esac
