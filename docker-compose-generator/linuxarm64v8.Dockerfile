# This is a manifest image, will pull the image with the same arch as the builder machine
FROM mcr.microsoft.com/dotnet/core/sdk:3.0.100-preview7 AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore /p:TargetFrameworkOverride=netcoreapp3.0
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release /p:TargetFrameworkOverride=netcoreapp3.0

# Force the builder machine to take make an arm runtime image. This is fine as long as the builder does not run any program
FROM mcr.microsoft.com/dotnet/core/runtime:3.0.0-preview7-buster-slim-arm64v8
LABEL org.btcpayserver.image=docker-compose-generator
WORKDIR /datadir

WORKDIR /app
ENV APP_DATADIR=/datadir
VOLUME /datadir

ENV INSIDE_CONTAINER=1

COPY --from=builder "/app" .

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
