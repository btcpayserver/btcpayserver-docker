# This script will run docker-compose-generator in a container to generate the yml files

docker pull btcpayserver/docker-compose-generator
docker run -v "$(Get-Location)\Production:/app/Production" `
           -v "$(Get-Location)\Production-NoReverseProxy:/app/Production-NoReverseProxy" `
           -v "$(Get-Location)\docker-compose-generator\docker-fragments:/app/docker-fragments" `
           --rm btcpayserver/docker-compose-generator pregen