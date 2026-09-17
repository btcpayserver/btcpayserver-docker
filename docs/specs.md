# Server Specifications

There is no single minimum server specification for every BTCPay Server
deployment. The required storage, memory, CPU, and bandwidth depend on the
selected chains, pruning profile, Lightning implementation, optional services,
and expected traffic.

Choose a dedicated Linux host that supports `x86_64`, `armv7l`, or `aarch64`
containers and provides root access. Debian or Ubuntu-style distributions are
the expected path for the automated installation.

## Basic Installation

A practical starting point for a small Bitcoin-only deployment without
resource-intensive add-ons is:

| Resource | Starting point |
|---|---:|
| Memory | 4 GB RAM |
| CPU | 2 virtual cores |
| Storage | 50 GB usable SSD storage as a bare minimum; choose a larger plan for headroom |
| Bandwidth | Enough for the initial full-chain download; unmetered preferred |

This profile uses Bitcoin with `opt-save-storage-xs`. The storage calculation is
explained below.

The storage components consume approximately 50 GB before image updates,
database growth, logs, and temporary maintenance space. Prefer the next larger
plan when the provider cannot expand storage without downtime.

Round the storage estimate up to the next plan size. A low-cost VPS around or
below $20 USD per month can usually satisfy this profile. More CPU reduces
initial synchronization time but is less important after the node is current.

If a VPS with 50 GB of SSD storage is too expensive, placing block data on
[attached persistent storage](#use-attached-storage) can reduce the required
root SSD to approximately 25 GB.
Treat that as a bare calculation and add operational headroom when selecting the
actual root-disk size.

## Calculate Storage

Start with 10 GB of SSD space for the host and stack, then add the retained
block target for every selected chain that supports the chosen pruning profile:

```text
blocks storage = pruning target x number of selected full nodes
root SSD = 10 GB + 15 GB Bitcoin chainstate + (non-Bitcoin nodes x 8 GB)
```

The available pruning profiles are:

| Fragment | Approximate retained block target per supported node |
|---|---:|
| `opt-save-storage` | 100 GB |
| `opt-save-storage-s` | 50 GB |
| `opt-save-storage-xs` | 25 GB |
| `opt-save-storage-xxs` | 5 GB |

These values are block-storage pruning targets, not hard limits for the entire
deployment.
Allow more space for chainstate growth, Docker images, databases, logs, updates,
and temporary operational needs.

For example, Bitcoin and Litecoin with `opt-save-storage-xs` need approximately:

```text
blocks storage = 25 GB Bitcoin + 25 GB Litecoin = 50 GB
root SSD = 10 GB + 15 GB Bitcoin chainstate + 8 GB Litecoin chainstate = 33 GB
```

After allowing storage headroom and rounding up to available plan sizes, an 80
GB attached volume and a 35 GB root SSD provide a reasonable starting point.

## Use Attached Storage

When an otherwise suitable VM has too little bundled storage, a lower-cost HDD
volume is generally acceptable for node `blocks` directories. Keep the
operating system, Docker, databases, chainstate, and wallets on the root SSD.

Treat this as an advanced storage layout:

- Confirm that the volume persists independently of the VM lifecycle.
- Mount it by filesystem UUID, not by a device name that may change.
- Make Docker depend on the mount so containers cannot write block data into an
  unmounted directory after a failed boot.
- Verify the mount and available capacity before installing or starting Docker.
- Use a [custom fragment](./customization.md) for bind mounts instead of editing
  the generated Compose file.
- Snapshot or back up important data off-host; an attached volume is not itself
  a backup.

## Adjust for Features

### Multiple Chains

Additional chains require more RAM and synchronization bandwidth. Four GB of RAM
can be a reasonable starting point for a low-traffic two-chain deployment, but
choose an upgradeable plan and monitor memory pressure during simultaneous
initial synchronization. Review the [cryptocurrency
guide](./cryptocurrencies.md) before selecting more than one.

Monero is pruned by default but used approximately 105 GB for its blockchain as
of July 2026; it does not use the pruning targets listed above. Plan for at
least 250 GB of SSD storage to leave enough headroom for chain growth, Bitcoin,
and the rest of the stack. ([Source](https://sethforprivacy.com/guides/accepting-monero-via-btcpay-server/))

### Lightning

Avoid `opt-save-storage-xxs` for a Lightning deployment. Lightning also adds a
continuously running service, public peer connectivity when enabled, liquidity
management, and stricter backup and recovery requirements. Read the [Lightning
guide](./lightning.md) before sizing or enabling it.

### Transaction Indexing and Mempool

Pruning is incompatible with `opt-txindex`, ElectrumX, and the bundled Mempool
service. These configurations require an unpruned node and substantially more
storage. Size them from the current chain data, index data, expected growth, and
enough free space for maintenance rather than from the pruning table above.

### Optional Applications

Applications such as WooCommerce, Zammad, and other database-backed services can
require more resources than the payment stack itself. Review each entry in the
[fragment catalog](./fragments.md) and prefer a larger or separate host when its
guide calls for one.

### Higher Traffic

More stores, API traffic, concurrent checkouts, and long retention periods put
additional load on PostgreSQL and BTCPay Server. Choose an upgradeable plan and
measure CPU, memory, database, and disk utilization rather than sizing solely
from chain count.
