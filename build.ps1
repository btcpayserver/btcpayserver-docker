# This script will run docker-compose-generator in a container to generate the yml files

If (-not ($BTCPAYGEN_DOCKER_IMAGE)) { $BTCPAYGEN_DOCKER_IMAGE = "btcpayserver/docker-compose-generator" }

If ($BTCPAYGEN_DOCKER_IMAGE -eq "btcpayserver/docker-compose-generator:local"){
	docker build docker-compose-generator -f docker-compose-generator/linuxamd64.Dockerfile --tag $BTCPAYGEN_DOCKER_IMAGE
} Else {
	docker pull $BTCPAYGEN_DOCKER_IMAGE
}

docker run -v "$(Get-Location)\Generated:/app/Generated" `
           -v "$(Get-Location)\docker-compose-generator\docker-fragments:/app/docker-fragments" `
           -v "$(Get-Location)\docker-compose-generator\crypto-definitions.json:/app/crypto-definitions.json" `
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
           -e "BTCPAYGEN_ADDITIONAL_FRAGMENTS=$BTCPAYGEN_ADDITIONAL_FRAGMENTS" `
           -e "BTCPAYGEN_EXCLUDE_FRAGMENTS=$BTCPAYGEN_EXCLUDE_FRAGMENTS" `
           -e "BTCPAYGEN_LIGHTNING=$BTCPAYGEN_LIGHTNING" `
           -e "BTCPAYGEN_SUBNAME=$BTCPAYGEN_SUBNAME" `
           -e "BTCPAY_HOST_SSHAUTHORIZEDKEYS=$BTCPAY_HOST_SSHAUTHORIZEDKEYS" `
           --rm $BTCPAYGEN_DOCKER_IMAGE

If ($BTCPAYGEN_REVERSEPROXY -eq "nginx") {
    Copy-Item ".\Production\nginx.tmpl" -Destination ".\Generated"
}

If ($BTCPAYGEN_REVERSEPROXY -eq "traefik") {
    Copy-Item ".\Traefik\traefik.toml" -Destination ".\Generated"
    
    New-Item  ".\Generated\acme.json" -type file
}
