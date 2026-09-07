# F-MQ12 — F-KT01 downstream admission

## Purpose

F-MQ12 consumes the first qualified F-KT production-kernel boundary after the F-CI18 qualified exit. It does not change production source and does not promote real-physics or production-MultiSWAP coverage without executable evidence.

## Exact lineage

- F-MQ11 parent: `e581efae0b5d466709b590d1727d84835919b32d`
- F-KT branch observed: `integration/f-kt`
- F-KT01 qualified branch head: `62f27672bbb74066ece202de8898597e655aed3d`
- F-KT01 qualification evidence commit: `e350d84e975e9f6ab4475658566f623b0e46f9ac`
- F-KT01 qualification workflow: `34117279573`
- F-CI18 baseline: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- corrected legacy oracle: B1.10

## Admitted F-KT01 boundary

F-MQ accepts the qualified F-KT01 evidence for the structural kernel/transaction boundary:

- one canonical production kernel API, `kernel_executor_t%advance_interval`;
- caller-owned committed state is input-only during advance;
- a candidate state is materialized only after the complete requested interval is accepted;
- publication requires explicit `commit_candidate`;
- `rollback_candidate` discards only the candidate;
- rejected trials do not mutate committed state;
- replay from the same committed state is exact on the qualified F-KT01 deterministic backend;
- forcing and numerical configuration are explicit, separate inputs;
- generic `[t0,t1]` semantics are preserved;
- worker scratch is not persistent column state;
- unrounded transaction mass is passed through without fabrication, and an injected mass defect is rejected.

## Ownership reclassification

No original F-MQ requirement is removed. F-MQ12 changes only downstream ownership for properties that F-KT01 now demonstrably covers.

- **P05**: F-KT structural state/candidate boundary is qualified; no remaining structural owner in this overlay.
- **P12**: F-KT forcing-input ownership is qualified; real B1.10 forcing-locality remains F-VQ.
- **P14**: F-KT state/scratch separation is qualified; complete optional-process state coverage remains F-VQ.
- **P16**: F-KT unrounded mass pass-through and rejection semantics are qualified; the real event-local mass record remains F-VQ.
- **P21**: candidate commit/rollback prerequisite is qualified; production predictor-corrector orchestration remains F-MR.
- **P22**: transaction prerequisite is qualified; explicit production coupling flux conservation remains F-MR.

R08, P07 and P08 gain confirming F-KT01 evidence but no ownership change, because their remaining work was already assigned to F-VQ and/or F-MR.

## Explicit holds

F-KT01 does **not** qualify:

- real B1.10 reference execution;
- complete optional-process temporal/storage scope;
- solver reentrancy;
- production MultiSWAP runtime;
- MODFLOW coupling;
- a complete F-MQ03 event-local real mass fixture.

At the F-MQ12 start, F-SI still pointed to the F-CI18 start commit and no F-MR branch was present. No claims are inferred from workstream names alone.

## Coverage

The three coverage dimensions are unchanged:

- synthetic executable: **27 / 35**
- real physics executable: **0 / 35**
- production runtime qualified: **0 / 35**

This is deliberate. F-MQ12 qualifies a production-kernel boundary and improves responsibility routing, but does not substitute structural evidence for physical or runtime qualification.

## Gate

The F-MQ12 workflow checks both the local overlay and the exact source-bound F-KT01 evidence. CI fetches the pinned F-KT01 qualification commit and verifies status, qualification evidence, contract semantics and the relevant kernel source fragments. Branch drift is therefore not silently accepted.
