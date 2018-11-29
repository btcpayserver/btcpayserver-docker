#!/bin/bash

# This script shows the steps to create an archive of the current UTXO Set

exit 1 # This script is not meant to run automatically


## ARGS#
NETWORK="mainnet"
export AZURE_STORAGE_CONTAINER="public"
export AZURE_STORAGE_CONNECTION_STRING=""
#######

# IN THE HOST #############################################################

# Stop btcpay
btcpay-down.sh

# Run only bitcoind and connect to it
SCRIPT="$(cat save-utxo-set-in-bitcoind.sh)"
cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE run -e "NETWORK=$NETWORK" bitcoind bash -c "$SCRIPT"
btcpay-up.sh

TAR_FILE="$(echo /var/lib/docker/volumes/generated_bitcoin_datadir/_data/utxo-snapshot-*)"
TAR_FILE_HASH="$(sha256sum "$TAR_FILE" | cut -d " " -f 1)"
echo "SHA256: $TAR_FILE_HASH"
echo "Uploading to azure..."
# Install az from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest

BLOB_NAME="$(basename -- $TAR_FILE)"
az storage container create --name "$AZURE_STORAGE_CONTAINER" --public-access "blob"
az storage blob upload -f "$TAR_FILE" \
                       -c "$AZURE_STORAGE_CONTAINER" \
                       -n "$BLOB_NAME" \
                       --content-type "application/x-tar"

az storage blob metadata update --container-name "$AZURE_STORAGE_CONTAINER" --name "$BLOB_NAME" --metadata "sha256=$TAR_FILE_HASH"

# Print the sha256sum. Downloaders will need to verify this
STORAGE_URL="$(az storage blob url --container-name "$AZURE_STORAGE_CONTAINER" --name "$BLOB_NAME" --protocol "http")"
echo "You can now download the UTXO on $STORAGE_URL"
echo "Please, after download, verify the sha256 with:"
echo "echo "$TAR_FILE_HASH  $BLOB_NAME" | sha256sum -c -"
rm "$TAR_FILE"