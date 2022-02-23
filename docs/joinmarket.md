# Joinmarket support

JoinMarket is software to create a special kind of bitcoin transaction called a CoinJoin transaction. Its aim is to improve the confidentiality and privacy of bitcoin transactions.

You will be able to use your bitcoin to help other protect their privacy, while earning a yield for this service.

See [the documentation of the joinmarket project](https://github.com/JoinMarket-Org/JoinMarket-Docs/blob/master/High-level-design.md) for more details.

This is a very advanced functionality, and there is no easy way to recover if something goes wrong.

For hardcore bitcoiners only.

## How to use

```bash
export JOINMARKET_WEBUI_USER="joinmarket"
export JOINMARKET_WEBUI_PASSWD="sUpErSeCrEt"
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-joinmarket"
. btcpay-setup.sh -i
```

Then you need to setup your default joinmarket wallet:

```bash
jm.sh wallet-tool-generate
jm.sh set-wallet <wallet_file_name> <password>
```

Once done, you will need to send some money to the joinmarket wallet:

```bash
jm.sh wallet-tool
```

## How to change joinmarket configuration?

Connect to your container, and edit your configuration:

```bash
jm.sh bash
vim $CONFIG
```

## Managing your wallet

By running `jm.sh` without parameter, you will get a bunch of command that you can run such as:

```
Usage:
------

Tooling to setup your joinmarket yield generator

    wallet-tool: Run wallet-tools.py on the wallet
    wallet-tool-generate: Generate a new wallet
    set-wallet: Set the wallet that the yield generator need to use
    bash: Open an interactive bash session in the joinmarket container
    receive-payjoin: Receive a payjoin payment
    sendpayment: Send a payjoin through coinjoin (password needed)

Example:
    * jm.sh wallet-tool-generate
    * jm.sh set-wallet wallet.jmdat mypassword
    * jm.sh wallet-tool
    * jm.sh receive-payjoin <amount>
    * jm.sh sendpayment <amount> <address>
    * jm.sh wallet-tool history
    * jm.sh bash
```

Note `jm.sh` commands are wrapper around joinmarket scripts. Those are just convenience command, you can always directly connect to the container via `jm.sh bash` and achieve the same result with the joinmarket python scripts.

## Getting command prompt into the container

You can connect to the container and have direct access to joinmarket scripts such as:

```bash
jm.sh bash
sendpayment.py wallet.jmdat ...
```

## Managing the services such as yield generators

First connect to the container:

```bash
jm.sh bash
```

You can list available services to run:

```bash
supervisorctl status
```

Which might show you

```bash
root> supervisorctl status
jmwalletd                        RUNNING   pid 55, uptime 0:00:21
ob-watcher                       RUNNING   pid 43, uptime 0:00:21
yg-privacyenhanced               STOPPED   Not started
yield-generator-basic            STOPPED   Not started
```

You can start a yield generator with:

```bash
supervisorctl start yg-privacyenhanced
```

***Note that services will NOT be restarted automatically if the container restart.***

If you want to automatically restart the service when the container restart,

```bash
vim $AUTO_START
```

Then remove the comment `#` in front of the service name you want to automatically restart.

## OB-Watcher

You can browse the [order book](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/orderbook.md) by visiting `https://<your-server>/joinmarket/orderbook/`

## Troubleshooting

### Error: Failed to load wallet, you need to remove the lock file

You might sometimes get the following error when running a python script for joinmarket:

```
Failed to load wallet, error message: RetryableStorageError('File is currently in use (locked by pid 12822). If this is a leftover from a crashed instance you need to remove the lock file `/root/.joinmarket/wallets/.wallet.jmdat.lock` manually.')
```

This is because a service using the wallet is running, so you need to shut it down before running the command.

Check which service is running:

```bash
supervisorctl status
```

And stop it

```bash
supervisorctl stop yg-privacyenhanced
```

### Read the logs of services

You can use the `supervisorctl tail` command:

```bash
supervisorctl tail yg-privacyenhanced
```

You can also check the logs in the `$DATADIR/logs` folder.
