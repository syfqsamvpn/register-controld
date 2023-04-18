
#!/bin/bash
clear

show_help() {
  cat << EOF
Options:
  -e, --email EMAIL   Email address to use for login
  -p, --password PASS Password to use for login
  -h, --help          Show this help message and exit
EOF
}

if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

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
deviceId=$(curl -Ss --request GET \
    --url https://api.controld.com/devices \
    --header "authorization: ${sessionID}" \
    --header 'content-type: application/json' | jq -r '.body.devices[0].resolvers.uid')

# Add IP
addIP=$(curl -Ss --request POST \
    --url "https://api.controld.com/access?device_id=${deviceId}" \
    --header "authorization: ${sessionID}" \
    --header 'content-type: application/json' \
    --data "{\"ips\":[\"$(curl -Ss ipv4.icanhazip.com)\"]}" | grep -ic "1 IPs added")

# Print result
if [[ ${addIP} != '0' ]]; then
    echo "Success, Add $(curl -Ss ipv4.icanhazip.com)"
    echo "Credit : @sam_sfx"
else
    echo "Sorry, Unsuccessful"
    echo "Credit : @sam_sfx"
fi
