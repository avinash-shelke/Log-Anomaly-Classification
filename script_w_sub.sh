#!/bin/bash

# This script reads the tenant, region, and subscription from a CSV file and creates a subscription in Azure API Management
# shell script command : ./script_w_pos_par.sh <file> <resourceGroupName> <serviceName> <primaryKey> <secondaryKey> <state> <subscription_name> <allowTracing>
# ./script_w_pos_par.sh no_subscription.csv apix-na-dev-rg apix-na-dev sub_123 sub_345 active ABCDEF_1234 false

# Load environment variables from the .env file
source .env

# Positional parameters for the script
file=$1
resourceGroupName=$2
serviceName=$3

primaryKey=$4
secondaryKey=$5
state=$6
subscription_name=$7
allowTracing=$8

tenants=()
regions=()

# Skip the header row
skip_headers=true

while IFS=, read -r tenant region sub; do
    if [ "$skip_headers" = true ]; then
        skip_headers=false
        continue
    fi

    tenants+=("$tenant")
    regions+=("$region")
done < "$file"

echo "Tenants: ${tenants[@]}"
echo "Number of Tenants: ${#tenants[@]}"
echo "Regions: ${regions[@]}"
echo "Number of Regions: ${#regions[@]}"

# Get the access token
access_url="https://login.microsoftonline.com/$TENANT_ID/oauth2/token"

res=$(curl -X POST "$access_url" -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&resource=https://management.azure.com/")

token=$(echo "$res" | grep -o '"access_token":"[^"]*' | awk -F':' '{print $2}' | sed 's/"//g')

echo "Access Token: $token"

for i in "${!tenants[@]}"; do
    echo "Processing Tenant: ${tenants[$i]} in Region: ${regions[$i]}"

    url="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.ApiManagement/service/$serviceName/subscriptions/$subscription_name?api-version=2022-08-01"
    data="{\"properties\":{\"primaryKey\":\"$primaryKey\",\"secondaryKey\":\"$secondaryKey\",\"state\":\"$state\",\"displayName\":\"$subscription_name\",\"scope\":\"/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.ApiManagement/service/$serviceName/products/AXPStandardTier\",\"allowTracing\":$allowTracing}}"

    response=$(curl -X PUT "$url" \
             -H "Content-Type: application/json" \
             -H "Authorization: Bearer $token" \
             -d "$data")

    echo "Created the tenant ${tenants[$i]} in region ${regions[$i]} with response: $response"
    break
done
