# This script will run docker-compose-generator in a container to generate the yml files

docker pull btcpayserver/docker-compose-generator
docker run -v "$(Get-Location)\Generated:/app/Generated" `
           -v "$(Get-Location)\docker-compose-generator\docker-fragments:/app/docker-fragments" `
           -e "BTCPAYGEN_CRYPTO1=$BTCPAYGEN_CRYPTO1" `
           -e "BTCPAYGEN_CRYPTO2=$BTCPAYGEN_CRYPTO2" `
           -e "BTCPAYGEN_CRYPTO3=$BTCPAYGEN_CRYPTO3" `
           -e "BTCPAYGEN_CRYPTO4=$BTCPAYGEN_CRYPTO4" `
           -e "BTCPAYGEN_CRYPTO5=$BTCPAYGEN_CRYPTO5" `
           -e "BTCPAYGEN_CRYPTO6=$BTCPAYGEN_CRYPTO6" `
           -e "BTCPAYGEN_CRYPTO7=$BTCPAYGEN_CRYPTO7" `
           -e "BTCPAYGEN_CRYPTO8=$BTCPAYGEN_CRYPTO8" `
           -e "BTCPAYGEN_CRYPTO9=$BTCPAYGEN_CRYPTO9" `
           -e "BTCPAYGEN_REVERSEPROXY=$BTCPAYGEN_REVERSEPROXY" `
           -e "BTCPAYGEN_LIGHTNING=$BTCPAYGEN_LIGHTNING" `
           -e "BTCPAYGEN_SUBNAME=$BTCPAYGEN_SUBNAME" `
           --rm btcpayserver/docker-compose-generator

If ($BTCPAYGEN_REVERSEPROXY -eq "nginx") {
    Copy-Item ".\Production\nginx.tmpl" -Destination ".\Generated"
}
