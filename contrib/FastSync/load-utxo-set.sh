#!/bin/bash

set -e

# This script shows the steps to download and deploy an archive of the current UTXO Set
# It will:
#   1. Download the UTXO Set from UTXO_DOWNLOAD_LINK, if UTXO_DOWNLOAD_LINK is empty, use NBITCOIN_NETWORK to find a default
#   2. Check the tarball against trusted hashes
#   3. Create the container's folders for blocks and chainstate, or empty them if they exists
#   4. Unzip the tarball
# This will download the utxo set and untar it in bitcoin's folder
# Usage: ./load-utxo-set.sh
# This will use the tar to load the utxo in bitcoin's folder
# Usage: ./load-utxo-set.sh utxo-snapshot-bitcoin-mainnet-565305.tar

if ! [ "$0" = "$BASH_SOURCE" ]; then
    echo "This script must not be sourced" 
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root after running \"sudo su -\"" 
   exit 1
fi

if ! [[ "$NBITCOIN_NETWORK" ]]; then
    echo "NBITCOIN_NETWORK should be set to mainnet, testnet or regtest" 
    exit 1
fi

TAR_FILE="$1"

if ! [[ "$UTXO_DOWNLOAD_LINK" ]]; then
    [[ $NBITCOIN_NETWORK == "mainnet" ]] && UTXO_DOWNLOAD_LINK="http://utxosets.blob.core.windows.net/public/utxo-snapshot-bitcoin-mainnet-680891.tar"
    [[ $NBITCOIN_NETWORK == "testnet" ]] && UTXO_DOWNLOAD_LINK="http://utxosets.blob.core.windows.net/public/utxo-snapshot-bitcoin-testnet-1445586.tar"
fi

if ! [[ "$UTXO_DOWNLOAD_LINK" ]] && ! [[ "$TAR_FILE" ]]; then
    echo "No default UTXO_DOWNLOAD_LINK for $NBITCOIN_NETWORK" 
    exit 1
fi

BITCOIN_DATA_DIR="$(docker volume inspect generated_bitcoin_datadir -f "{{.Mountpoint}}" 2>/dev/null)" || \
BITCOIN_DATA_DIR="/var/lib/docker/volumes/generated_bitcoin_datadir/_data"

[ ! -d "$BITCOIN_DATA_DIR" ] && mkdir -p "$BITCOIN_DATA_DIR"

if [[ "$TAR_FILE" ]]; then
  TAR_NAME="$(basename $TAR_FILE)"
else
  TAR_NAME="$(basename $UTXO_DOWNLOAD_LINK)"
  TAR_FILE="$BITCOIN_DATA_DIR/$TAR_NAME"
fi

TAR_DIR="$(dirname "$TAR_FILE")"
cp "utxo-sets" "$TAR_DIR/utxo-sets"
cd "$TAR_DIR"
IS_DOWNLOADED=false
if [ ! -f "$TAR_FILE" ]; then
  echo "Downloading $UTXO_DOWNLOAD_LINK to $TAR_FILE"
  wget "$UTXO_DOWNLOAD_LINK" -q --show-progress
  IS_DOWNLOADED=true
else
  echo "$TAR_FILE already exists"
fi

grep "$TAR_NAME" "utxo-sets" | tee "utxo-set"
rm "utxo-sets"
if ! sha256sum -c "utxo-set"; then
  echo "$TAR_FILE is not trusted"
  rm "utxo-set"
  cd -
  exit 1
fi
rm "utxo-set"
cd -

NETWORK_DIRECTORY=$NBITCOIN_NETWORK
if [[ $NBITCOIN_NETWORK == "mainnet" ]]; then
  NETWORK_DIRECTORY="."
fi
if [[ $NBITCOIN_NETWORK == "testnet" ]]; then
  NETWORK_DIRECTORY="testnet3"
fi

NETWORK_DIRECTORY="$BITCOIN_DATA_DIR/$NETWORK_DIRECTORY"
[ -d "$NETWORK_DIRECTORY/blocks" ] && ( rm -rf "$NETWORK_DIRECTORY/blocks" || rm -rf $NETWORK_DIRECTORY/blocks/* )
[ -d "$NETWORK_DIRECTORY/chainstate" ] && rm -rf "$NETWORK_DIRECTORY/chainstate"
[ ! -d "$NETWORK_DIRECTORY" ] && mkdir "$NETWORK_DIRECTORY"

echo "Extracting..."
if ! tar -xf "$TAR_FILE" -C "$BITCOIN_DATA_DIR"; then
  echo "Failed extracting, did you turned bitcoin off? (btcpay-down.sh)"
  exit 1
fi
$IS_DOWNLOADED && rm -f "$TAR_FILE"

BTCPAY_DATA_DIR="$(docker volume inspect generated_btcpay_datadir -f "{{.Mountpoint}}" 2>/dev/null)" || \
BTCPAY_DATA_DIR="/var/lib/docker/volumes/generated_btcpay_datadir/_data"

[ ! -d "$BTCPAY_DATA_DIR" ] && mkdir -p "$BTCPAY_DATA_DIR"
echo "$TAR_NAME" > "$BTCPAY_DATA_DIR/FastSynced"

echo "Successfully downloaded and extracted."

if docker volume inspect generated_bitcoin_wallet_datadir &>/dev/null; then
  echo -e '\033[33mWARNING: You need to delete your Bitcoin Core wallet before restarting with "btcpay-up.sh", or bitcoin core will fail to start.\033[0m'
  echo -e '\033[33mDo not delete the wallet if you have any funds on it. (For example, this may be the case if you use Eclair or FullyNoded to receive funds)\033[0m'
  echo -e '\033[33mHow to proceed: If you agree to delete your Bitcoin Core wallet, run "docker volume rm generated_bitcoin_wallet_datadir"\033[0m'
else
  echo "You can now run btcpay again (btcpay-up.sh)"
fi