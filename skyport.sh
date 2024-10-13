#!/bin/bash

# --- Function to Install Node.js and Git ---
install_node_git() {
    echo "Installing Node.js 20.x and Git..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

    sudo apt update
    sudo apt install -y nodejs git
    if [ $? -ne 0 ]; then
        echo "Error: Node.js or Git installation failed!"
        exit 1
    fi
}

# --- Function to Install Docker ---
install_docker() {
    echo "Checking for Docker installation..."
    if ! command -v docker &> /dev/null; then
    echo "Docker not found, installing Docker..."

    # Update package list
    sudo apt update
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update package list!"
        exit 1
    fi

    # Install necessary packages for Docker installation
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive.gpg
    
    # Add Docker's APT repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

    # Update package index and install Docker
    sudo apt update
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update package list after adding Docker repository!"
        exit 1
    fi

    sudo apt install -y docker-ce docker-ce-cli containerd.io
    if [ $? -ne 0 ]; then
        echo "Error: Docker installation failed!"
        exit 1
    fi

    echo "Docker installed successfully."
else
    echo "Docker is already installed."
fi

# Verify Docker installation
docker --version

}

# --- Function to Install PM2 ---
install_pm2() {
    echo "Checking for PM2 installation..."
    if ! command -v pm2 &> /dev/null; then
        echo "PM2 not found, installing PM2..."
        npm install -g pm2
        if [ $? -ne 0 ]; then
            echo "Error: PM2 installation failed!"
            exit 1
        fi
        echo "PM2 installed successfully."
    else
        echo "PM2 is already installed."
    fi
}

# --- Function to Install Dependencies ---
install_dependencies() {
    echo "Installing dependencies..."
    install_node_git
    install_docker
    install_pm2
}

# --- Function to Clone and Set Up the Skyport Panel ---
setup_skyport_panel() {
    echo "Installing dependencies for Skyport Panel..."
    install_dependencies

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
        echo "Error: Failed to clone Skyport Panel!"
        exit 1
    fi

    cd panel || { echo "Failed to change directory to panel"; exit 1; }
    npm install
    npm run seed
    npm run createUser

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Skyport Panel dependencies!"
        exit 1
    fi
    echo "Starting Skyport Daemon with PM2..."
    pm2 start index.js -n skyport_panel
    echo "Skyport Panel installed successfully."
}

# --- Function to Clone and Set Up the Skyport Daemon ---
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
        echo "Error: Failed to clone Skyport Daemon!"
        exit 1
    fi

    cd skyportd || { echo "Failed to change directory to skyportd"; exit 1; }

    echo "Installing dependencies for Skyport Daemon..."
    npm install

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Skyport Daemon dependencies!"
        exit 1
    fi

    echo "Dependencies for Skyport Daemon installed successfully."

    # Prompt for command to run after installation
    read -p "Enter the command to configure the daemon with the panel: " daemon_command
    eval "$daemon_command"

    echo "Starting Skyport Daemon with PM2..."
    node .
}

# --- Function to Backup Installations ---
backup_installations() {
    echo "Backing up installations..."
    backup_dir="/etc/skyport_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    cp -r /etc/panel "$backup_dir/panel"
    cp -r /etc/skyportd "$backup_dir/skyportd"

    if [ $? -ne 0 ]; then
        echo "Error: Backup failed!"
        exit 1
    fi

    echo "Backup completed successfully to $backup_dir."
}

# --- Function to Remove Installations ---
remove_installations() {
    read -p "Are you sure you want to remove Skyport Panel and Daemon? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "Aborting removal."
        exit 0
    fi

    echo "Removing Skyport Panel..."
    rm -rf /etc/panel
    echo "Removing Skyport Daemon..."
    rm -rf /etc/skyportd

    echo "Removing installed dependencies..."
    sudo apt purge -y nodejs git docker-ce docker-ce-cli containerd.io
    sudo apt autoremove -y

    echo "Installations removed successfully."
}

# --- Main Menu ---
while true; do
    echo "Choose an option:"
    echo "1. Install Skyport Panel"
    echo "2. Install Skyport Daemon"
    echo "3. Install both Skyport Panel and Daemon"
    echo "4. Update Skyport Panel"
    echo "5. Update Skyport Daemon"
    echo "6. Backup installations"
    echo "7. Remove installations"
    echo "8. Install Dependencies"
    echo "9. Exit"

    read -p "Enter your choice (1-9): " choice

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
            echo "Updating Skyport Panel..."
            # Add your update logic here
            ;;
        5)
            echo "Updating Skyport Daemon..."
            # Add your update logic here
            ;;
        6)
            backup_installations
            ;;
        7)
            remove_installations
            ;;
        8)
            install_dependencies
            ;;
        9)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option! Please enter a number between 1 and 9."
            ;;
    esac
done
