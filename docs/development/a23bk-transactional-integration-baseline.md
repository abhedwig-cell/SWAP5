# A23BK transactional integration baseline

**Status:** `HISTORICAL_LINEAGE_INCOMPLETE_NEW_BASELINE_REQUIRED`  
**Workstream:** TX  
**Slice:** A23BK  
**Baseline branch:** `integration/a23bk-transactional-rebase`  
**Baseline parent commit:** `2d05eeab9d766d51bc7c436ea1e45f9b49940e92`  
**Reference oracle:** `B1.6`  

## Decision

The historical transactional/step-doubling reconstruction route is closed as non-materializable for production use.

This does not invalidate the focused qualifications obtained from retained source, complete patches or qualified shadow builds. It means that patch-stage evidence may no longer be promoted to a current production postimage when the exact parent bytes are unavailable.

Future transactional integration starts from this explicit Git baseline and must materialize complete source postimages into Git.

## Evidence for closing the historical route

The retained materialization ledger classifies several source units required for the old transaction lineage as incomplete evidence rather than exact current source:

- `mod_step_doubling.f90`: `PATCH_STAGE_EVIDENCE`;
- `mod_time_step_decision.f90`: `PATCH_STAGE_EVIDENCE`;
- `mod_transaction_commit_contract.f90`: `PATCH_STAGE_EVIDENCE`;
- `mod_bare_transaction_legacy_adapter.f90`: P08/P17/P18 `PATCH_STAGE_EVIDENCE`;
- `mod_solver_retry_decision.f90`: P11/P18 `PATCH_STAGE_EVIDENCE`;
- `mod_bare_trial_attempt_legacy_adapter.f90`: P12 `PATCH_STAGE_EVIDENCE`.

Later post-stage/runtime evidence demonstrates important control-flow semantics, including restore-before-shadow, rollback on temporal rejection and dispatch to an accepted transaction executor. However, those artefacts are deltas against source parents that were not retained as exact current postimages. They are therefore evidence of behavior/interface evolution, not a deterministic source reconstruction chain.

The available SWAP 4.3.1 distribution contains no transactional step-doubling implementation from this later refactor lineage.

## New baseline contract

1. Git is the source of truth for all new transaction source.
2. New or imported transaction modules must be committed as complete source files, not only as patches in chat artefacts.
3. A patch may define an exact postimage only when its parent bytes are pinned and the patch applies cleanly with a verified resulting hash.
4. Historical `PATCH_STAGE_EVIDENCE` remains useful for design review and behavioral intent, but is not accepted as current production source.
5. The B1.6 corrected legacy reference is the physical/numerical oracle for qualification unless an explicitly later qualified reference replaces it.
6. Production integration must preserve the top-Jacobian qualified route; A23BK changes no solver/Jacobian code.
7. Transactional source must retain checkpoint -> trial/retry -> commit/rollback semantics and must not let rejected trials mutate committed physical state.
8. Mass conservation remains a hard acceptance condition. A source integration cannot be promoted solely because focused transaction tests pass.
9. Measurement/diagnostic seams remain outside physical state and may not change solver policy.
10. A23BH selective step-doubling remains `PRODUCTION_ACCURACY_HOLD` until an integrated always-sampled reference path and representative difficult-column fixtures exist.

## Reference root

The current repository main commit used to start this integration branch is:

`2d05eeab9d766d51bc7c436ea1e45f9b49940e92`

That repository state admits corrected reference `B1.6`. The pinned B1.6 evidence records:

- B0 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- B0 source archive SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
- B1.6 oracle status: `QUALIFIED_NUMERICAL_BEHAVIOURAL`.

## What is retained from the historical work

Retain as qualification evidence, not as a production source tree:

- exact full-source files recovered independently;
- exact postimages produced from complete patches with pinned preimages;
- focused rollback/retry tests;
- step-doubling controller and replay contracts;
- transaction ownership/interface decisions;
- runtime-cost and diagnostic observer contracts;
- A23BH/A23BI/A23BJ selection and reference-screen evidence.

Do not combine these artefacts into an assumed historical tree unless every intermediate source preimage is exact.

## Next integration unit

The next unit should be `A23BL`: materialize a first canonical transaction source set on this branch from complete, provenance-qualified source only. Where a historical source unit is incomplete, re-implement the accepted contract explicitly against B1.6 rather than reconstructing undocumented bytes. The resulting full source postimages, build manifest and focused transaction gates must all be committed together.

A23BL must not yet introduce a new selective step-doubling policy. First establish an always-sampled/reference transaction path on the new baseline.

## Invariants

Primary: 1, 2, 3, 7, 8, 13, 23, 25, 29, 30.  
Supporting: 4, 5, 6, 16, 24, 26.
