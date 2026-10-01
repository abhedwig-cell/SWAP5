# F-MIG431-LOW01-A canonical closeout

Date: 2026-10-01

Status: `CANONICAL_ADMITTED_CLOSED`

Scope: SWBOTB=4 q(gwl) lower-boundary migration only.

## Admission

- admission PR: #972
- admitted head: `70635de501367b150be88206ca4afe4825c7c261`
- canonical merge commit: `5ab13625c757407e633d0871fea663a5b6fabaeb`
- target: `integration/f-ci-canonical`

The PR was merged only after the branch had been reconciled against the then-current serialized Reference backend and the bundled LOW01-A qualification completed successfully.

## Qualified behavior

The admitted implementation preserves the B1.11 SWBOTB=4 state-dependent q(gwl) semantics:

- exponential and HTAB/QTAB provider routes;
- committed/start-of-trial groundwater-level sampling;
- lagged qbot held constant through the Richards trial;
- rejected-trial committed-state immutability;
- same-checkpoint retry qbot identity;
- reuse of the admitted prescribed-qbot bottom owner;
- no generic Richards ABI, qbot sign, accepted mass owner or transaction-policy change.

Persisted qualification run `36926021938` passed the LOW01-A provider, binding, rejected-trial/retry, O0/O2, prescribed-qbot preservation and production-seam gates.

Broad PR workflows also exposed pre-existing moving-preservation/stale compile-list failures. Those were inspected and were not used as evidence for LOW01-A; no unrelated historical gate was modified to force green status.

## Boundary of claim

This closeout admits SWBOTB=4 only. It does not claim migration of all lower-boundary functionality.
