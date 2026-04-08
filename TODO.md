# TODO

Follow-ups deliberately deferred from the audit + test + simulate pass.

## Dead role-management scripts

`script/ScheduleRoles.s.sol` and `script/ExecuteRoles.s.sol` still reference
the removed `GUARDIAN` env var (removed in commit `80aa476`). They are not
part of the deploy flow, and `ExecuteRoles.s.sol` has its `vm.broadcast`
body commented out, so they are currently dead code.

Additional smells:
- Both scripts declare `pragma ^0.8.20` while everything else in the repo is
  `^0.8.25`. It still compiles under `solc 0.8.25`, but is inconsistent.
- `ExecuteRoles.s.sol` declares a `salt` local that is never used (compiler
  warning).
- `ScheduleRoles.s.sol` reads `PRIVATE_KEY` into an unused local and its
  `run()` is effectively a no-op (compiler warning).

Decide whether to:
1. Delete both scripts outright (simplest — role management can be done
   via `cast` one-liners against the live timelock), or
2. Rebuild the role-management flow without a guardian, pragma-bumped and
   wired into the test suite.

## `.env.example` still lists `GUARDIAN`

`.env.example` still has a `GUARDIAN=0x...` entry that is no longer read by
any production script. Remove it when the dead scripts above are resolved.

## Bytecode golden file (optional hardening)

`SimulateDeploy.s.sol` already diffs the deployed runtime code against the
freshly-compiled artifact (`vm.getDeployedCode(...)`) as an in-run drift
check. A stronger guarantee is to commit a golden hex file (e.g.
`artifacts/S01Timelock.bytecode.hex`) and add a CI step that diffs it
against the current build. That catches unintended compiler / dependency
drift between branches, not just within a single run. Orthogonal to the
`SimulateDeploy` check; add if/when the compiler pin or OZ version changes.
