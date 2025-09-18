#!/bin/bash

# OpenVPN Web Interface Wrapper
# This script provides a simple interface for web applications
# Usage: echo '{"name":"config","path":"path"}' | openvpn_web.sh <command>

OPENVPN_SCRIPT="/usr/local/x-ui/bin/openvpn_service.sh"

# Function to validate JSON data
validate_json() {
    local json="$1"
    if [ -z "$json" ]; then
        echo '{"error":"No JSON data provided"}'
        return 1
    fi

    # Check if it's valid JSON
    if command -v python3 >/dev/null 2>&1; then
        if ! echo "$json" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
            echo '{"error":"Invalid JSON format"}'
            return 1
        fi
    elif command -v jq >/dev/null 2>&1; then
        if ! echo "$json" | jq empty 2>/dev/null; then
            echo '{"error":"Invalid JSON format"}'
            return 1
        fi
    fi

    return 0
}

get_json_name() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    name = data.get('name', '')
    if isinstance(name, str):
        name = name.strip()
    print(name if name else '')
except Exception:
    print('')
" 2>/dev/null
    elif command -v jq >/dev/null 2>&1; then
        jq -r '.name // empty' 2>/dev/null
    else
        # Fallback if no json parser
        grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//'
    fi
}


# Parse command
cmd="${1:-status}"

# Check if OpenVPN script exists and is executable
if [ ! -x "$OPENVPN_SCRIPT" ]; then
    echo "{\"error\":\"OpenVPN service script not found or not executable: $OPENVPN_SCRIPT\"}"
    exit 1
fi

case "$cmd" in
    "list")
        exec "$OPENVPN_SCRIPT" --web list
        ;;
    "start"|"stop"|"status"|"ip"|"edit")
        # For these commands, we expect JSON on stdin
        if [ -t 0 ]; then
            echo '{"error":"No JSON data provided via stdin"}'
            exit 1
        fi
        
        json_data=$(cat)
        config_name=$(echo "$json_data" | get_json_name)

        if [ -z "$config_name" ]; then
            echo '{"error":"Could not parse config name from JSON"}'
            exit 1
        fi
        
        # Execute the command with the parsed config name
        exec "$OPENVPN_SCRIPT" "$cmd" "$config_name"
        ;;
    "health")
        # Health check command
        if [ -d "/usr/local/x-ui/openvpn" ] && [ -x "$OPENVPN_SCRIPT" ]; then
            echo '{"status":"healthy","message":"OpenVPN service is operational"}'
        else
            echo '{"status":"unhealthy","error":"OpenVPN service components missing"}'
            exit 1
        fi
        ;;
    *)
        echo '{"error":"Invalid command. Use: list, start, stop, status, ip, edit, health"}'
        exit 1
        ;;
esac
