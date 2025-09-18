#!/bin/bash

OPENVPN_DIR="/usr/local/x-ui/openvpn"
OPENVPN_LOG_DIR="/var/log/openvpn"

# Export WEB_INTERFACE flag for all operations when called with --web
if [[ "$1" == "--web" ]]; then
    export WEB_INTERFACE=true
    shift
fi

# Create log directory if it doesn't exist
mkdir -p "$OPENVPN_LOG_DIR"

# Detect if called from web interface (when arguments contain [object Object])
if [[ "$*" == *"[object Object]"* ]]; then
    export WEB_INTERFACE=true
fi

# Function to list all OpenVPN configurations
list_configs() {
    if [ ! -d "$OPENVPN_DIR" ]; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"error\":\"OpenVPN directory does not exist: $OPENVPN_DIR\"}"
        else
            echo "OpenVPN directory does not exist: $OPENVPN_DIR" >&2
        fi
        return 1
    fi

    local configs=()
    while IFS= read -r -d '' file; do
        local config_name
        config_name=$(basename "$file" .ovpn)
        # Skip if config name is empty or contains only spaces
        if [ -n "$config_name" ] && [[ "$config_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            configs+=("$config_name")
        fi
    done < <(find "$OPENVPN_DIR" -name "*.ovpn" -type f -print0)

    if [ ${#configs[@]} -eq 0 ]; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"configs\":[],\"message\":\"No OpenVPN configuration files found in $OPENVPN_DIR\"}"
        else
            echo "No OpenVPN configuration files found in $OPENVPN_DIR"
        fi
        return 1
    fi

    # Check if output should be JSON (for web interface)
    if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
        local json_configs=""
        for config in "${configs[@]}"; do
            local status="stopped"
            local ip_addr=""
            local ip_json="\"ip\":null"

            # Get status and IP if running
            if pgrep -f "^openvpn.*--config.*$config\.ovpn" > /dev/null 2>&1; then
                status="running"
                # Try to get IP address
                ip_result=$(get_ip "$config" 2>/dev/null)
                if [[ "$ip_result" == *'"ip"'* ]]; then
                    ip_addr=$(echo "$ip_result" | sed -n 's/.*"ip":"\([^"]*\)".*/\1/p')
                    if [ -n "$ip_addr" ]; then
                        ip_json="\"ip\":\"$ip_addr\""
                    fi
                fi
            fi

            local config_json="{\"name\":\"$config\",\"path\":\"$OPENVPN_DIR/$config.ovpn\",\"status\":\"$status\",${ip_json}}"
            if [ -z "$json_configs" ]; then
                json_configs="$config_json"
            else
                json_configs="$json_configs,$config_json"
            fi
        done
        echo "{\"configs\":[${json_configs:-\"\"}],\"total\":${#configs[@]}}"
    else
        printf '%s\n' "${configs[@]}"
    fi
}

# Function to start an OpenVPN configuration
start_config() {
    local config_name="$1"
    local config_path="$OPENVPN_DIR/$config_name.ovpn"
    local log_file="$OPENVPN_LOG_DIR/${config_name}.log"

    if [ ! -f "$config_path" ]; then
        echo "Error: Configuration file $config_name.ovpn not found"
        exit 1
    fi

    # Check if already running
    if pgrep -f "^openvpn.*--config.*$config_name\.ovpn" > /dev/null 2>&1; then
        echo "OpenVPN configuration $config_name is already running"
        exit 0
    fi
    
    # Start OpenVPN in daemon mode
    openvpn --config "$config_path" --daemon --log "$log_file" --writepid "/var/run/openvpn.$config_name.pid"

    # Wait a bit and check if process is running
    sleep 5
    if pgrep -f "^openvpn.*--config.*$config_name\.ovpn" > /dev/null 2>&1; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"running\",\"message\":\"OpenVPN configuration started successfully\"}"
        else
            echo "OpenVPN configuration $config_name started successfully"
        fi
    else
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"stopped\",\"error\":\"Failed to start OpenVPN configuration\"}"
        else
            echo "Failed to start OpenVPN configuration $config_name"
        fi
        exit 1
    fi
}

# Function to stop an OpenVPN configuration
stop_config() {
    local config_name="$1"
    local config_path="$OPENVPN_DIR/$config_name.ovpn"
    local pid_file="/var/run/openvpn.$config_name.pid"

    if [ -z "$config_name" ]; then
        echo "Error: No configuration name provided"
        return 1
    fi

    if [ ! -f "$config_path" ]; then
        echo "Error: Configuration file $config_name.ovpn not found"
        return 1
    fi
    
    if [ -f "$pid_file" ]; then
        kill $(cat "$pid_file") 2>/dev/null
        rm -f "$pid_file"
        echo "OpenVPN configuration $config_name stopped"
    else
        # Try to find and kill by process name if pid file not found
        pkill -f "^openvpn.*--config.*$config_name\.ovpn"
        if [ $? -eq 0 ]; then
            echo "OpenVPN configuration $config_name stopped"
        else
            echo "No running OpenVPN configuration found for $config_name"
        fi
    fi
}

# Function to check status of an OpenVPN configuration
check_status() {
    local config_name="$1"

    if [ -z "$config_name" ]; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"error\":\"no configuration name provided\"}"
        else
            echo "error: no configuration name provided"
        fi
        return 1
    fi

    # Check if configuration file exists
    if [ ! -f "$OPENVPN_DIR/$config_name.ovpn" ]; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"stopped\"}"
            return 0
        else
            echo "error: configuration file not found"
            return 1
        fi
    fi

    # Check if OpenVPN process is running for this configuration
    # Use a more specific pattern to avoid false positives
    if pgrep -f "^openvpn.*--config.*$config_name\.ovpn" > /dev/null 2>&1; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"running\"}"
        else
            echo "running"
        fi
    else
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"stopped\"}"
        else
            echo "stopped"
        fi
    fi
}

# Function to get IP address of an OpenVPN interface
get_ip() {
    local config_name="$1"

    if [ -z "$config_name" ]; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":null,\"status\":\"unknown\",\"ip\":null,\"error\":\"Could not determine config name\"}"
            return 0
        else
            echo "Error: Could not determine config name"
            return 1
        fi
    fi

    # Check if OpenVPN process is running for this config
    if ! pgrep -f "^openvpn.*--config.*$config_name\.ovpn" > /dev/null 2>&1; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"stopped\",\"ip\":null}"
        else
            echo "OpenVPN not running for $config_name"
        fi
        return 1
    fi

    # Get all VPN interfaces that are UP
    local vpn_interfaces=()
    while IFS= read -r line; do
        # Parse interface name from ip link output (format: "6: tun0: <UP...")
        if [[ $line =~ ^[0-9]+:\ ([a-z0-9]+): ]]; then
            local iface="${BASH_REMATCH[1]}"
            # Check if this is a VPN interface and if it's UP
            if [[ $iface =~ ^(tun|tap)[0-9]+$ ]] && [[ $line =~ "UP" ]]; then
                vpn_interfaces+=("$iface")
            fi
        fi
    done < <(ip link show 2>/dev/null)

    if [ ${#vpn_interfaces[@]} -eq 0 ]; then
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"name\":\"$config_name\",\"status\":\"running\",\"ip\":null}"
            return 0
        else
            echo "No active VPN interface found"
        fi
        return 1
    fi

    # Try to get IP from each VPN interface
    for interface_name in "${vpn_interfaces[@]}"; do
        # Get IPv4 addresses
        local ip_addr=""
        ip_addr=$(ip -4 addr show "$interface_name" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)

        # If no IPv4, try IPv6
        if [ -z "$ip_addr" ]; then
            ip_addr=$(ip -6 addr show "$interface_name" 2>/dev/null | grep -oP 'inet6 \K[0-9a-f:]+' | grep -v '^::1\|^fe80' | head -1)
        fi

        if [ -n "$ip_addr" ]; then
            if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
                echo "{\"name\":\"$config_name\",\"status\":\"running\",\"ip\":\"$ip_addr\"}"
            else
                echo "$ip_addr"
            fi
            return 0
        fi
    done

    # If we get here, we found interfaces but no IP addresses
    if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
        echo "{\"name\":\"$config_name\",\"status\":\"running\",\"ip\":null}"
        return 0
    else
        echo "VPN interface found but no IP address assigned"
    fi
}

# Function to edit a configuration file
edit_config() {
    local config_name="$1"
    local config_path="$OPENVPN_DIR/$config_name.ovpn"

    if [ -z "$config_name" ]; then
        echo "Error: No configuration name provided"
        return 1
    fi

    if [ ! -f "$config_path" ]; then
        echo "Error: Configuration file $config_name.ovpn not found"
        return 1
    fi

    # Open the file in the default editor
    ${EDITOR:-nano} "$config_path"
}

# Main command handling logic
cmd="$1"
config_name="$2"

if [[ "$1" == "--web" ]]; then
    export WEB_INTERFACE=true
    cmd="$2"
    config_name="$3"
fi

case "$cmd" in
    "list") 
        list_configs 
        ;;
    "start"|"stop"|"status"|"ip"|"edit")
        if [ -z "$config_name" ]; then
            if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
                echo "{\"error\":\"Usage: $0 $cmd <config_name>\"}"
            else
                echo "Usage: $0 $cmd <config_name>"
            fi
            exit 1
        fi
        
        # Call the appropriate function. 
        # Note: bash doesn't allow dynamic function calls with arguments easily and safely
        # without using eval. A case statement is safer.
        case "$cmd" in
            "start") start_config "$config_name" ;;
            "stop") stop_config "$config_name" ;;
            "status") check_status "$config_name" ;;
            "ip") get_ip "$config_name" ;;
            "edit") edit_config "$config_name" ;;
        esac
        ;;
    *)
        if [[ "${WEB_INTERFACE:-false}" == "true" ]]; then
            echo "{\"error\":\"Usage: $0 {list|start|stop|status|ip|edit} [config_name]\"}"
        else
            echo "Usage: $0 {list|start|stop|status|ip|edit} [config_name]"
        fi
        exit 1
        ;;
esac