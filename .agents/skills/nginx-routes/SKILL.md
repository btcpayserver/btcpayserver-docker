---
name: nginx-routes
description: Maintain BTCPay Docker's Nginx route catalog and fragment metadata. Use when adding or changing nginx/routes/*.conf, required-routes, optional-routes, Generated/manifest.json, or btcpay-routes.
---

# Nginx Routes

Use this workflow whenever a change adds, removes, or modifies a managed route.

## Catalog Workflow

1. Identify the fragment that provides the route's backing service.
2. Choose a stable, friendly alias containing only lowercase letters, digits, and hyphens. Do not include `bitcoin` merely to identify the chain; use it only when it is literally part of the service or product name.
3. Add one flat file at `nginx/routes/<friendly-alias>.conf`. Do not create route subdirectories or use the Compose service name as the filename unless it is also the best friendly alias.
4. Add the alias to the fragment's top-level `required-routes` or `optional-routes` sequence. Required routes are always enabled when the fragment is selected. Optional routes can be changed with `btcpay-routes add` and `remove`.
5. A route provided by multiple alternative fragments may be declared by each fragment; the generated manifest deduplicates aliases. A route must never be both required and optional in one generated composition.

## Snippet Rules

- Write snippets for inclusion in the BTCPay virtual host's `server` context. Include only `location` blocks and directives valid for those location blocks; do not add `http`, `server`, or `upstream` blocks.
- Keep all locations belonging to one friendly route in the same file. Preserve companion regex, RPC, websocket, redirect, and nested locations together, in their required order and nesting. Do not split a previously grouped service condition into separate aliases unless users must be able to expose the pieces independently.
- Proxy to Compose service names. Preserve path trailing slashes, headers, rewrites, websocket upgrades, filters, timeouts, and access-denial locations when moving or changing an existing route.
- Do not restore per-service route blocks in `nginx/nginx.tmpl`; managed route behavior belongs in the catalog, and the template should consume `enabled-routes/*.conf` through its single include.

## Validation

`btcpay-routes add` performs `nginx -t` before reloading and restores the prior enabled-route set if validation fails. Test every changed alias, including all grouped paths handled by its snippet. Confirm required routes appear in `enabledRoutes`, optional routes appear in `optionalRoutes`, only optional routes accept `add` and `remove`, all output and errors are valid JSON, and optional selections survive regeneration and synchronization.
