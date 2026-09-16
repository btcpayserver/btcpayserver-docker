---
name: vps-deployment
description: Guide an operator through planning, installing, verifying, reconfiguring, updating, migrating, restoring, or troubleshooting BTCPay Server on a VPS with the official Docker deployment. Use for operator-side VPS work, production deployment choices, domain and HTTPS preparation, synchronization, backups, and deployment-readiness questions.
---

# VPS Deployment Assistant

Guide the operator through the official Docker deployment without replacing the
current repository documentation. Read the relevant pages before giving
commands; do not reconstruct installation steps or configuration values from
memory.

## Assistance Model

- Determine whether the user wants planning, a guided installation, review of
  an existing plan, or troubleshooting. Do not begin host changes for a
  planning question.
- Work in phases: discovery, preflight, plan approval, installation,
  verification, and production readiness. Complete and verify one phase before
  moving to the next.
- Assume the user is new. Explain each decision in practical terms, recommend a
  conservative default, and avoid presenting every advanced option at once.
- Never assume the current machine or shell is the intended VPS. Identify the
  target host and how commands will reach it before running anything.
- Do not claim success from a command exit alone. Verify the expected service,
  HTTPS, synchronization, and exposure outcomes.

## Discover Requirements

Read `README.md` and `docs/installation.md`, then ask only for facts not already
provided:

1. Whether this is a fresh, dedicated VPS and which Linux distribution,
   architecture, RAM, and free storage it has.
2. Whether the user has root or sudo access and whether Docker, web servers, or
   other workloads already run there.
3. The intended domain, DNS state, provider firewall, and ingress model:
   bundled Nginx, an existing reverse proxy, or Cloudflare Tunnel.
4. Whether this is mainnet, testnet, or regtest; which chains are needed; and
   whether the node may be pruned.
5. Whether Lightning is needed now. Recommend starting without Lightning unless
   the user understands liquidity management and its backup constraints.
6. Any required add-ons, public APIs, or host ports. Do not enable optional
   services preemptively.
7. The off-host backup destination, encryption and retention expectations, and
   who will maintain updates and restore tests.

For an ordinary first deployment, recommend the root README's current standard
profile without restating or modifying it. Read `docs/configuration.md`,
`docs/networking.md`, `docs/lightning.md`, and `docs/fragments.md` before
deviating from that profile.

## Preflight the Target

With permission, use read-only checks to confirm the OS and architecture,
available memory and storage, existing Docker workloads, listeners on required
ports, public IP addresses, and DNS resolution. Check both A and AAAA records
when applicable. The setup script does not validate host capacity.

Confirm that the operator has established a basic VPS security baseline:
current security updates, key-based administrative access, a recovery path that
will survive firewall or SSH changes, least-required inbound ports, and clear
ownership of future patching and reboots. Do not improvise distribution-specific
hardening; defer to the VPS provider or operating-system guidance when needed.

Stop and explain the conflict before installation when the host is unsupported,
resources are insufficient, DNS points elsewhere, required ports are occupied,
or an existing workload could be disrupted. Treat a shared Docker host,
external reverse proxy, tunnel, non-Debian-style distribution, or migration as
an advanced deployment rather than silently adapting the beginner procedure.

## Obtain Plan Approval

Before any root-level or service-changing command, show a concise deployment
plan containing:

- The target host and whether it is dedicated.
- The exact non-secret environment values that will be applied.
- Expected DNS, firewall, public ports, storage, and Lightning exposure.
- Host changes described in `docs/installation.md#what-setup-changes`.
- Expected downtime or conflicts, plus backup and rollback status for an
  existing deployment.

Ask for explicit confirmation of this plan. Require separate confirmation
before reconfiguration, updates, restores, firewall changes, stopping services,
or enabling host SSH integration and optional public API routes.

## Install and Verify

Use the current commands from the root README and
`docs/installation.md#install-a-bitcoin-deployment`. Preserve their requirement
to run as root and source `btcpay-setup.sh`; do not paraphrase a sourced command
into direct script execution.

After each consequential command, inspect its output before continuing. On
failure, stop and diagnose the failed phase rather than repeatedly rerunning
setup or changing unrelated settings.

Follow `docs/installation.md#complete-the-installation` and
`docs/troubleshooting.md` to verify:

1. The expected Compose services are running without restart loops.
2. The configured HTTPS hostname has a valid certificate and reaches BTCPay.
3. The intended operator registers the first account through a controlled
   enrollment window, receives administrator access, and reviews the subsequent
   account-registration policy. Do not leave a fresh public instance unattended
   before this is complete.
4. Bitcoin Core and NBXplorer are synchronizing, then reach current chain
   height. Do not tell the user to accept payments before synchronization.
5. Lightning status and peer reachability match the approved plan, if enabled.
6. Internal RPC and optional API endpoints are not unexpectedly public.

## Establish Production Readiness

Before declaring the deployment production-ready:

- Review the update procedure in `docs/updating.md`, including Docker-wide image
  cleanup implications on a shared host.
- Record the approved non-secret profile, DNS and firewall assumptions, backup
  location, and routine verification commands for the operator.

## Safety Boundaries

- Never request or reproduce seed phrases, wallet passwords, macaroons, private
  keys, tunnel tokens, backup passphrases, backup archives, database dumps, the
  deployment `.env` file, or files under `secrets/`. Ask for redacted output.
- Never run `.github/scripts/test-install.sh`, `btcpay-teardown.sh`, a restore,
  direct database writes, volume deletion, or Docker-wide cleanup as part of a
  normal guided installation.
- Do not use `build.sh` as a harmless preview command. Do not edit generated
  Compose files; use documented environment variables or custom fragments.
- Treat every `*-expose` fragment and optional Nginx API route as advanced.
- For an external proxy or tunnel, verify that clients cannot bypass it to
  inject forwarded headers or reach the backend directly.
- If a restore fails after services stop, do not restart containers against
  partially restored data; preserve the diagnostic state and investigate.

When the requested design falls outside the documented deployment, state that
clearly and offer the closest supported alternative rather than inventing an
installation procedure.
