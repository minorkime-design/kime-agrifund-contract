# Soroban Development Guide — Minor Kime AgriFund

## Overview

This guide covers how to set up and use the Soroban Rust SDK development environment for building, testing, and deploying the Minor Kime AgriFund smart contracts.

## Prerequisites

- Docker and Docker Compose
- Rust (for local development without Docker)
- Git

---

## Quick Start

### 1. Start the Soroban development environment

```bash
make soroban-up
```

This starts:
- **soroban-cli**: Soroban CLI container for contract deployment
- **soroban-rpc**: Local Soroban RPC server on port 8000

### 2. Build all contracts

```bash
make build-docker
# or locally (requires Rust):
make build
```

### 3. Run all tests

```bash
make test
```

---

## Local Rust Setup (without Docker)

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add wasm32 target
rustup target add wasm32-unknown-unknown

# Install Stellar CLI
cargo install stellar-cli
```

---

## Build Configuration

The workspace `Cargo.toml` defines the following release profile optimized for WASM size:

```toml
[profile.release]
opt-level = "z"        # Optimize for size
overflow-checks = true # Keep arithmetic safety
debug = 0              # No debug info
strip = "symbols"      # Strip symbol names
debug-assertions = false
panic = "abort"        # Smaller than unwind
codegen-units = 1      # Required for maximum LTO effectiveness
lto = true             # Full link-time optimization
```

After `cargo build`, `scripts/build.sh` applies `wasm-opt -Oz` for an additional 5–20% size reduction, targeting the <15 KB per-contract threshold.

---

## Contract Development Workflow

### 1. Edit contract source

```
contracts/<name>/src/lib.rs
```

### 2. Add or update tests

```
contracts/<name>/src/test.rs
```

### 3. Build and test

```bash
cargo build --release --target wasm32-unknown-unknown
cargo test
```

### 4. Deploy locally and verify

```bash
make deploy-local
stellar contract invoke --id <CONTRACT_ID> -- <function> ...
```

### 5. Commit

```bash
git add contracts/<name>/src/
git commit -m "feat(<name>): description"
```

---

## Contract Upgrade & Migration Strategy

### When to upgrade in-place

- Bug fixes that don't change storage structure
- Performance optimizations maintaining backward compatibility
- Adding new functions without removing existing ones
- Additive event schema changes (new event types only)
- Gas optimizations that don't affect storage layout

### When to redeploy (new instance)

- Breaking storage changes (removing or restructuring `DataKey` fields)
- Changing existing event signatures
- Removing or modifying function signatures
- Major architectural changes

### Safe upgrade process

#### 1. Staging deployment

```bash
cargo build -p escrow --release --target wasm32-unknown-unknown

stellar contract deploy \
  --wasm ./target/wasm32-unknown-unknown/release/escrow.wasm \
  --network testnet \
  --source <admin-signer>
```

#### 2. Test all critical paths on staging

```bash
cargo test -p escrow -- --nocapture
```

#### 3. Storage compatibility verification

Never remove active storage keys. Additive changes only:

```rust
// ✅ Safe — adding new keys
DataKey::NewFeature,

// ❌ Unsafe — removing existing keys
// DataKey::OldFeature,  // Never remove

// ❌ Unsafe — changing key types
// Map<Address, i128> → Map<u32, i128>
```

#### 4. Multi-sig authorization (production)

Production upgrades should use multi-sig admin accounts with a 2/3 threshold minimum.

#### 5. Execute upgrade

```rust
// The escrow contract exposes an upgrade function
EscrowContract::upgrade(env, admin, new_wasm_hash);
```

#### 6. Post-upgrade checks

```bash
stellar contract invoke --id <CONTRACT_ID> --network public -- get_deal_value
```

Monitor event logs for 24–48 hours before re-enabling write operations.

---

## Storage Compatibility Rules

1. **Never remove active storage keys** — once a `DataKey` is used in production, it must remain readable
2. **Additive changes only** — new keys, new fields with defaults, new enum variants
3. **Never change the type of an existing key** — numeric types can only be widened

### Migration patterns

**Pattern 1: Versioned keys**
```rust
DataKey::InvestorsV1, // deprecated, kept for reads
DataKey::InvestorsV2, // new version
```

**Pattern 2: Migration function**
```rust
pub fn migrate_investors(env: Env) -> Result<(), Error> {
    let old: Map<Address, i128> = env.storage().instance()
        .get(&DataKey::InvestorsV1).unwrap();
    let mut new: Map<Address, InvestorInfo> = Map::new(&env);
    for (addr, amount) in old.iter() {
        new.set(addr, InvestorInfo { amount, metadata: None });
    }
    env.storage().instance().set(&DataKey::InvestorsV2, &new);
    Ok(())
}
```

---

## Contract Address Registry

Maintain network-specific addresses in `addresses.toml` (not committed — add to `.gitignore`):

```toml
[networks.testnet]
escrow                = "CABC..."
farm_campaign         = "CDEF..."
marketplace_settlement = "CGHI..."
revenue_distributor   = "CJKL..."
project_factory       = "CMNO..."
usdc_token            = "CPQR..."
platform              = "GSTU..."

[networks.public]
escrow                = ""
farm_campaign         = ""
marketplace_settlement = ""
revenue_distributor   = ""
project_factory       = ""
usdc_token            = "CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA"
platform              = ""
```

---

## Environment Variables

```bash
export SOROBAN_RPC_HOST=http://localhost:8000
export SOROBAN_RPC_URL=http://localhost:8000/soroban/rpc
export NETWORK=testnet
export DEPLOYER_SECRET=S...
export USDC_CONTRACT_ID=C...
```

---

## Troubleshooting

**`wasm32 target not found`**
```bash
rustup target add wasm32-unknown-unknown
```

**Soroban container won't start**
```bash
docker ps
docker pull stellar/soroban-preview:latest
```

**RPC connection errors**
```bash
docker-compose ps soroban-rpc
curl http://localhost:8000/soroban/rpc
```

**Test failures**
```bash
RUST_LOG=debug cargo test -- --nocapture
cargo test test_initialize -- --nocapture
```

---

## Upgrade Checklist

Before upgrading:
- [ ] All active campaigns identified and documented
- [ ] Storage compatibility verified against staging data
- [ ] Multi-sig threshold configured and tested (production)
- [ ] All tests pass on staging network
- [ ] Rollback plan documented
- [ ] Backup of current contract state taken
- [ ] Team approval obtained
- [ ] Monitoring and alerting configured

After upgrade:
- [ ] Contract WASM hash updated on-chain
- [ ] Read-only functions respond correctly
- [ ] Active campaigns validated
- [ ] Event logs monitored for 24–48h
- [ ] Indexer configurations updated with new contract addresses
- [ ] Documentation updated

---

## Emergency Rollback

```bash
stellar contract invoke \
  --id <contract-id> \
  --network public \
  -- upgrade \
  --caller <admin-address> \
  --new_wasm_hash <previous-wasm-hash>
```

---

## Resources

- [Soroban Documentation](https://developers.stellar.org/learn/build/smart-contracts)
- [Soroban Rust SDK](https://docs.rs/soroban-sdk/)
- [Stellar Developer Center](https://developers.stellar.org/)
- [Soroban Examples](https://github.com/stellar/soroban-examples)
- [Stellar Discord](https://discord.gg/stellardev)

---

**Maintainer:** Minor Kime AgriFund Blockchain Team
