# DockerFile build helper

This helper updates the image inventory in
[`docs/supported-images.md`](../../docs/supported-images.md). It discovers images
from the Compose fragments, maps them to their source repositories and
architecture-specific Dockerfiles, and validates the Dockerfile links.

## How to use?

From this directory, install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and run:

```bash
./update-repo.sh
```

Or, from the repository root, use Docker:

```bash
docker run --rm \
  -v "$PWD:/project" \
  -w /project/contrib/DockerFileBuildHelper \
  mcr.microsoft.com/dotnet/sdk:10.0 \
  ./update-repo.sh
```

This updates only the supported-image table; it does not build container images.
