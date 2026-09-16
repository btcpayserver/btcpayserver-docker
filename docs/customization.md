# Customization

The generated Compose file is assembled from fragments. Do not edit
`Generated/docker-compose.generated.yml` directly; setup and updates overwrite
it.

## Create a Custom Fragment

Custom fragment filenames should end in `.custom.yml`. That suffix is ignored
by Git, avoiding conflicts during updates.

For example, copy the 100 GB pruning profile:

```bash
cp docker-compose-generator/docker-fragments/opt-save-storage.yml \
  docker-compose-generator/docker-fragments/opt-save-storage.custom.yml
```

Edit the custom file, then select its basename:

```bash
btcpay-fragments add opt-save-storage.custom
```

The command preserves other selected fragments. Remove the custom fragment with:

```bash
btcpay-fragments remove opt-save-storage.custom
```

## Fragment Metadata

Fragments can declare:

- `required`: recursively selected dependencies that cannot be excluded
- `recommended`: recursively selected defaults that can be excluded
- `excluded`: recommended fragments suppressed while this fragment is selected
- `exclusive`: alternatives that cannot be selected together
- `incompatible`: conflicts with an exclusive group
- `required-routes` and `optional-routes`: Nginx route declarations

Use existing fragments as examples and validate the resulting Compose file.

## Generate Without Installing

Set the complete generator selection and run `build.sh` from the repository
root:

```bash
BTCPAYGEN_CRYPTO1="btc" \
BTCPAYGEN_REVERSEPROXY="nginx" \
BTCPAYGEN_LIGHTNING="none" \
./build.sh
```

Unlike `btcpay-setup.sh`, direct `build.sh` use does not apply the setup
defaults. Specify every selection you need. The output is
`Generated/docker-compose.generated.yml`; operate it explicitly with Docker
Compose and provide its runtime environment.

## Existing Reverse Proxy

For a standard installation behind an external reverse proxy, prefer the
documented setup path in [Networking](./networking.md#external-reverse-proxy)
instead of manually operating a custom generated stack.
