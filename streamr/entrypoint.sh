#!/bin/bash

config_path=/home/streamr/.streamr/config/default.json
private_key_source_path=/home/streamr/.streamr/config/private_key_source.txt

# Function to generate a new private key
function generate_private_key {
  key=$(openssl ecparam -name secp256k1 -genkey -noout | openssl ec -text -noout 2>/dev/null)
  private_key=$(echo -n "$key" | grep priv -A 3 | tail -n +2 | tr -d '\n[:space:]:' | sed 's/^00//')
  echo "0x$private_key"
}

# Function to generate the configuration file
function generate_config {
  local private_key
  local current_private_key_source
  local current_private_key
  local current_api_key

  # Read current private key, source, and API key if config files exist
  if [ -f "$config_path" ]; then
    current_private_key=$(jq -r '.client.auth.privateKey' "$config_path")
    current_api_key=$(jq -r '.apiAuthentication.keys[0]' "$config_path")
  fi

  if [ -f "$private_key_source_path" ]; then
    current_private_key_source=$(cat "$private_key_source_path")
  fi

  # Consider current_private_key as null if it is "null"
  if [[ "$current_private_key" == "null" ]]; then
    current_private_key=""
  fi

  # Generate a new private key if needed
  if [[ "$PRIVATE_KEY_SOURCE" == "Generate" ]]; then
    if [[ "$current_private_key_source" != "Generate" ]] || [[ -z "$current_private_key" ]]; then
      private_key=$(generate_private_key)
    else
      private_key="$current_private_key"
    fi
  else
    private_key="$PRIVATE_KEY"
  fi

  # Determine the network environment
  if [[ "$NETWORK" == "Streamr 1.0 mainnet + Polygon" ]]; then
    environment="polygon"
  elif [[ "$NETWORK" == "Streamr 1.0 testnet + Polygon Amoy testnet" ]]; then
    environment="polygonAmoy"
  else
    echo "Invalid NETWORK value"
    exit 1
  fi

  # Construct the JSON configuration
  json_content=$(jq -n \
    --arg schema "https://schema.streamr.network/config-v3.schema.json" \
    --arg privateKey "$private_key" \
    --arg environment "$environment" \
    '{
      "$schema": $schema,
      "client": {
        "auth": {
          "privateKey": $privateKey
        },
        "environment": $environment
      },
      "plugins": {}
    }'
  )

  # Add optional operator plugin if specified
  if [[ -n "$OPERATOR" ]]; then
    json_content=$(echo "$json_content" | jq --arg operator "$OPERATOR" '.plugins.operator = {operatorContractAddress: $operator}')
  fi

  # Add websocket plugin if specified
  if [[ "$WEBSOCKET_PLUGIN" == "Yes" ]]; then
    json_content=$(echo "$json_content" | jq '.plugins.websocket = {}')
  fi

  # Add MQTT plugin if specified
  if [[ "$MQTT_PLUGIN" == "Yes" ]]; then
    json_content=$(echo "$json_content" | jq '.plugins.mqtt = {}')
  fi

  # Add HTTP plugin if specified
  if [[ "$HTTP_PLUGIN" == "Yes" ]]; then
    json_content=$(echo "$json_content" | jq '.plugins.http = {}')
  fi

# Use existing API key if it exists, otherwise generate a new one
  if [[ -z "$current_api_key" || "$current_api_key" == "null" ]]; then
    api_key=$(echo -n $(uuidgen | tr -d '-') | base64 | tr -cd '[:alnum:]')
  else
    api_key="$current_api_key"
  fi

  json_content=$(echo "$json_content" | jq --arg api_key "$api_key" '.apiAuthentication.keys = [$api_key]')

  # Save the configuration file and the private key source
  mkdir -p $(dirname "$config_path")
  echo "$json_content" > $config_path
  echo "$PRIVATE_KEY_SOURCE" > $private_key_source_path
}

# Generate the configuration file
generate_config

# Execute the Streamr broker
exec npm exec -c streamr-broker
