# This is a manifest image, will pull the image with the same arch as the builder machine
FROM microsoft/dotnet:2.1.500-sdk AS builder
WORKDIR /source
COPY src/docker-compose-generator.csproj docker-compose-generator.csproj
# Cache some dependencies
RUN dotnet restore
COPY src/. .
RUN dotnet publish --output /app/ --configuration Release

# Force the builder machine to take make an arm runtime image. This is fine as long as the builder does not run any program
FROM microsoft/dotnet:2.1.6-aspnetcore-runtime-stretch-slim-arm32v7
WORKDIR /datadir

WORKDIR /app
ENV APP_DATADIR=/datadir
VOLUME /datadir

ENV INSIDE_CONTAINER=1

COPY --from=builder "/app" .

ENTRYPOINT ["dotnet", "docker-compose-generator.dll"]
