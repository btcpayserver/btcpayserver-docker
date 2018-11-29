#!/bin/bash

# This script shows the steps to download and update an archive of the current UTXO Set

exit # This script is not meant to run automatically


## ARGS#
NETWORK="testnet"
DOWNLOAD_LINK="http://utxosets.blob.core.windows.net/public/utxo-snapshot-bitcoin-testnet-1445586.tar"
TAR_FILE_HASH="eabaaa717bb8eeaf603e383dd8642d9d34df8e767fccbd208b0c936b79c82742"
#######

BITCOIN_DATA_DIR="/var/lib/docker/volumes/generated_bitcoin_datadir/_data"
[ ! -d "$BITCOIN_DATA_DIR" ] && mkdir -p "$BITCOIN_DATA_DIR"

TAR_FILE="$BITCOIN_DATA_DIR/snapshot.tar"
echo "Downloading $DOWNLOAD_LINK to $TAR_FILE"
wget "$DOWNLOAD_LINK" -q --show-progress -O "$TAR_FILE"

if ! echo "$TAR_FILE_HASH" "$TAR_FILE" | sha256sum -c -; then  
  echo "Invalid hash"
  exit 1
fi

NETWORK_DIRECTORY=$NETWORK
if [[ $NETWORK == "mainnet" ]]; then
  NETWORK_DIRECTORY="."
fi
if [[ $NETWORK == "testnet" ]]; then
  NETWORK_DIRECTORY="testnet3"
fi

NETWORK_DIRECTORY="$BITCOIN_DATA_DIR/$NETWORK_DIRECTORY"
[ -d "$NETWORK_DIRECTORY/blocks" ] && rm -rf "$NETWORK_DIRECTORY/blocks"
[ -d "$NETWORK_DIRECTORY/chainstate" ] && rm -rf "$NETWORK_DIRECTORY/chainstate"
[ ! -d "$NETWORK_DIRECTORY" ] && mkdir "$NETWORK_DIRECTORY"

echo "Extracting..."
tar -xf "$TAR_FILE" -C "$BITCOIN_DATA_DIR"

echo "Extracted"
rm "$TAR_FILE"