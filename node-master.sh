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
    MAINNODE_RPC="https://rpc.ollo.zone"
    CONFIG="$HOME/.ollo/config/config.toml"
    APPCONFIG="$HOME/.ollo/config/app.toml"
    # Download and copy the genesis file
    # Replace this with the actual command to get the genesis file for the specific chain
    curl $MAINNODE_RPC/genesis? | jq ".result.genesis" > $HOME/.ollo/config/genesis.json

    ollod validate-genesis
    response=$(curl -s "$MAINNODE_RPC/status")
    seed_id=$(echo "$response" | jq -r '.result.node_info.id')
    MAINNODE_ID="$seed_id@73.14.46.216:26656"
    sed -i 's/persistent_peers = ""/persistent_peers = "'$MAINNODE_ID'"/g' ~/.ollo/config/config.toml
    sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["*"\]/g' "$CONFIG"
    sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' "$CONFIG"
    sed -i '/\[api\]/,+3 s/enable = false/enable = true/' "$APPCONFIG"
    sed -i '/\[api\]/,+3 s/swagger = false/swagger = true/' "$APPCONFIG"
    sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g'  "$APPCONFIG"
    sed -i 's/api = "eth,net,web3"/api = "eth,txpool,personal,net,debug,web3"/g' "$APPCONFIG"
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
            read -p "Enter the name for the key: " new_key_name
            ollod keys add $new_key_name --recover
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
init_new_node() {
    chain_id="ollo-testnet-2"
    echo "Setting up a full node for $chain_id..."
    
    read -p "Enter node moniker (e.g., my_node): " moniker

    # Initialize the node (Replace 'node_name' with your desired node name)
    ollod init $moniker --chain-id $chain_id --overwrite
    
    echo "Initialization $moniker node for $chain_id."
}

setup_validator_node() {
    read -p "Enter amount (e.g., 1000000000000uollo): " amount
    read -p "Enter commission rate (e.g., 0.10): " commission_rate
    read -p "Enter commission max rate (e.g., 0.20): " commission_max_rate
    read -p "Enter commission max change rate (e.g., 0.05): " commission_max_change_rate
    read -p "Enter min self delegation (e.g., 1000000): " min_self_delegation
    read -p "Enter your website: " website
    read -p "Enter details: " details
    read -p "Enter security contact email: " security_contact
    read -p "Enter identity (e.g., KEYBASE PGP): " identity
    echo "Setting up a validator node for $chain_id..."
    
    ollod tx staking create-validator \
        --amount="$amount" \
        --pubkey="$(ollod tendermint show-validator)" \
        --moniker="$moniker" \
        --chain-id=$chain_id \
        --commission-rate="$commission_rate" \
        --commission-max-rate="$commission_max_rate" \
        --commission-max-change-rate="$commission_max_change_rate" \
        --min-self-delegation="$min_self_delegation" \
        --gas="auto" \
        --gas-adjustment="1.5" \
        --from="$new_key_name" \
        --website="$website" \
        --details="$details" \
        --security-contact="$security_contact" \
        --identity="$identity"
    echo "Validator node set up."
}


# Function to update validator details
update_validator() {
    chain_id="ollo-testnet-2"
    echo "Updating validator details for $chain_id..."
    
    # Update validator description
    ollod tx staking edit-validator \
        --moniker="$moniker" \
        --identity="new_identity" \
        --website="https://new-website.com" \
        --details="New details about the validator" \
        --from="$new_key_name" \
        --chain-id=$chain_id
    
    # Update validator commission rate
    ollod tx staking edit-validator \
        --commission-rate="0.15" \
        --from="$new_key_name" \
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
    echo "2. Init new node"
    echo "3. Set up environment"
    echo "4. Set up Keys"
    echo "5. Service Management"
    echo "6. Set up a validator node"
    echo "7. Update validator details"
    echo "8. Exit"
    echo "====================================="
    read -p "Select an option [1-8]: " option

    case $option in
        1)
            install_software
            ;;
        2)
            init_new_node
            ;;
        3)
            setup_environment
            ;;
        4)
            manage_keys
            ;;
        5)
            manage_service
            ;;
        6)
            setup_validator_node
            ;;
        7)
            update_validator
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
