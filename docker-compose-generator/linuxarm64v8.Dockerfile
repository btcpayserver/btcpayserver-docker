# This is a manifest image, will pull the image with the same arch as the builder machine
FROM mcr.microsoft.com/dotnet/sdk:6.0.401-bullseye-slim AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release

# Force the builder machine to take make an arm runtime image. This is fine as long as the builder does not run any program
FROM mcr.microsoft.com/dotnet/runtime:6.0.9-bullseye-slim-arm64v8
LABEL org.btcpayserver.image=docker-compose-generator
WORKDIR /datadir

WORKDIR /app
ENV APP_DATADIR=/datadir
VOLUME /datadir

ENV INSIDE_CONTAINER=1

COPY --from=builder "/app" .

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
