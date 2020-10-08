# Fast sync for Bitcoin

## What problem does Fast Sync solve?

When you start a new BTCPay Server, you need to synchronize your Bitcoin node from the genesis block.

Validating from the genesis blocks takes in general 1 or 2 days on affordable servers. (around 10$ per months)

However, on some low powered devices like raspberry PI, synchronization time will take around 2 weeks nowadays. (and it will linearly increase with time)

Fast sync provides a solution to decrease dramatically the synchronization time to minutes or few hours.

__Current UTXO Set snapshots only work for Bitcoin Core 0.17.0 or higher. Do NOT use these sets on older versions of Bitcoin Core (0.16.3 or lower)__

## How does Fast Sync solve it?

In order for Bitcoin software to operate, you do not need all the history of blocks from the genesis. 

What you need is the state of Bitcoin up to a certain block (this state is called `UTXO Set`), and around 300 blocks before this point.

Fast Sync downloads the UTXO Set at a specific block on an external server, and deploy it on your node. We call this file a `UTXO Set snapshot`.

When your node start up again, it will only need to synchronize from the snapshot, to the latest blocks.

## What are the downsides of Fast Sync?

### Malicious UTXO Set

Fast Sync can be potentially abused:
1. The attacker gives you an `UTXO Set snapshot` which does not follow Bitcoin consensus
2. The attacker makes a purchase to your store. 
3. Nodes following the consensus would not recognize the payment as valid, but your node will. 
4. The coins the attacker sent you are just worthless

Other attacks can completely bring down your node.

### Lightning Network routing issues

As a merchant, you generally do not care about this issue. Merchants are mainly receiving payment, so they don't need to do any routing.

However, if you plan to send payments from your lightning node, you may have issues:

Because you do not have old blocks, then your lightning node won't see any channels which have been created prior to the snapshot.

If this is a problem for you, just use an older snapshot.

## How to verify that the UTXO Set snapshot follows the consensus?

### If you trust the owner of this repository....

The snapshots recognized as valid by the `btcpayserver-docker` repository you cloned can be found on [utxo-sets](utxo-sets).

The script [load-utxo-set.sh](load-utxo-set.sh) will download the utxo-set from the environment variable `UTXO_DOWNLOAD_LINK`.

If `UTXO_DOWNLOAD_LINK` is empty, `NBITCOIN_NETWORK` (with value set to `mainnet` or `testnet`) will be used to take a default `UTXO_DOWNLOAD_LINK` that we hard coded inside [load-utxo-set.sh](load-utxo-set.sh).

Once the files are downloaded, the hash will be checked against those in [utxo-sets](utxo-sets).


However: This only prove that `if the owner of this git repository is honest`, then the utxo-set are correct.

NOTE: **Completing those steps does not mean that the UTXO set snapshot is legit**. It only mean that you trust the owner of this git repositoy to have verified that it is legit.

### If you trust someone else...

This repository contains the signatures of some developers, for example [sigs/NicolasDorier.utxo-sets.asc](sigs/NicolasDorier.utxo-sets.asc) contains the hashes that `NicolasDorier` verified himself.

