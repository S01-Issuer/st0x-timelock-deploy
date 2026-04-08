## St0x Deploy Timelock

Deploys an OpenZeppelin `TimelockController` wrapper (`S01Timelock`) to Base.
Constructor: `minDelay = 48h`, 2 proposers, open execution (`executor = address(0)`), no external admin.

### First-time setup

```
git submodule update --init --recursive
```

This populates `lib/openzeppelin-contracts` (OZ v5.6.1) and `lib/forge-std` (v1.9.6)
at the revs pinned in `foundry.lock`.

### Build

```
forge build
```

### Test

```
forge test -vv
```

Expected: **15 tests pass** (see `test/S01Timelock.t.sol`). These cover role
assignment, schedule/execute/cancel, delay enforcement, direct-call reverts,
and batched role-management flow.

### Simulate / dry-run (no broadcast)

Before triggering the real deploy workflow, run the simulation script against
the exact constructor arguments that will be used. It deploys `S01Timelock`
in-memory, asserts every post-deploy invariant, and exits non-zero on any
mismatch. **No transaction is sent.**

```
# 1. Pure local smoke check, no env vars, no RPC
forge script script/SimulateDeploy.s.sol --sig "run()" -vvvv

# 2. Dry-run with real proposer addresses (still in-memory, no RPC)
PROPOSER_1=0x... PROPOSER_2=0x... \
  forge script script/SimulateDeploy.s.sol -vvvv

# 3. Fork simulation against live Base state (still NO --broadcast)
PROPOSER_1=0x... PROPOSER_2=0x... \
  forge script script/SimulateDeploy.s.sol \
    --rpc-url base \
    --sender 0xYourDeployer \
    -vvvv
```

All three modes print `SimulateDeploy: all invariants OK` on success.

The deploy GitHub Actions workflow (`.github/workflows/manual-sol-artifacts.yaml`)
**also re-runs `forge test`, the in-memory sim, and the fork sim as pre-deploy
gates — no broadcast happens unless all three pass.**

### Deploy

```
forge script script/DeployTimelock.s.sol \
  --rpc-url $RPC_URL_BASE \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv --broadcast
```

In practice the deploy is triggered via the `Deploy Timelock` GitHub Actions
workflow, which supplies secrets and runs the pre-deploy gates first.
