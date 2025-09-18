#!/bin/bash

OPENVPN_DIR="/usr/local/x-ui/openvpn"
OPENVPN_LOG_DIR="/var/log/openvpn"

# Export WEB_INTERFACE flag for all operations when called with --web
if [[ "$1" == "--web" ]]; then
    export WEB_INTERFACE=true
    shift
fi

# Function to parse config name from argument (handles JavaScript objects)
parse_config_name() {
    local arg="$1"

    echo "DEBUG: parse_config_name called with: '$arg'" >&2

    # Check if argument is exactly "[object Object]" (JavaScript object toString)
    if [[ "$arg" == "[object Object]" ]]; then
        echo "DEBUG: Detected [object Object], trying to read from stdin" >&2
        # For web interface calls, try to read JSON from stdin first
        if [ ! -t 0 ]; then
            # Read from stdin
            if command -v python3 >/dev/null 2>&1; then
                config_name=$(python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    name = data.get('name', '')
    if name and name != '[object Object]':
        print(name)
    else:
        print('')
except Exception as e:
    print('')
" 2>/dev/null)
                if [ -n "$config_name" ] && [ "$config_name" != "[object Object]" ]; then
                    echo "DEBUG: Parsed from stdin using Python: '$config_name'" >&2
                    echo "$config_name"
                    return 0
                fi
            else
                # Fallback to jq if available
                if command -v jq >/dev/null 2>&1; then
                    config_name=$(jq -r '.name // empty' 2>/dev/null)
                    if [ -n "$config_name" ] && [ "$config_name" != "[object Object]" ] && [ "$config_name" != "null" ]; then
                        echo "DEBUG: Parsed from stdin using jq: '$config_name'" >&2
                        echo "$config_name"
                        return 0
                    fi
                fi
            fi
        fi
        # If no stdin or parsing failed, return empty
        echo "DEBUG: No valid data from stdin, returning empty" >&2
        echo ""
        return 1
    fi

    # Check if argument is a JavaScript object string
    if [[ "$arg" == *'"name"'* ]]; then
        echo "DEBUG: Detected JSON-like argument, trying to parse" >&2
        # Try to extract name using Python (more reliable than sed)
        if command -v python3 >/dev/null 2>&1; then
            config_name=$(echo "$arg" | python3 -c "
import sys, json, re
try:
    # Clean up the argument - remove any extra quotes or malformed JSON
    arg = sys.stdin.read().strip()
    # Try to fix common JSON issues
    arg = re.sub(r'([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:', r'\1\"\2\":', arg)
    data = json.loads(arg)
    name = data.get('name', '')
    if name and name != '[object Object]':
        print(name)
    else:
        print('')
except Exception as e:
    print('')
" 2>/dev/null)
        elif command -v jq >/dev/null 2>&1; then
            # Fallback to jq if Python not available
            config_name=$(echo "$arg" | jq -r '.name // empty' 2>/dev/null)
        else
            # Last resort fallback to sed
            config_name=$(echo "$arg" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"//p' | sed 's/".*//' | sed 's/.*,//')
        fi

        if [ -n "$config_name" ] && [ "$config_name" != "[object Object]" ] && [ "$config_name" != "null" ]; then
            echo "DEBUG: Parsed from JSON argument: '$config_name'" >&2
            echo "$config_name"
            return 0
        fi
    fi

    # If not a JSON object or parsing failed, return the argument as-is (but clean it up)
    # Remove any trailing commas or malformed parts
    clean_arg=$(echo "$arg" | sed 's/,$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ "$clean_arg" != "[object Object]" ]; then
        echo "DEBUG: Returning cleaned argument: '$clean_arg'" >&2
        echo "$clean_arg"
    else
        echo "DEBUG: Cleaned argument is [object Object], returning empty" >&2
        echo ""
        return 1
    fi
}

# Test the parse function
echo "Testing parse_config_name with 'vpnbook-de20-tcp80':"
result=$(parse_config_name "vpnbook-de20-tcp80")
echo "Result: '$result'"