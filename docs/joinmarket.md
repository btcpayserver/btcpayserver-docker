# Joinmarket support

JoinMarket is software to create a special kind of bitcoin transaction called a CoinJoin transaction. Its aim is to improve the confidentiality and privacy of bitcoin transactions.

You will be able to use your bitcoin to help other protect their privacy, while earning a yield for this service.

See [the documentation of the joinmarket project](https://github.com/JoinMarket-Org/JoinMarket-Docs/blob/master/High-level-design.md) for more details.

This is a very advanced functionality, and there is no easy way to recover if something goes wrong.

For hardcore bitcoiners only.

## How to use

```bash
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-joinmarket"
. btcpay-setup.sh -i
```

Then you need to setup your joinmarket wallet:

```bash
jm.sh wallet-tool-generate
jm.sh set-wallet <wallet_file_name> <password>
```

Once done, you will need to send some money to the joinmarket wallet:

```bash
jm.sh wallet-tool
```

## How to fine tune?

In the [README](../README.md), follow the instruction in `How can I customize the generated docker-compose file?`.
Then pass as environment variable the attribute you want to modify, prefixed by `jm_`.

Our system is using the default configuration of joinmarket, then replace the values your specify like this.

Example:

```yml
services:
  joinmarket:
    environment:
      jm_gaplimit: 3000
      jm_txfee: 300
      jm_cjfee_a: 500
```

## Managing your wallet

By running `jm.sh` without parameter, you will get a bunch of command that you can run such as:

For example:
```
Usage:
------

Tooling to setup your joinmarket yield generator

    exec: Run the specified joinmarket script
    wallet-tool: Run wallet-tools.py on the wallet
    wallet-tool-generate: Generate a new wallet
    set-wallet: Set the wallet that the yield generator need to use
    logs: See logs of the yield generator (add -f to follow the logs)
    bash: Open an interactive bash session in the joinmarket container
    receive-payjoin: Receive a payjoin payment (this will stop the yield generator until the payment is received)
    sendpayment: Send a payjoin through coinjoin (password needed, this will stop the yield generator until the payment is received)
    start: Start the yield generator (started by default)
    stop: Stop the yield generator

Example:
    * jm.sh wallet-tool-generate
    * jm.sh set-wallet wallet.jmdat mypassword
    * jm.sh wallet-tool
    * jm.sh receive-payjoin
    * jm.sh sendpayment <address> <amount>
    * jm.sh wallet-tool history
    * jm.sh logs -f
    * jm.sh bash
    * jm.sh start
    * jm.sh stop
```

Note `jm.sh` commands are wrapper around joinmarket scripts. Those wrapper makes your life easier by:
1. Avoiding, when it can, that you enter wallet file name/ wallet password
2. Stop and Start the yield generator for the duration of the operation

In some cases you might want to get access to the raw scripts of joinmarket, in which case, you need to get the command prompt into the container.

## Getting command prompt into the container

You can connect to the container and have direct access to joinmarket scripts such as:

```bash
jm.sh bash
sendpayment.py wallet.jmdat ...
```

However, you might get the following error:

```
Failed to load wallet, error message: RetryableStorageError('File is currently in use (locked by pid 12822). If this is a leftover from a crashed instance you need to remove the lock file `/root/.joinmarket/wallets/.wallet.jmdat.lock` manually.')
```

This is because the yield generator is running.

You can stop and start the yield generator with the helper scripts in the container `stop.sh` and `start.sh`.


## Troubleshooting

Run `jm.sh logs` to get the logs of the yield generator.

A common issue is that a lock file is present, preventing it to restart.
In which case, connect directly into the container with `jm.sh bash` and delete the problematic file.