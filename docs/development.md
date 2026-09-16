# Development

The Docker Compose generator is a .NET application under
`docker-compose-generator/`. It reads cryptocurrency definitions and YAML
fragments, resolves their metadata, and writes the generated Compose stack,
manifest, and image scripts.

## Build the Generator Locally

From the repository root:

```bash
export BTCPAYGEN_DOCKER_IMAGE="btcpayserver/docker-compose-generator:local"
./build.sh
```

The special `:local` image name makes `build.sh` build the generator Dockerfile
instead of pulling the published image.

For direct .NET development:

```bash
dotnet build docker-compose-generator/src/docker-compose-generator.csproj
```

## Add a Fragment

Create a YAML file under `docker-compose-generator/docker-fragments/`. Use
existing fragments to model service merges, volumes, dependencies, route
metadata, and compatibility rules.

Check the generated Compose output and add focused tests for behavior that is
not covered by ordinary Compose validation. New images must also be considered
by the source-build helper; see
[`contrib/DockerFileBuildHelper`](https://github.com/btcpayserver/btcpayserver-docker/tree/master/contrib/DockerFileBuildHelper).

## Add a Cryptocurrency

Adding a chain requires coordinated support across the stack:

1. Add or verify chain support in NBitcoin, NBXplorer, and BTCPay Server.
2. Provide maintained, reproducible container images for the required daemon
   and supporting services.
3. Add the Compose fragments for the node, NBXplorer configuration, volumes,
   and optional Lightning implementation.
4. Add the chain to
   [`docker-compose-generator/crypto-definitions.json`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/crypto-definitions.json).
5. Add source-build mappings for published images where verified source builds
   are available.
6. Test generation, startup, synchronization, payment detection, upgrades, and
   supported architectures.

Non-Bitcoin and non-Litecoin integrations are maintained by their respective
communities. A definition should not be added without maintainers able to test
and support it.

## Generated Image Documentation

`contrib/DockerFileBuildHelper` owns `contrib/build-all-images.sh` and the table
in `docs/supported-images.md`. Do not edit either generated section manually.
Follow the repository's `AGENTS.md` procedure when an image reference changes.

## Validation

Run the tests relevant to the changed scripts or fragments and finish with:

```bash
git diff --check
```

For image-helper changes, also run the generation and validation commands
documented in `AGENTS.md`.
