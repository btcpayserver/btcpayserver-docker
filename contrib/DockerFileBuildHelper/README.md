# DockerFile build helper

By default, the Docker deployment fetches prebuilt images from container
registries. This makes deployment fast and reliable but requires trusting the
image publishers. This helper generates a script for building supported images
from source.

## How to use?

From this directory, install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and run:

```bash
./run.sh
```

Or, from the repository root, use Docker:

```bash
docker run --rm \
  -v "$PWD:/project" \
  -w /project/contrib/DockerFileBuildHelper \
  mcr.microsoft.com/dotnet/sdk:10.0 \
  ./run.sh
```

`run.sh` generates a local `build-all.sh` file in this directory, which you can
run to build the images from source. It does not update the generated artifacts
checked into the repository.

To update the checked-in `contrib/build-all-images.sh` script and supported-image
table, run `./update-repo.sh` instead. The generated table is stored in
[`docs/supported-images.md`](../../docs/supported-images.md).
