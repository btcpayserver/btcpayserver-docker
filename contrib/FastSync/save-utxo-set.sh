#!/bin/bash

# This script shows the steps to create an archive of the current UTXO Set
# It will:
#   1. Shutdown BTCPay Server
#   2. Start bitcoind
#   3. Prune it to up to 289 blocks from the tip
#   4. Stop bitcoind
#   5. Archive in a tarball the blocks and chainstate directories
#   6. Restart BTCPay
#   7. If AZURE_STORAGE_CONNECTION_STRING is set, then upload to azure storage and make the blob public, else print hash and tarball

: "${AZURE_STORAGE_CONTAINER:=public}"

if [[ "$AZURE_STORAGE_CONNECTION_STRING" ]] && ! [ -x "$(command -v az)" ]; then
    echo "You want to upload the utxoset to azure, but az is not installed. See https://docs.microsoft.com/en-us/cli/azure/ to install it."
    exit
fi

echo "Closing down btcpay... it can take a while"
btcpay-down.sh

for i in /var/lib/docker/volumes/generated_bitcoin_datadir/_data/utxo-snapshot-*; do
    echo "Deleting $i"
    rm $i
done

rm /var/lib/docker/volumes/generated_bitcoin_datadir/_data/utxo-snapshot-*
# Run only bitcoind and connect to it
SCRIPT="$(cat save-utxo-set-in-bitcoind.sh)"
cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE run --rm -e "NBITCOIN_NETWORK=$NBITCOIN_NETWORK" bitcoind bash -c "$SCRIPT"
btcpay-up.sh

echo "Calculating the hash of the tar file..."
TAR_FILE="$(echo /var/lib/docker/volumes/generated_bitcoin_datadir/_data/utxo-snapshot-*)"
echo "Tar file of size $(ls -s -h $TAR_FILE)"
TAR_FILE_HASH="$(sha256sum "$TAR_FILE" | cut -d " " -f 1)"

if [[ "$AZURE_STORAGE_CONNECTION_STRING" ]]; then
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
else
    echo "SHA256: $TAR_FILE_HASH"
    echo "File at: $TAR_FILE"
fi
