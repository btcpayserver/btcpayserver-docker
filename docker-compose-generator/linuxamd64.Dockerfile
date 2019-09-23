#
FROM mcr.microsoft.com/dotnet/core/sdk:2.1.505-alpine3.7 AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release

#
FROM mcr.microsoft.com/dotnet/core/runtime:2.1.9-alpine3.7
LABEL org.btcpayserver.image=docker-compose-generator
WORKDIR /datadir
WORKDIR /app
ENV APP_DATADIR=/datadir
VOLUME /datadir

ENV INSIDE_CONTAINER=1

COPY --from=builder "/app" .

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
