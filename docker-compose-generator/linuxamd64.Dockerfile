#
FROM mcr.microsoft.com/dotnet/sdk:6.0.401-bullseye-slim AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release

#
FROM mcr.microsoft.com/dotnet/runtime:6.0.9-bullseye-slim
LABEL org.btcpayserver.image=docker-compose-generator
WORKDIR /datadir
WORKDIR /app
ENV APP_DATADIR=/datadir
VOLUME /datadir

ENV INSIDE_CONTAINER=1

COPY --from=builder "/app" .

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
