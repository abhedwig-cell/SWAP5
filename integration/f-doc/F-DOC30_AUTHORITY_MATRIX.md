# F-DOC30 authority matrix — transactional interval architecture

## Scope

F-DOC30 is documentation-only. It deepens the reviewer-facing description of the frozen Status-A transaction and canonical-interval architecture. It does not alter production code, reference code, tests, retry policy, tolerances, physics or the frozen Status-A denominator.

## Frozen denominator

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

The F-DOC30 work branch starts from moving canonical `d223b7ab4ed297194c209f85d6b51bef86b79959`. The intervening F-APP04 admission does not modify the two frozen transaction owners or `docs/numerics/transactional-time-stepping.md`.

## Claim-to-authority matrix

| Documentation claim | Primary implementation authority | Qualification / admission authority | Claim ceiling |
| --- | --- | --- | --- |
| A transaction attempt originates from accepted state plus captured attempt context; rejected attempts restore that context. | `src/transaction/mod_transaction_reference.f90`, frozen blob `d5a71a526efaebd82054580c3186f8e3545db331` | F-KT15 lineage reconciliation; F-CI49 architecture audit and qualification | State ownership and rollback semantics only; no database-transaction analogy is required or implied. |
| Full-versus-two-half evaluation is candidate work. Solver, complete mass-accounting and temporal gates must pass before the two-half candidate replaces transaction committed state. | `mod_transaction_reference.f90` | F-KT15; F-CI49 invariant 7 and hard mass gate | Describes the frozen external full/half route; does not define a universal timestep algorithm for every solver. |
| The qualified model-certificate route also remains candidate work until solver, mass and temporal-certificate acceptance succeed. | `mod_transaction_reference.f90` | F-KT15 / F-CI49 qualification | Bounded to the admitted certificate route; no claim that every model supplies such a certificate. |
| Rejection increments rollback/retry diagnostics and scales/retries only under caller-owned transaction policy; retry exhaustion fails closed. | `mod_transaction_reference.f90` | F-CI49 gate matrix: transaction semantics, commit/rollback, retry fail-closed PASS | F-DOC30 does not establish new numeric defaults or recommend universal tolerance values. |
| An accepted transaction may update the private working state used inside a requested canonical interval. | `src/runtime/mod_canonical_interval_runtime.f90`, frozen blob `0b50dda5caf3b73a82561d7b0ba1e92386a08fee` | F-KT15 definitive production delta; F-CI49 exact-source allowlist | Internal accepted substep commit is not yet external requested-interval publication. |
| Externally committed canonical state remains unchanged until the complete requested `[t0,t1]` interval finishes; completion performs one external `move_alloc(working, committed)`. | `mod_canonical_interval_runtime.f90` | F-KT15/F-CI49 and F-CI49P postimage reconciliation | No partial externally committed canonical state is claimed on failed transaction, no-progress or substep-limit return. |
| Accepted mass terms are accumulated across internal accepted transactions, then whole-interval residual is `storage_change - (total_in - total_out)` and completeness is explicit. | `mod_canonical_interval_runtime.f90` | F-CI49 hard mass-conservation PASS; Status-A transaction preservation | This is the accounting convention of the frozen admitted runtime, not a new science equation. |
| Transaction/retry/rollback and accepted-route diagnostics remain observable while rejected candidate state is not published. | both primary owners | F-KT15 transaction/architecture gate; F-CI49 30/30 architecture invariant audit | Diagnostics are not themselves acceptance authority; accepted state remains the authority. |
| The transaction architecture remains part of Status-A and is protected by same-tree and permanent transaction/oracle/mass/numerical preservation gates. | `docs/status-a/TRACEABILITY.md` | current Status-A release-readiness inheritance | Later post-Status-A work is not silently imported into the frozen scientific denominator. |

## Qualification lineage

1. **F-KT15 definitive production owner** — `work/f-kt15-task2-solver-service-production-composition`, head `48336cb7f14e9246b03c23e549fe7354a93f9e6b`; final closeout workflow `34675851064` succeeded. Its definitive production delta names both F-DOC30 primary owner files. Its transaction gate records checkpoint/trial/retry/commit/rollback PASS, rejected-trial committed-state immutability PASS and hard mass conservation without tolerance relaxation.
2. **F-CI49 canonical admission** — first full green admission workflow `34677619807`; source allowlist includes both primary owner files. Gate matrix records transaction semantics, rejected-trial immutability, commit/rollback, retry fail-closed and hard mass conservation PASS.
3. **F-CI49P post-promotion reconciliation** — F-CI49 admission head `40e674db6c48f494fb5f49e52951c2a9ae3dfe9d`, promoted postimage `42544af575db522d012db491db801615577048df`; final decision states postimage and moving preservation authority reconciliation complete, with no production/reference/scientific/tolerance mutation.
4. **Status-A umbrella preservation** — the current traceability row for Transaction architecture binds the admitted production postimage into the frozen Status-A denominator and points to same-tree F-GC29 plus transactional, independent-oracle and applicable mass/numerical preservation gates.

## Explicit nonclaims

F-DOC30 does not:

- define a new timestep controller, retry budget, retry scale, mass tolerance or temporal tolerance;
- promote RossFast or another post-Status-A solver into the frozen Status-A denominator;
- claim generic ACID/database semantics;
- claim parallel or concurrent real-physics MultiSWAP execution;
- generalize groundwater-coupling staged interface ledgers into the generic transaction core;
- change production, reference, test, physical or numerical semantics.
