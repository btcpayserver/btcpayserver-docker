#!/bin/bash

# This script shows the steps to download and update an archive of the current UTXO Set

if ! [ "$0" = "$BASH_SOURCE" ]; then
    echo "This script must not be sourced" 
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root after running \"sudo su -\"" 
   exit 1
fi

: "${UTXO_DOWNLOAD_LINK:=http://utxosets.blob.core.windows.net/public/utxo-snapshot-bitcoin-mainnet-551636.tar}"
NETWORK=""
[[ $DOWNLOAD_LINK == *-testnet-* ]] && NETWORK="testnet"
[[ $DOWNLOAD_LINK == *-mainnet-* ]] && NETWORK="mainnet"
[[ $DOWNLOAD_LINK == *-regtest-* ]] && NETWORK="regtest"

BITCOIN_DATA_DIR="/var/lib/docker/volumes/generated_bitcoin_datadir/_data"
[ ! -d "$BITCOIN_DATA_DIR" ] && mkdir -p "$BITCOIN_DATA_DIR"

TAR_NAME="$(basename $DOWNLOAD_LINK)"
TAR_FILE="$BITCOIN_DATA_DIR/$TAR_NAME"

echo "Downloading $DOWNLOAD_LINK to $TAR_FILE"
cd "$BITCOIN_DATA_DIR"
if [ ! -f "$TAR_FILE" ]; then
  wget "$DOWNLOAD_LINK" -q --show-progress
else
  echo "$TAR_FILE already exists"
fi

echo "
fab994299273080bf7124c8c45c4ada867974ca747900178496a69e450cf713f  utxo-snapshot-bitcoin-mainnet-551636.tar
eabaaa717bb8eeaf603e383dd8642d9d34df8e767fccbd208b0c936b79c82742  utxo-snapshot-bitcoin-testnet-1445586.tar
" > "trusted-utxo-sets.asc"

grep "$TAR_NAME" "trusted-utxo-sets.asc" | tee "sig.asc"
rm "trusted-utxo-sets.asc"
if ! sha256sum -c "sig.asc"; then  
  echo "$TAR_FILE is not trusted"
  rm "sig.asc"
  cd -
  exit 1
fi
rm "sig.asc"
cd -

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
if ! tar -xf "$TAR_FILE" -C "$BITCOIN_DATA_DIR"; then
  echo "Failed extracting, did you turned bitcoin off? (btcpay-down.sh)"
  exit 1
fi
rm "$TAR_FILE"

BTCPAY_DATA_DIR="/var/lib/docker/volumes/generated_btcpay_datadir/_data"
[ ! -d "$BTCPAY_DATA_DIR" ] && mkdir -p "$BTCPAY_DATA_DIR"
echo "$TAR_NAME" > "$BTCPAY_DATA_DIR/FastSynced"

echo "Successfully downloaded and extracted, you can run btcpay again (btcpay-up.sh)"