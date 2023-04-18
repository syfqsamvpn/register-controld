#!/bin/bash
clear

# Define colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

show_help() {
  cat << EOF
Options:
  -e, --email EMAIL   Email address to use for login
  -p, --password PASS Password to use for login
  -d, --device DEVICE Device ID to add IP to (default: first device)
  -i, --ips IPS       Comma-separated list of IP addresses to add
  -t, --ttl TTL       Time-to-live for the IP addresses (default: 1m)
  -h, --help          Show this help message and exit
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -e|--email)
      email="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--password)
      pass="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--device)
      device="$2"
      shift # past argument
      shift # past value
      ;;
    -i|--ips)
      ips="$2"
      shift # past argument
      shift # past value
      ;;
    -t|--ttl)
      ttl="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *) # unknown option
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Prompt for email and password if not provided as arguments
if [ -z "$email" ] || [ -z "$pass" ]; then
  read -p "Email: " email
  read -sp "Password: " pass
  echo
fi

# Mask password in output
echo -e "${GREEN}Logging in with email ${email} and password ********${NC}"

# Get the user token
token=$(curl -Ss --request POST \
    --url https://api.controld.com/preauth/login \
    --header 'content-type: application/json' \
    --data "{\"email\":\"$email\",\"password\":\"$pass\",\"ttl\":\"$ttl\"}" | jq -r '.body.token')

if [ -z "$token" ]; then
  echo -e "${RED}Error: Failed to get user token${NC}"
  echo "Credit: @sam_sfx"
  exit 1
fi

echo -e "${GREEN}Successfully received user token${NC}"

# Get the session ID
sessionID=$(curl -Ss --request POST \
    --url https://api.controld.com/users/login \
    --header 'content-type: application/json' \
    --data "{\"email\":\"$email\",\"password\":\"$pass\",\"ttl\":\"$ttl\",\"token\":\"$token\"}" | jq -r '.body.session')

if [ -z "$sessionID" ]; then
  echo -e "${RED}Error: Failed to get session ID${NC}"
  echo "Credit: @sam_sfx"
  exit 1
fi

echo -e "${GREEN}Successfully received session ID${NC}"

# Get the device ID
if [ -z "$device" ]; then
  # If device ID not specified, use the first device in the list
  deviceId=$(curl -Ss --request GET \
      --url https://api.controld.com/devices \
      --header "authorization: ${sessionID}" \
      --header 'content-type: application/json' | jq -r '.body.devices[0].resolvers.uid')
else
  deviceId="$device"
fi

if [ -z "$deviceId" ]; then
  echo -e "${RED}Error: Failed to get device ID${NC}"
  echo "Credit: @sam_sfx"
  exit 1
fi

echo -e "${GREEN}Successfully received device ID${NC}"

if [ -z "$ips" ]; then
  # If IP addresses not specified, get the current IP address
  ips="$(curl -Ss ipv4.icanhazip.com)"
fi

# Add IP addresses
addIP=$(curl -Ss --request POST \
    --url "https://api.controld.com/access?device_id=${deviceId}" \
    --header "authorization: ${sessionID}" \
    --header 'content-type: application/json' \
    --data "{\"ips\":[\"${ips}\"]}" | grep -ic "1 IPs added")

if [ $addIP -eq 1 ]; then
  echo -e "${GREEN}Success: Added IP(s) ${ips} to device ${deviceId}${NC}"
  echo "Credit: @sam_sfx"
else
  echo -e "${RED}Error: Failed to add IP(s) ${ips} to device ${deviceId}${NC}"
  echo "Credit: @sam_sfx"
  exit 1
fi
