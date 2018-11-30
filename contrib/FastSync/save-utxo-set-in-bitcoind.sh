# This file is internal and meant to be run by save-utxo-set.sh
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

NETWORK_DIRECTORY=$NBITCOIN_NETWORK
if [[ $NBITCOIN_NETWORK == "mainnet" ]]; then
  NETWORK_DIRECTORY="."
fi
if [[ $NBITCOIN_NETWORK == "testnet" ]]; then
  NETWORK_DIRECTORY="testnet3"
fi

cd /data
TAR_NAME="utxo-snapshot-bitcoin-$NBITCOIN_NETWORK-$PRUNED_HEIGHT.tar"
echo "Creating $TAR_NAME..."
tar -cf "$TAR_NAME" "$NETWORK_DIRECTORY/blocks/"
tar -rf "$TAR_NAME" "$NETWORK_DIRECTORY/chainstate/"
exit
