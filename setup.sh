#!/bin/bash

# Check if jq is installed, and install if not
if ! command -v jq &> /dev/null; then
    sudo apt-get update && sudo apt-get install jq -y
fi

if ! [ -f /etc/resolvconf/resolv.conf.d/head ]; then
    sudo apt-get update && sudo apt-get install resolvconf -y
fi

# Define usage function
usage() {
    echo "Usage: $0 [-e EMAIL] [-p PASSWORD]"
    echo "Options:"
    echo "  -e, --email EMAIL   Email address to use for login"
    echo "  -p, --password PASS Password to use for login"
    echo "  -h, --help          Show this help message and exit"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -e | --email)
        email="$2"
        shift 2
        ;;
    -p | --password)
        pass="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *) # unknown option
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

# Prompt for email and password if not provided
if [ -z "$email" ] || [ -z "$pass" ]; then
    read -p "Email : " email
    read -p "Pass  : " pass
fi

# Get the user token
token=$(curl -Ss --request POST \
    --url https://api.controld.com/preauth/login \
    --header 'content-type: application/json' \
    --data "{\"email\":\"$email\",\"password\":\"$pass\",\"ttl\":\"1m\"}" | jq -r '.body.token')

# Get the session ID
sessionID=$(curl -Ss --request POST \
    --url https://api.controld.com/users/login \
    --header 'content-type: application/json' \
    --data "{\"email\":\"$email\",\"password\":\"$pass\",\"ttl\":\"1m\",\"token\":\"$token\"}" | jq -r '.body.session')

# Get the device ID
device=$(curl -Ss --request GET \
    --url https://api.controld.com/devices \
    --header "authorization: ${sessionID}" \
    --header 'content-type: application/json')

deviceId=$(echo "$device" | jq -r '.body.devices[0].resolvers.uid')
ipv4=$(echo "$device" | jq -r '.body.devices[0].resolvers.v4[0]')

# Add IP
addIP=$(curl -Ss --request POST \
    --url "https://api.controld.com/access?device_id=${deviceId}" \
    --header "authorization: ${sessionID}" \
    --header 'content-type: application/json' \
    --data "{\"ips\":[\"$(curl -Ss ipv4.icanhazip.com)\"]}" | grep -ic "1 IPs added")

# Print result
if [[ ${addIP} != '0' ]]; then
    echo "Success, Added $(curl -Ss ipv4.icanhazip.com)"
    echo ""
    echo "IP DNS : ${ipv4}"
    echo "Credit : @sam_sfx"
else
    echo "Sorry, Unsuccessful"
    echo "Credit : @sam_sfx"
fi
