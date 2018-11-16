FROM microsoft/dotnet:2.1.500-sdk-alpine3.7 AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release

FROM microsoft/dotnet:2.1.6-runtime-alpine3.7
WORKDIR /app

RUN mkdir /datadir
ENV APP_DATADIR=/datadir
VOLUME /datadir

ENV INSIDE_CONTAINER=1

COPY --from=builder "/app" .

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
