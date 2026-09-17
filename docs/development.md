# Development

The Docker Compose generator is a .NET application under
`docker-compose-generator/`. It reads cryptocurrency definitions and YAML
fragments, resolves their metadata, and writes the generated Compose stack,
manifest, and image scripts.

## Build the Generator Locally

For image-only development, build the generator directly from the repository
root:

```bash
docker build \
  -t btcpayserver/docker-compose-generator:local \
  docker-compose-generator
```

This avoids the generated-file and secret changes performed by `build.sh`.

For direct .NET development:

```bash
dotnet build docker-compose-generator/src/docker-compose-generator.csproj
```

## Add a Fragment

Checked-in fragments define supported deployment features. For a private
deployment override, create a `.custom.yml` fragment as described in
[Customization](./customization.md) instead.

### Choose a Name and Model

Create the fragment in `docker-compose-generator/docker-fragments/` using a
lowercase, kebab-case filename. Existing naming conventions are:

- `opt-add-<product>.yml` for an optional application or service
- `opt-<feature>.yml` for an optional behavior or tuning change
- `<chain>.yml` and `<chain>-<lightning>.yml` for cryptocurrency integrations

Use a nearby fragment with similar behavior as the starting point. Useful
examples include `bitcoin.yml` for a chain and service overlays,
`bitcoin-lnd.yml` for Lightning and route metadata, `opt-add-mempool.yml` for a
multi-service application, and `opt-save-storage.yml` for a tuning overlay.

Each generated service must have exactly one selected fragment that defines its
`image`. Other fragments can extend that service without repeating the image.
The generator uses a shallow merge rather than Docker Compose's multi-file
merge behavior:

- New service properties and mapping entries are added.
- Sequence entries such as volumes, ports, and dependencies are appended.
- Repeated scalar mapping entries are appended with a comma or newline.
- Scalar service properties such as `command`, `restart`, and `image` cannot be
  reliably replaced.
- Nested mappings are not recursively merged, and merge order is not stable.

Do not design a fragment that depends on replacing an existing value or on
fragment processing order. Inspect the generated Compose file to confirm the
result.

For a new service:

- Pin a versioned image and verify its supported architectures.
- Prefer internal `expose` entries. Use `ports` only for intentional host
  exposure, binding administrative endpoints to loopback where possible.
- Store durable state in a declared, product-specific named volume.
- Reference other containers by Compose service name.
- Use environment substitution for operator-provided values; never commit
  credentials.
- Add Compose secrets when the service needs a generated credential. Secret
  file paths must be relative paths below `../secrets/`.

### Declare Relationships

Fragments can use these generator-specific top-level sequences:

| Key | Meaning |
|---|---|
| `required` | Recursively select dependencies that operators cannot exclude. |
| `recommended` | Recursively select defaults unless explicitly excluded. |
| `excluded` | Suppress recommended fragments that conflict with this fragment. |
| `exclusive` | Claim a named group in which only one selected fragment is allowed. |
| `incompatible` | Reject the fragment when a selected fragment claims the named exclusive group. |
| `required-routes` | Enable Nginx route aliases whenever the fragment is selected. |
| `optional-routes` | Make route aliases available through `btcpay-routes add` and `remove`. |

Values in `required`, `recommended`, and `excluded` are fragment basenames
without the `.yml` suffix. Values in `exclusive` and `incompatible` are group
names such as `lightning`, `proxy`, or `pruning`; they are not fragment
filenames. Use `required` only for functionality without which the fragment
cannot work. Use `recommended` for a safe default that an operator may
reasonably disable. Use `excluded` when selecting the fragment makes a
recommended fragment invalid; exclusions cannot override explicit or required
selections.

When exposing an HTTP or API endpoint through bundled Nginx, add its snippet to
`nginx/routes/<alias>.conf` and declare the lowercase, hyphenated alias as
required or optional. Route snippets are included inside the BTCPay virtual
host's `server` context, so keep related `location` blocks together and do not
add `http`, `server`, or `upstream` blocks. Do not add service route blocks
directly to `nginx/nginx.tmpl`.

### Complete the Integration

Add optional fragments to the appropriate table in [Optional
Fragments](./fragments.md). Add a dedicated guide when operators need to
configure credentials, DNS, hostnames, backups, security boundaries, or an
external service.

Every image reference is also consumed by `contrib/DockerFileBuildHelper`.
Follow [Generated Image Documentation](#generated-image-documentation) when an
image changes.

Cryptocurrency fragments additionally require the integration steps under [Add
a Cryptocurrency](#add-a-cryptocurrency).

### Validate the Fragment

Generate a representative composition in a temporary directory so validation
does not alter an installed stack. Set `FRAGMENT` to the new basename and adjust
the selected cryptocurrency or Lightning implementation when required:

```bash
FRAGMENT="opt-add-example"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -a docker-compose-generator "$TMP_DIR/"
mkdir "$TMP_DIR/Generated"

(
  cd "$TMP_DIR/docker-compose-generator"
  BTCPAYGEN_CRYPTO1="btc" \
  BTCPAYGEN_REVERSEPROXY="nginx" \
  BTCPAYGEN_LIGHTNING="none" \
  BTCPAYGEN_ADDITIONAL_FRAGMENTS="$FRAGMENT" \
  dotnet run --project src/docker-compose-generator.csproj \
    --configuration Release --no-launch-profile
)

BTCPAY_HOST="example.com" \
BTCPAY_ADDITIONAL_HOSTS="" \
docker compose \
  -f "$TMP_DIR/Generated/docker-compose.generated.yml" \
  config --quiet
jq --arg fragment "$FRAGMENT" \
  -e '.fragments | index($fragment) != null' \
  "$TMP_DIR/Generated/manifest.json"
```

This generates and parses Compose configuration but does not start services.
Review the generated service, volume, network, secret, and route entries. Test
required, excluded, and incompatible selections when the fragment declares
those relationships.

Run focused repository tests for any scripts, routes, templates, or secret
handling changed by the integration. Add a regression test when Compose parsing
does not cover the behavior. Use `.github/workflows/ci.yml` and `AGENTS.md` for
the current validation commands, and finish with `git diff --check`.

## Add a Cryptocurrency

Adding a chain requires coordinated support across the stack, for Bitcoin-based crypto-currencies:

1. Add or verify chain support in NBitcoin, NBXplorer, and BTCPay Server.
2. Provide maintained, reproducible container images for the required daemon
   and supporting services.
3. Add the Compose fragments for the node, NBXplorer configuration, volumes,
   and optional Lightning implementation.
4. Add the chain to
   [`docker-compose-generator/crypto-definitions.json`](../docker-compose-generator/crypto-definitions.json).
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
