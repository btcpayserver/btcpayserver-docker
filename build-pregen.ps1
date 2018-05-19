# This script will run docker-compose-generator in a container to generate the yml files

docker pull btcpayserver/docker-compose-generator
docker run -v "$(Get-Location)\Production:/app/Production" -v "$(Get-Location)\Production-NoReverseProxy:/app/Production-NoReverseProxy" --rm btcpayserver/docker-compose-generator pregen