You need to verify with [KeyBase command line](https://keybase.io/docs/command_line) that the signature is legit:
```bash
keybase pgp verify -i sigs/NicolasDorier.utxo-sets.asc
```
If you don't like command line, you can verify against [keybase verify page](https://keybase.io/verify) by just copying and pasting the content of [sigs/NicolasDorier.utxo-sets.asc](sigs/NicolasDorier.utxo-sets.asc).


You can verify that the handle `NicolasDorier` refers to the person who controls `NicolasDorier` twitter, github and reddit handle on [the keybase profile page](https://keybase.io/NicolasDorier).

NOTE: **Completing those steps does not mean that the UTXO set snapshot is legit**. It only mean that you trust the owner of a Keybase account who has proved access to some social media accounts in the past.

### Don't trust, verify!<a name="donttrust"></a>

If you don't trust anybody, which should be the case as much as possible, then here are the steps to verify that the UTXO set is not malicious.

1. You need another node that you own, `under your control`, that `you synchronized from the genesis block`. Let's call this node `Trusty`.
2. You need to create a new node which use `Fast Sync` with the UTXO snapshot you want to verify. Let's call this node, `Synchy`.
3. Wait that `Synchy` is fully synched.
4. Now on `Synchy` and `Trusty` run at the same time:

```bash
 bitcoin-cli gettxoutsetinfo
```
If `Synchy` or `Trusty` are using BTCPay Server use:
```bash
bitcoin-cli.sh gettxoutsetinfo
```


5. Verify that the output of `Synchy` and `Trusty` are identical (you can ignore `disk_size`).

NOTE: Completing those steps, under the assumption the software you are running is not malicious, **correctly prove that the UTXO set snapshot is legit**.

## FAQ
### Can I add my signature to this repository?

If you are a bitcoin developer or public figure, feel free to add your signature. For this you need:

1. A [keybase account](http://keybase.io) linked to your social media accounts.
2. Follow the steps described in the [Don't trust, verify!](#donttrust) section each snapshots you want to sign.
3. Create a file with same format as [utxo-sets](utxo-sets) with the snapshots you validated. (Let's call this file `YOU.utxo-sets`)
4. Run the following command line

```bash
# Assuming your are inside the FastSync directory
keybase pgp sign -i YOU.utxo-sets -c -t -o sigs/YOU.utxo-sets.asc
rm YOU.utxo-sets
git add sigs/YOU.utxo-sets.asc
git commit -m "Add YOU utxo-set signature" --all
```
And make a pull request to `btcpayserver-docker` repository.

### Where can I download UTXO set snapshots

You should not need to do this, because [load-utxo-set.sh](load-utxo-set.sh) do the hard work for you. 

But if you really want, just browse on [this listing](http://utxosets.blob.core.windows.net/public?restype=container&comp=list&include=metadata). 

Select the snapshot you want, and download it by querying `http://utxosets.blob.core.windows.net/public/{blobName}`.

### How can I create my own snapshot?

Assuming you have a node running on a docker deployment of BTCPay Server, you just need to run [save-utxo-set.sh](save-utxo-set.sh).

 This script shows the steps to create an archive of the current UTXO Set
 It will:
1. Shutdown BTCPay Server
2. Start bitcoind
3. Prune it to up to 289 blocks from the tip
4. Stop bitcoind
5. Archive in a tarball the blocks and chainstate directories
6. Restart BTCPay
7. If `AZURE_STORAGE_CONNECTION_STRING` is set, then upload to azure storage and make the blob public, else print hash and tarball

### How can I do this for my altcoin?

Your altcoin does not need it, almost nobody use it compared to bitcoin.

However, if you insist, follow what we did for Bitcoin, we can't hand hold you on this.

### Do you plan to destroy Bitcoin?

This feature may be controversial, because of the risk that almost nobody will follow the [Don't trust, verify!](#donttrust) step.

What if somebody start spreading a corrupted snapshot on wild scale?

I think this issue can be mitigated at the social layer. If several person start using social media for spreading their `bitcoin-cli getutxosetinfo` every 10 000 blocks, any corrupt snapshot would be soon detected. We plan to make expose the hash via `BTCPayServer` and make it easy for people to share.

### Why you don't just: Make BTCPayServer rely on SPV

All SPV solution brings a systemic risk to Bitcoin. If everybody relies on SPV to accept payment and miners want to change consensus rules, then you will have no leverage as individual, nor as a community to decide against.

Even with `UTXO Set snapshots` you continue to validate consensus rules from the block of the snapshot.

### Why you don't just: Make BTCPayServer rely on an external trusted node

Why not just hosting BTCPayServer on the raspberry pi, but the bitcoin full node on another machine?

For two reasons:

First, `BTCPayServer` is trying to bring down the technical barriers to operate payments on your own. Running on an external node means that the user need the technical skills to set it up.

`BTCPayServer` also relies on Bitcoin's RPC which is not meant to be exposed on internet. We can't see any simple enough solution which would allow normal people to run an external node somewhere else.

The second reason is about reliability: You want your service to be self contained. If you host a node on another server, and for some reason this server goes down, then your `BTCPayServer` hosted on the raspberry PI will also cease to function.
