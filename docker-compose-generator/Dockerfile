FROM microsoft/aspnetcore-build:2.0.6-2.1.101-stretch AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release

FROM microsoft/aspnetcore:2.0.6-stretch
WORKDIR /app

RUN mkdir /datadir
ENV APP_DATADIR=/datadir
VOLUME /datadir

COPY --from=builder "/app" .
COPY docker-fragments docker-fragments

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
