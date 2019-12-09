#!/usr/bin/env bash

# Author: Marco Tijbout
# Version: 2.0a
# Release: Public
# Last Update: 05-Dec-19
# Modification Note(s):

################################################################################
## Set Variables
################################################################################
INPUT_FILE="users-list"
LOG_FILE="output-userCreation.log"
ORG_ADMINS="id-string"
SYSTEM_ADMINS="id-string"
PASSWORD="password"

## Start with empty log file.
> $LOG_FILE

################################################################################
## User Interaction
################################################################################
clear

echo -e "\\nPlease enter your Pulse environment (e.g. iotc001.vmware.com)"
read -p 'Pulse instance: ' PULSEINSTANCE
# PULSEINSTANCE="iotc00x.vmware.com"

echo -e "\\nPlease enter your username (e.g. msmith@pulse.local) to log in to Pulse"
read -p 'Username: ' ADMIN_ACCOUNT
# ADMIN_ACCOUNT="username@domain.local"

echo -e "\\nPlease enter the password for the account $ADMIN_ACCOUNT"
echo -n "Password: "
read -s ADMIN_PASSWORD
# ADMIN_PASSWORD="your_password"

echo -e "\\n\\nThank you, we are now going to programatically create a few things in the Pulse Console using Rest API calls.\n"
read -n 1 -s -r -p "Press any key to continue"
echo -e "\\n"

################################################################################
## Rest API Calls to manipulate Pulse
################################################################################

## Identify current Pulse API version
APIVersion=$(curl --request GET \
  --url https://$PULSEINSTANCE:443/api/versions \
  --header 'Accept: application/json;api-version=1.0' \
  --header 'Cache-Control: no-cache' \
  --header 'Connection: keep-alive' \
  --header 'Content-Type: application/json' \
  --header "'Host: $PULSEINSTANCE:443'" \
  --header 'accept-encoding: gzip, deflate' \
| awk -F ':' '{print $2'} | awk -F ',' '{print $1}' | sed -e 's/"//g')

## Use Basic Auth to retrieve Bearer Token
BearerToken=$(curl --user ${ADMIN_ACCOUNT}:${ADMIN_PASSWORD} --request GET \
--url https://$PULSEINSTANCE:443/api/tokens \
--header "Accept: application/json;api-version=$APIVersion" \
--header 'Cache-Control: no-cache' \
--header 'Connection: keep-alive' \
--header 'Content-Type: application/json' \
--header "'Host: $PULSEINSTANCE:443'" \
--header 'accept-encoding: gzip, deflate' \
--header 'cache-control: no-cache' \
| grep accessToken | awk -F ':' '{print $2}' | awk -F ',' '{print $1}' | sed -e 's/"//g' | tr -d '\n')
# echo $BearerToken >$LOG_FILE

################################################################################
## Function that creates the user account.
################################################################################
doMagic() {
    echo '{
    "userName": "'$2'",
    "displayName": "'$1'",
    "email": "'$3'",
    "password":"'$PASSWORD'",
    "status":"ACTIVE",
    "groups": ["'$ORG_ADMINS'","'$SYSTEM_ADMINS'"]
    }' |  \
    http --verify=no POST https://$PULSEINSTANCE:443/api/users \
    Accept:"application/json;api-version=$APIVersion" \
    Authorization:"Bearer $BearerToken" \
    Cache-Control:no-cache \
    Connection:keep-alive \
    Content-Type:application/json \
    Host:$PULSEINSTANCE:443 \
    >> $LOG_FILE
}

IFS=$';' #< Define the separator for the columns in the input file.
while read line ; do
    set $line
    echo -e "\n[INFO] Processing account for:" $1
    doMagic $1 $2 $3 $BearerToken $PULSEINSTANCE $APIVersion $ORG_ADMINS $SYSTEM_ADMINS $PASSWORD
done < $INPUT_FILE

echo -e "\n[INFO] Done processing accounts..."

cat $LOG_FILE