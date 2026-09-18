# F-GC42 — Whole-window coupling-service composition

## Scope

F-GC42 composes the canonically admitted F-GC39 nonlinear coupling-window contract with the canonically admitted F-GC41 whole-window publication contract.

It does not change predictor/corrector science, MODFLOW nonlinear semantics, tangent authority, groundwater physics, or iMOD Coupler ownership.

The executable composition is:

```text
F-GC39
  capture accepted SWAP origin
  build predictor response
  open one MODFLOW prepared solve
  iterate MODFLOW + SWAP correctors
  retain final SWAP candidate
  finalize_solve
       |
       v
F-GC41
  SWAP candidate preflight
  MODFLOW timestep readiness preflight
  ledger preflight
  ---- first irreversible publication point ----
  finalize_time_step
  publish retained SWAP candidate
  commit prepared ledger
```

## Failure boundary

Failure before F-GC39 convergence never reaches publication. Failure after F-GC39 convergence but during F-GC41 preflight invalidates the abandoned MODFLOW runtime and aborts reversible SWAP/ledger state without timestep publication. Failure after the publication point is a durability/restart concern and is not represented as rollback-safe retry.

## Qualification claim

Owner qualification proves the exact hand-off and ordering between the already-qualified F-GC39 and F-GC41 contracts, including no publication on coupling failure and no publication on publication-preflight failure.

This workunit does **not** claim a real-SWAP plus real-MODFLOW production application run. The MODFLOW lifecycle itself is live-qualified in F-GC38/F-GC41; F-GC42 qualifies the service composition boundary. A later workunit must bind the production SWAP participant and exercise a real end-to-end application case.

## Exclusions

- no new groundwater physics;
- no predictor/corrector ownership in iMOD Coupler;
- no tangent-policy change;
- no N:1 scaling expansion;
- no Ribasim or irrigation;
- no claim of real-SWAP plus real-MODFLOW application qualification.
