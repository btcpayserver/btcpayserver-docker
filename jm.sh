#!/bin/bash

function display_help () {
cat <<-END
Usage:
------

Tooling to setup your joinmarket yield generator

    wallet-tool: Run wallet-tools.py on the wallet
    wallet-tool-generate: Generate a new wallet
    set-wallet: Set the wallet that the yield generator need to use
    bash: Open an interactive bash session in the joinmarket container
    receive-payjoin: Receive a payjoin payment
    sendpayment: Send a payjoin through coinjoin (password needed)
    reset-config: Reset the configuration to its default value

Example:
    * jm.sh wallet-tool-generate
    * jm.sh set-wallet wallet.jmdat mypassword
    * jm.sh wallet-tool
    * jm.sh receive-payjoin <amount>
    * jm.sh sendpayment <amount> <address>
    * jm.sh wallet-tool history
    * jm.sh reset-config
    * jm.sh bash

See https://github.com/btcpayserver/btcpayserver-docker/tree/master/docs/joinmarket.md for more information.
END
}

while (( "$#" )); do
  case "$1" in
    bash)
      CMD="$1"
      shift 1
      break;
      ;;
    reset-config)
      CMD="$1"
      shift 1
      break;
      ;;
    wallet-tool)
      CMD="$1"
      shift 1
      break;
      ;;
    set-wallet)
      CMD="$1"
      shift 1
      break;
      ;;
    receive-payjoin)
      CMD="$1"
      shift 1
      break;
      ;;
    sendpayment)
      CMD="$1"
      shift 1
      break;
      ;;
    wallet-tool-generate)
      CMD="$1"
      shift 1
      break;
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      display_help
      return
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

if ! [[ "$CMD" ]]; then
    display_help
else
    if [[ "$CMD" == "wallet-tool" ]]; then
        docker exec joinmarket exec-wrapper.sh unlockwallet wallet-tool.py "$@"
    elif [[ "$CMD" == "wallet-tool-generate" ]]; then
        docker exec -ti joinmarket exec-wrapper.sh wallet-tool.py generate "$@"
    elif [[ "$CMD" == "sendpayment" ]]; then
        docker exec -ti joinmarket exec-wrapper.sh unlockwallet nopass sendpayment.py "$@"
    elif [[ "$CMD" == "receive-payjoin" ]]; then
        docker exec -ti joinmarket exec-wrapper.sh unlockwallet receive-payjoin.py "$@"
    elif [[ "$CMD" == "set-wallet" ]]; then
        docker exec joinmarket set-wallet.sh "$@"
        docker restart joinmarket
    elif [[ "$CMD" == "reset-config" ]]; then
        docker exec -ti joinmarket bash -c 'rm -f "$CONFIG"'
        docker restart joinmarket
    elif [[ "$CMD" == "bash" ]]; then
        docker exec -ti joinmarket exec-wrapper.sh bash "$@"
    else
        display_help
    fi
fi
