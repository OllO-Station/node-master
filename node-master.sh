#!/bin/bash

# Set text color to blue
echo -e "\033[34m"

display_ascii_art() {
    # Set background color to black and text color to green
    echo -e "\033[38;5;93m"
    echo "      █▀█ █░░ █░░ █▀█"      
    echo "      █▄█ █▄▄ █▄▄ █▄█"
    echo ""
    echo "      █▀ ▀█▀ ▄▀█ ▀█▀ █ █▀█ █▄░█"
    echo "      ▄█ ░█░ █▀█ ░█░ █ █▄█ █░▀█"
    # Reset terminal colors back to normal
    echo -e "\033[0m\033[34m"
}

# Function to install OLLO CLI and node software
install_software() {
    echo "Installing OLLO CLI and Node software..."
    export PATH="$PATH:/root/go/bin"
    git clone https://github.com/OllO-Station/ollo.git
    cd ollo
    make install
    echo "Software installed."
}

# Function to set up the environment
setup_environment() {
    echo "Setting up the environment..."
    # Fetch genesis.json from genesis node
    curl $MAINNODE_RPC/genesis? | jq ".result.genesis" > $HOME/.ollo/config/genesis.json
    ollod validate-genesis
    # Use curl to make the HTTP request and capture the response
    response=$(curl -s "$MAINNODE_RPC/status")
    # Extract the seed ID from the response
    seed_id=$(echo "$response" | jq -r '.result.node_info.id')
    MAINNODE_ID="$seed_id@73.14.46.216:26656"
    # set seed to main node's id manually
    sed -i 's/persistent_peers = ""/persistent_peers = "'$MAINNODE_ID'"/g' ~/.ollo/config/config.toml
    echo "Environment set up."
}

# Function to manage keys
manage_keys() {
    echo "Managing OLLO keys..."
    read -p "Do you have existing keys? (yes/no): " has_keys
    if [ "$has_keys" == "yes" ]; then
        echo "Please proceed to import your keys."
        echo "To import an existing key, you can use the following command:"
        echo "ollod keys add <name> --recover"
        read -p "Would you like to import keys now? (yes/no): " import_now
        if [ "$import_now" == "yes" ]; then
            read -p "Enter the name for the key: " key_name
            ollod keys add $key_name --recover
        fi
    else
        echo "Creating new keys."
        echo "To add a new key, you can use the following command:"
        echo "ollod keys add <name>"
        read -p "Would you like to create new keys now? (yes/no): " create_now
        if [ "$create_now" == "yes" ]; then
            read -p "Enter the name for the new key: " new_key_name
            ollod keys add $new_key_name
        fi
    fi
}

# Function to manage OLLO service
manage_service() {
    echo "Managing OLLO service..."
    read -p "Activate Service Management? (yes/no): " activate_service
    if [ "$activate_service" == "yes" ]; then
        sudo tee /etc/systemd/system/ollo.service > /dev/null <<EOF
[Unit]
Description=OLLO Daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which ollod) start
Restart=always
RestartSec=3
LimitNOFILE=8192
[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable ollo
        sudo systemctl start ollo
        echo "OLLO service activated."
    else
        echo "OLLO service not activated."
    fi
}

# Function to set up a full node
setup_full_node() {
    chain_id=$1
    echo "Setting up a full node for $chain_id..."
    
    # Initialize the node (Replace 'node_name' with your desired node name)
    ollod init node_name --chain-id $chain_id
    
    # Download and copy the genesis file
    # Replace this with the actual command to get the genesis file for the specific chain
    cp path/to/genesis.json ~/.ollod/config/genesis.json
    
    # Add seed nodes (Replace with actual seed node addresses)
    sed -i 's/seeds = ""/seeds = "seed1,seed2,seed3"/' ~/.ollochaind/config/config.toml
    
    # Start the node
    ollod start
    echo "Full node set up for $chain_id."
}

# Function to set up a validator node
setup_validator_node() {
    chain_id=$1
    echo "Setting up a validator node for $chain_id..."
    
    # Initialize the node and set up as in 'setup_full_node'
    # ...
    
    # Create a new key or import an existing one for the validator
    # Replace 'validator_key_name' with your desired key name
    ollod keys add validator_key_name
    
    # Generate a transaction to create the validator
    # Replace the relevant fields as required
    ollod tx staking create-validator \
        --amount=10000000stake \
        --pubkey=$(ollod tendermint show-validator) \
        --moniker="your_validator_name" \
        --chain-id=$chain_id \
        --commission-rate="0.10" \
        --commission-max-rate="0.20" \
        --commission-max-change-rate="0.01" \
        --min-self-delegation="1" \
        --gas="auto" \
        --from=validator_key_name
    
    echo "Validator node set up for $chain_id."
}

# Function to update validator details
update_validator() {
    chain_id=$1
    echo "Updating validator details for $chain_id..."
    
    # Update validator description
    ollochaind tx staking edit-validator \
        --moniker="new_validator_name" \
        --identity="new_identity" \
        --website="https://new-website.com" \
        --details="New details about the validator" \
        --from=validator_key_name \
        --chain-id=$chain_id
    
    # Update validator commission rate
    ollochaind tx staking edit-validator \
        --commission-rate="0.15" \
        --from=validator_key_name \
        --chain-id=$chain_id
    
    echo "Validator details updated for $chain_id."
}

# Main interactive menu
while true; do
    clear
    display_ascii_art
    echo "====================================="
    echo " OLLO CHAIN NODE SETUP"
    echo "====================================="
    echo "1. Install necessary software"
    echo "2. Set up environment"
    echo "3. Set up Keys"
    echo "4. Set up a validator node"
    echo "5. Set up a full node"
    echo "6. Update validator details"
    echo "7. Service Management"
    echo "8. Exit"
    echo "====================================="
    read -p "Select an option [1-8]: " option

    case $option in
        1)
            install_software
            ;;
        2)
            setup_environment
            ;;
        3)
            manage_keys
            ;;
        4)
            setup_validator_node
            ;;
        5)
            setup_full_node
            ;;
        6)
            update_validator
            ;;
        7)
            manage_service
            ;;
        8)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue"
done
