# Minor Kime AgriFund — Soroban Smart Contracts

Rust smart contracts for the Minor Kime AgriFund platform, deployed on the Stellar network using the Soroban smart contract VM.

## Overview

Minor Kime AgriFund enables fractional tokenization of agricultural trade deals. Farmers and traders create deals backed by real produce, investors fund them by purchasing tokens, and funds are held in smart-contract escrow — releasing automatically once verified shipping milestones are completed.

**Settlement flow:**
1. Trader creates a deal (e.g. "10 tons of cocoa, $100,000 target")
2. Investors fund the deal; funds are locked in the escrow contract
3. Shipping milestones are recorded on-chain: Farm → Warehouse → Port → Importer
4. Once all milestones are verified, escrow releases: **98% to farmer, 2% to platform**
5. If funding deadline passes without reaching the target, investors are fully refunded

---

## Contracts

| Contract | Description |
|---|---|
| [`escrow`](contracts/escrow/) | Milestone-based escrow with compliance freeze controls and deadline refunds |
| [`farm_campaign`](contracts/farm_campaign/) | Full campaign lifecycle: invest, approve, milestone release, revenue distribution, dispute resolution |
| [`farm_campaign_settlement`](contracts/farm_campaign_settlement/) | Harvest verification and quality-adjusted settlement |
| [`marketplace_settlement`](contracts/marketplace_settlement/) | Spot and forward purchase order settlement (buyer → farmer + investors + platform) |
| [`project_factory`](contracts/project_factory/) | Registry and deployer of `farm_campaign` contract instances |
| [`revenue_distributor`](contracts/revenue_distributor/) | Pro-rata USDC distribution to registered token holders |
| [`alert-registry`](contracts/alert-registry/) | Per-watcher on-chain price alert rules with pause/unpause admin controls |

---

## Quick Start

### Prerequisites

- Rust with the `wasm32-unknown-unknown` target
- Docker & Docker Compose (for the containerized workflow)
- [Stellar CLI](https://developers.stellar.org/docs/tools/developer-tools/cli/install-cli)

### Install Rust toolchain

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-unknown-unknown
cargo install stellar-cli
```

### Build all contracts

```bash
make build
# or directly:
cargo build --release --target wasm32-unknown-unknown
```

### Run tests

```bash
make test
# or directly:
cargo test
```

### Build and test a single contract

```bash
make build-escrow
make test-escrow
```

### Build with Docker (no local Rust required)

```bash
make soroban-up       # start Soroban RPC + CLI containers
make build-docker     # compile inside the container
make test-docker      # run tests inside the container
```

---

## Project Structure

```
minor-kime agrifund contract/
├── Cargo.toml                      # Workspace configuration + release profile
├── Cargo.lock                      # Pinned dependency tree
├── Makefile                        # Development commands
├── README.md                       # This file
├── SOROBAN_DEVELOPMENT.md          # Detailed development guide
├── .cargo/
│   └── config.toml                 # Cargo aliases + RUSTFLAGS
├── .github/
│   └── workflows/
│       └── soroban-ci.yml          # CI: build + test + lint
├── contracts/
│   ├── escrow/
│   │   ├── Cargo.toml
│   │   ├── ESCROW_CONTRACT.md      # Full contract reference
│   │   └── src/
│   │       ├── lib.rs
│   │       └── test.rs
│   ├── farm_campaign/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── lib.rs              # Contains inline unit tests
│   ├── farm_campaign_settlement/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       └── test.rs
│   ├── marketplace_settlement/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── lib.rs
│   ├── project_factory/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       └── test.rs
│   ├── revenue_distributor/
│   │   ├── Cargo.toml
│   │   ├── README.md               # Gas cost estimates + integration guide
│   │   └── src/
│   │       ├── lib.rs
│   │       └── test.rs
│   └── alert-registry/
│       ├── Cargo.toml
│       └── src/
│           ├── lib.rs
│           └── test.rs
├── scripts/
│   ├── build.sh                    # Local build + wasm-opt post-processing
│   ├── deploy.sh                   # Dockerized deploy pipeline
│   └── deploy-and-integrate.mjs   # Node.js deploy + backend .env writer
└── shared/
    └── events.json                 # Canonical event schemas for all contracts
```

---

## Deployment

### Deploy to testnet (Bash pipeline)

```bash
export DEPLOYER_SECRET=S...          # Stellar secret key with XLM
export USDC_CONTRACT_ID=C...         # USDC token contract on testnet

./scripts/deploy.sh
```

### Deploy via Node.js (integrates with backend .env)

```bash
# Requires STELLAR_PLATFORM_SECRET in backend/.env
node scripts/deploy-and-integrate.mjs
```

### Deploy individual contract manually

```bash
# Build
cargo build -p escrow --release --target wasm32-unknown-unknown

# Deploy
stellar contract deploy \
  --wasm target/wasm32-unknown-unknown/release/escrow.wasm \
  --network testnet \
  --source <your-account>

# Initialize
stellar contract invoke \
  --id <CONTRACT_ID> \
  --network testnet \
  --source <your-account> \
  -- initialize \
  --admin <ADMIN_ADDRESS> \
  --farmer <FARMER_ADDRESS> \
  --platform <PLATFORM_ADDRESS> \
  --usdc_token <USDC_CONTRACT> \
  --deal_value 10000000000 \
  --milestone_count 3 \
  --investors '["<INVESTOR_1>", "<INVESTOR_2>"]' \
  --funding_deadline 1735689600
```

---

## Settlement Logic

| Recipient | Share |
|---|---|
| Farmer | 98% of `total_funded` |
| Platform | 2% of `total_funded` |

The 98/2 split is hardcoded in the escrow contract and cannot be changed after deployment. The `farm_campaign` contract supports configurable `platform_fee_bps` per deal.

---

## Security Model

- **Per-deal keypair isolation** — each deal uses a dedicated escrow contract instance; compromise of one does not affect others
- **Compliance freeze** — admin can freeze any contributor to block payouts pending regulatory review; emits `compliance_halt` events
- **Reentrancy guard** — `OperationInProgress` flag blocks reentrant token transfer calls
- **Replay protection** — `Released`/`Distributed`/`Refunded` flags prevent double-payment on any path
- **Multi-sig upgrade path** — contract upgrade requires admin authorization; production deployments should use multi-sig accounts
- **WASM size limit** — release profile targets <15 KB per contract to minimize on-chain storage fees

---

## Testing

```bash
# All contracts
cargo test

# With output
cargo test -- --nocapture

# Single contract
cargo test -p escrow
cargo test -p farm_campaign
cargo test -p revenue_distributor
```

Test coverage includes:
- Happy path: fund → milestone → settle
- Refund flows: deadline expiry, batch refund, idempotent re-calls
- Compliance: freeze/unfreeze, blocked settlement, batch skip
- Replay protection: double-release, double-settle, double-refund
- Reentrancy: `OperationInProgress` guard behavior
- Authorization: all admin-only and role-gated functions

---

## Resources

- [Soroban Documentation](https://developers.stellar.org/learn/build/smart-contracts)
- [Soroban Rust SDK](https://docs.rs/soroban-sdk/)
- [Stellar Developer Center](https://developers.stellar.org/)
- [Stellar Discord](https://discord.gg/stellardev)

---

## License

MIT
