# M3 gate evidence: transactional interval execution

**Status:** `IN_PROGRESS_NOT_READY_TO_EXIT`  
**Snapshot:** 2026-09-04  
**Slice:** M3 - Transactional interval execution

This page evaluates the current transactional refactoring against the [M3 exit gate](migration-slices.md#m3---transactional-interval-execution). It is an evidence dossier, not a design target. A criterion is marked complete only when explicit implementation and qualification evidence exists for that criterion.

!!! warning "Repository evidence versus active refactoring"
    The `SWAP5` repository is currently documentation-led. The active transactional refactoring is being developed and qualified in the SWAP 4.3.1 audit/refactoring workstream and is not yet mirrored here as the production source tree. D3e therefore distinguishes **implemented/refactored structure**, **supporting qualification evidence**, and **still-missing M3 exit evidence**.

## Overall judgement

M3 has made substantial structural progress, especially around explicit trial results, removal of redundant snapshot copies, solver-attempt status, retry-policy extraction and removal of interval orchestration from monolithic legacy control flow.

M3 is **not ready to exit**. Four proof areas remain decisive:

1. a hard automated proof that rejected trials cannot mutate any authoritative committed state;
2. retry-specific integrated-flux and water-balance accounting, including no double counting;
3. warm-start independence of the accepted physical result;
4. generic interval qualification including a non-midnight start, not only sub-day synchronization.

## Evidence vocabulary

| Mark | Meaning |
| --- | --- |
| `STRUCTURAL_EVIDENCE` | The refactoring seam exists or has been explicitly introduced, but the M3 behavioural gate is not yet fully demonstrated. |
| `SUPPORTING_EVIDENCE` | A related test demonstrates useful behaviour, but does not by itself prove the M3 criterion. |
| `GATE_EVIDENCE` | Direct automated evidence for the stated M3 exit criterion. |
| `OPEN` | Required evidence is still missing. |

## Refactoring evidence already available

### Explicit trial-result boundary

The transactional work introduced a result-oriented trial boundary rather than relying only on broad mutable snapshots. The full-step snapshot was replaced by an explicit `BareSoilTrialResult` (`sd_full_result`), and the second half-step endpoint is already available through `sd_half2_result%endpoint`.

Redundant diagnostic copies `sd_h_half_end`, `sd_theta_half_end` and `sd_pond_half_end` were therefore removed. This is **structural evidence** that the accepted endpoint can be carried by a transaction result rather than by duplicate mutable state.

**M3 relevance:** invariants 7 and 8; supports single-source endpoint ownership.

### Transaction controller separated from legacy control flow

The transaction controller has been progressively detached from legacy `swap.f90` control flow. The workstream identified and then moved transaction execution behind an adapter boundary rather than allowing the legacy `select case` structure to define the future transaction API.

The orchestration target is one complete transactional interval: committed start -> one or more attempts -> explicit result -> policy decision -> commit/discard.

**M3 relevance:** invariants 7, 9, 23 and 29.

### Explicit solver-attempt status

Solver outcome is being represented explicitly rather than inferred indirectly from legacy flags. This is a necessary seam between the soil-water solve and the runtime retry policy.

**M3 relevance:** retry policy can consume a typed attempt outcome without owning solver internals.

### Retry-policy extraction

Legacy timestep-reduction behaviour associated with `SoilWaterStateVar(2)` and `TimeControl(5)` has been targeted behind a solver-retry policy/execution adapter. The architectural intent is that state restoration and timestep policy no longer remain fused to legacy global control flow.

This is currently **structural evidence**, not yet a complete proof that all retry paths obey the new transaction boundary.

### Interval orchestration extraction

The active refactoring has moved toward extracting the whole orchestration of one transactional interval from `swap.f90`. This is the correct M3 seam: `swap.f90` must cease to be the owner of checkpoint/trial/retry/commit semantics.

The remaining qualification question is behavioural: whether every reachable retry/reject path now obeys that seam.

## Supporting interval evidence

Separate API/runtime test work already provides useful supporting evidence for interval execution:

- a real-input scheduler path executed eight committed 6-hour timesteps with exact equivalence through the new scheduling chain;
- an API-C/D coupling testbank executed 8 x 6-hour synchronization intervals;
- the latter reported maximum interval water-balance residual `4.42e-8 cm` and 2-day residual `2.09e-8 cm` for the tested path;
- repeated execution of that testbank was byte-identical;
- a two-way dummy-aquifer coupling experiment demonstrated explicit head -> SWAP -> flux -> aquifer -> head progression with conservative aquifer accounting.

These results are **supporting evidence**, not M3 exit evidence. They demonstrate that sub-day synchronization and repeatable interval execution are feasible, but they do not yet prove rollback integrity, retry accounting, warm-start independence or a non-midnight start across the complete transactional path.

## M3 exit-criterion matrix

| M3 exit criterion | Current evidence | Status | What is still required |
| --- | --- | --- | --- |
| Rejected trials do not mutate committed state | Explicit trial-result/commit structure and reduced snapshot duplication support the intended boundary. | `STRUCTURAL_EVIDENCE` | Automated state fingerprint test over every committed physical-state field before/after forced rejected trials, including optional active state. |
| Accepted endpoint is committed exactly once | Endpoint now travels through explicit trial results instead of redundant endpoint copies. | `STRUCTURAL_EVIDENCE` | Commit-count or state-version test showing exactly one authoritative state transition for one accepted interval, including after one or more rejected attempts. |
| Integrated fluxes are not double counted across retries | Water balance is already a hard architectural rule; supporting 6-hour testbank balances are small. | `OPEN` | Force at least one retry and compare interval-integrated flux/accounting against an equivalent accepted reference path; prove rejected-attempt fluxes never enter committed accounting. |
| Rerun from identical committed state is deterministic or tolerance-consistent | API-C/D 8 x 6-hour testbank produced byte-identical repeat execution. | `SUPPORTING_EVIDENCE` | Repeat the actual M3 transaction path with forced retry/reject behaviour from an identical checkpoint and compare endpoint, fluxes, route diagnostics and balance. |
| Warm-start numerics do not change accepted physical result outside tolerance | Architecture distinguishes warm-start numerics from physical state. | `OPEN` | Run identical committed state/forcing with cold start and at least two different retained numerical guesses; compare accepted endpoint and integrated fluxes within stated tolerances. |
| Retry/fallback route is visible in diagnostics | Explicit solver-attempt status is being introduced and retry policy is being separated. | `STRUCTURAL_EVIDENCE` | Stable interval diagnostics containing attempt count, reason/status, timestep sequence, execution class/fallback and final acceptance state. |
| Generic `[t0,t1]`, including non-midnight start and non-day interval | 6-hour interval scheduling and coupling synchronization have been demonstrated. | `SUPPORTING_EVIDENCE` | At least one full transactional test starting at a non-midnight time plus a non-day interval, with no calendar-specific branch required for correctness. |
| Water balance closes for normal and retry paths | Normal/sub-day supporting cases show small residuals. | `OPEN` | Explicit forced-retry balance gate for accepted interval, including rollback of rejected integrated flux/storage contributions. |
| Retry policy never silently changes physical options | Physical/numerical policy separation is normative and retry policy is being extracted. | `OPEN` | Test that physical configuration hash/module activation is identical before and after retry/fallback decisions; only numerical policy may change. |

## Minimum remaining code cuts before M3 exit testing

D3e identifies four remaining implementation cuts. These are intentionally narrow.

### M3-C1 - authoritative commit owner

There must be one code path that can replace the committed column state with a trial endpoint. Trial execution, solver calls, retry adapters and diagnostics must not directly mutate the authoritative state store.

**Completion test:** force a rejected attempt that perturbs every relevant trial-state field; the committed-state fingerprint remains unchanged until the final accepted commit.

### M3-C2 - committed accounting versus attempt accounting

Fluxes and storage changes produced by an attempt must remain attempt-local until acceptance. The final interval result must aggregate only accepted physical history.

**Completion test:** force retry after a numerically valid partial attempt and prove rejected attempt fluxes are absent from the committed water balance.

### M3-C3 - warm-start side channel

Numerical warm-start data may persist between attempts, but it must have a separate ownership path from committed physical state.

**Completion test:** deliberately vary or clear warm-start data while keeping the committed checkpoint identical; accepted physics remains within the declared reference tolerance.

### M3-C4 - generic-time acceptance test

The extracted interval executor must receive explicit `t0` and `t1` semantics independent of midnight/day control flow. Calendar event boundaries may still cause runtime subdivision when a physical process requires them, but they must not define the fundamental transaction.

**Completion test:** one non-midnight transactional interval, one non-day interval, and one interval crossing a calendar boundary that is irrelevant to active physics. Results must follow physical/event requirements, not hidden daily assumptions.

## Recommended M3 qualification test set

A compact M3 gate should contain at least these cases:

| Test | Purpose |
| --- | --- |
| `M3-T01 normal-commit` | Baseline transaction, exactly one commit. |
| `M3-T02 forced-reject-state` | Prove rejected trial cannot mutate committed state. |
| `M3-T03 retry-flux-accounting` | Prove rejected fluxes/storage are not double counted. |
| `M3-T04 deterministic-rerun` | Repeat identical checkpoint and forcing. |
| `M3-T05 warm-start-independence` | Compare cold and altered numerical warm starts. |
| `M3-T06 non-midnight-interval` | Remove implicit day-start assumption. |
| `M3-T07 non-day-interval` | Qualify arbitrary `[t0,t1]` duration. |
| `M3-T08 retry-diagnostics` | Check attempt/retry/fallback provenance. |
| `M3-T09 physics-policy-invariance` | Verify numerical retry cannot alter physical options. |
| `M3-T10 retry-water-balance` | Hard mass-balance gate under forced retry. |

The tests should compare both state and interval-integrated fluxes. Water balance is a hard pass/fail condition, not a descriptive metric.

## M3 exit decision

**Decision:** `NO_EXIT_YET`.

The architecture and active refactoring are sufficiently mature to define the transaction boundary, but behavioural evidence is still incomplete. The next development work should therefore not introduce another abstraction layer. It should implement **M3-C1 and M3-C2 first**, because authoritative commit ownership and attempt-local accounting are prerequisites for meaningful rollback and water-balance qualification.

After C1/C2, implement C3/C4 and execute M3-T01 through M3-T10. Only then should the implementation-status row for transactional checkpoint/trial/retry/commit be reconsidered for promotion from `IN_PROGRESS` to `QUALIFIED`.

## Invariant trace

D3e primarily exercises invariants **7, 8, 9, 10, 13, 23, 24, 26, 29 and 30**, with supporting ownership constraints from invariants **3-5**. No M3 exit may weaken mass conservation or silently alter the configured physics.