---
name: vps-deployment
description: Guide an operator through planning, installing, verifying, reconfiguring, updating, migrating, restoring, or troubleshooting BTCPay Server on a VPS with the official Docker deployment. Use for operator-side VPS work, production deployment choices, domain and HTTPS preparation, synchronization, and deployment-readiness questions.
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
- When the VPS already exists, begin installation, reconfiguration, update,
  migration, restore, or troubleshooting by asking only for the SSH host target
  and connect to `root@<server-hostname>` using existing SSH configuration and
  keys. Never request a password or private key. Discover host facts with
  read-only commands instead of front-loading a questionnaire.
- Work in phases: discovery, preflight, plan approval, installation,
  verification, and production readiness. Complete and verify one phase before
  moving to the next.
- Assume the user is new. Explain each decision in practical terms, recommend a
  conservative default, and avoid presenting every advanced option at once.
- Never assume the current machine or shell is the intended VPS. Identify the
  target host and how commands will reach it before running anything.
- Do not claim success from a command exit alone. Verify the expected service,
  HTTPS, synchronization, and exposure outcomes.

## Select and Size a VPS

Before recommending a VPS, ask in one concise message which cryptocurrencies,
Lightning implementation, and resource-intensive add-ons it must support. Do
not assume Bitcoin-only. For multiple chains, read `docs/cryptocurrencies.md`
and their definitions before sizing.

For ordinary Bitcoin-only deployments, prefer a low-cost VPS with 4 GB RAM and
`opt-save-storage-xs`. Size usable storage as the pruning target plus 20 GB:
approximately 45 GB for this 25 GB profile, rounded up to the next plan size.
Do not recommend 8 GB RAM or a 160 GB SSD without a concrete need.

If local SSD storage is expensive, offer a provider-attached non-SSD volume for
Bitcoin Core's `blocks` directory. Keep the OS, Docker, chainstate, and databases
on the root SSD; budget the pruning target on the attached volume and 20 GB on
the root disk. Confirm persistence, mount ordering, and ownership. When configure
it, make sure mounts are mounted before docker starts.

## Access and Discover

Read `README.md` and `docs/installation.md`, then use read-only checks to find:

1. The Linux distribution, architecture, memory, storage, and whether the VPS
   appears fresh and dedicated.
2. The available privilege level and any existing Docker workloads, web
   servers, listeners, deployment files, or BTCPay installation.
3. Public IP addresses, hostname and DNS evidence available from the host,
   firewall state visible on the VPS, and the apparent ingress model.
4. Existing BTCPay network, chain, pruning, Lightning, add-on, exposed-port,
   storage-mount, and update configuration when present. Do not read or display
   secret values.

After inspection, ask once for only the decisions needed next and not available
from the host or prior context, offering conservative defaults. If SSH access
is unavailable, use one concise fallback questionnaire.

Recommend starting without Lightning unless the user understands liquidity
management and its backup constraints. Do not enable optional services
preemptively.

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
- The selected cryptocurrencies and the resource assumptions used to size them.
- The exact non-secret environment values that will be applied.
- Expected DNS, firewall, public ports, pruning profile, root and attached
  storage layout, and Lightning exposure.
- Host changes described in `docs/installation.md#what-setup-changes`.
- Expected downtime or conflicts.

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
- Record the approved non-secret profile, DNS and firewall assumptions, and routine verification commands for the operator.

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
