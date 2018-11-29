#!/bin/bash

# This script shows the steps to create an archive of the current UTXO Set

exit # This script is not meant to run automatically


## ARGS#
NETWORK="testnet"
export AZURE_STORAGE_CONTAINER="public"
export AZURE_STORAGE_CONNECTION_STRING=""
#######

# IN THE HOST #############################################################

# Stop btcpay
btcpay-down.sh

# Run only bitcoind and connect to it
cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE run -e "NETWORK=$NETWORK" bitcoind bash

# IN THE CONTAINER #############################################################
ENVIRONMENT=""
BITCOIND="bitcoind -datadir=/data"
BITCOIN_CLI="bitcoin-cli -datadir=/data"

$BITCOIND &
BITCOIND_PID=$!
CURRENT_HEIGHT="$($BITCOIN_CLI -rpcwait getblockcount)"
let "PRUNED_HEIGHT=$CURRENT_HEIGHT - 289"

echo "Pruning to $PRUNED_HEIGHT"
$BITCOIN_CLI pruneblockchain "$PRUNED_HEIGHT"

echo "Waiting bitcoind to stop..."
$BITCOIN_CLI stop
wait $BITCOIND_PID

NETWORK_DIRECTORY=$NETWORK
if [[ $NETWORK == "mainnet" ]]; then
  NETWORK_DIRECTORY="."
fi
if [[ $NETWORK == "testnet" ]]; then
  NETWORK_DIRECTORY="testnet3"
fi

cd /data
TAR_NAME="utxo-snapshot-bitcoin-$NETWORK-$PRUNED_HEIGHT.tar"
echo "Creating $TAR_NAME..."
tar -cf "$TAR_NAME" "$NETWORK_DIRECTORY/blocks/"
tar -rf "$TAR_NAME" "$NETWORK_DIRECTORY/chainstate/"

# Exit from the container
exit

# IN THE HOST #############################################################

# Restart btcpay
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