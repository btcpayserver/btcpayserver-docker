## Interactive script to manage BTCPAYGEN_ADDITIONAL_FRAGMENTS in Docker setup ##

The tool:
1. Shows the current active additional fragments for the BTCpay Docker (take the command from here https://docs.btcpayserver.org/FAQ/Deployment/#how-can-i-modify-or-deactivate-environment-variables)
2. Asks the user what they want to do between:
   <br>a. Exports the BTCPAYGEN_ADDITIONAL_FRAGMENTS variable without the ones active
   <br>b. Enables one or more fragments in addition to the existing environment variables by choosing from the list of available fragments
   <br>c. Disables one or more fragments from the list of the current active additional fragments
   <br>d. Cancels and does nothing.

4. Asks the user to confirm
5. Runs btcpay-setup.sh
