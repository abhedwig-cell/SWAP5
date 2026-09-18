# F-ROM0TA3 — Reference-floor sample architecture binding

## Decision

Use a separate F-KT qualification path, not a new ordinary temporal mode.

## Existing architecture observations

The current transaction core exposes only two valid temporal acceptance modes: external full/two-half and model certificate. `TX_TEMPORAL_NONE` exists as a diagnostic/absence value but is deliberately not a valid transaction policy.

The canonical interval runtime treats `TX_STATUS_ACCEPTED` as ordinary temporally accepted transaction authority and has no execution-purpose or qualification-purpose discriminator in `canonical_numerical_config_t`.

The kernel already owns the state-publication boundary through:

- `kernel_committed_state_t`;
- `kernel_checkpoint_t`;
- opaque `kernel_candidate_state_t`;
- lineage/revision/time validation;
- `kernel_executor_t%commit_candidate`;
- rollback/discard semantics.

Therefore adding a qualification semantic to the normal transaction policy would overload application acceptance, while implementing a parallel physical-state owner outside F-KT would duplicate authority.

## Bound design

Add an F-KT-owned **reference-floor sample path** with separate typed provenance:

- `kernel_reference_floor_result_t`;
- `kernel_reference_floor_candidate_t`;
- `kernel_executor_t%sample_reference_floor_interval`;
- `kernel_executor_t%commit_reference_floor_candidate`;
- `kernel_executor_t%discard_reference_floor_candidate`.

The path is not reachable through `run_canonical_interval` and does not add a `TX_TEMPORAL_*` value.

The sample path performs one and only one prescribed physical advance over exactly `[t0,t1]`. It applies:

1. committed-state/time/provenance guards;
2. normal model admission and parameter binding;
3. normal model interval preparation;
4. one physical `advance`;
5. solver-convergence gate;
6. complete mass-accounting gate;
7. unchanged caller-supplied hard mass tolerance;
8. candidate materialization with origin lineage/revision/time;
9. commit only through a dedicated kernel commit method with the same lineage/revision/time guards as ordinary candidates.

There is no temporal accuracy claim, retry, automatic subdivision or application budget.

## Why the candidate type is separate

An ordinary `kernel_candidate_state_t` means a canonical application interval has completed. Reusing it for a reference-floor sample would permit accidental publication through the ordinary commit API and erase the semantic distinction established by F-ROM0TA2.

A separate candidate type makes that misuse impossible at the Fortran type boundary.

The committed physical carrier itself is unchanged. Reference-floor authority remains in an external qualification receipt/trajectory ledger, not in physical state. This follows the established rule that policy/provenance documents and qualification semantics do not become physical persistent state.

## FMR binding

The first composition is deliberately narrow:

- serialized Reference backend only;
- Reference Richards only, not RossFast;
- pure hydraulic B1.10 state;
- base optional-state layout;
- no temporal-history continuation layout;
- no snow;
- no soil temperature;
- no macropore;
- no root extraction;
- no drainage-response extension;
- no fixed-weir surface-water extension;
- no accepted-trajectory directional request.

FMR exposes separate reference-floor sample/commit/discard methods. Ordinary `run_trial` remains unchanged.

## Fixed-resolution failure semantics

A failed fixed-resolution sample is terminal evidence for that preregistered row. It is not internally retried at a smaller dt.

A finer dt is a distinct preregistered resolution trajectory, never an adaptive rescue hidden inside the same row.

## Restart/replay

The qualification trajectory ledger owns:

- resolution identity;
- authority class;
- material/forcing identity;
- committed revision/time sequence;
- evidence digest.

Physical restart continues to use the existing trusted committed-state reconstruction capability. Qualification authority is restored only when the external ledger/provenance matches. No new physical state field is required.

## Resolution provenance

A successful sample must report:

- requested t0/t1;
- exact accepted dt = t1-t0;
- exactly one physical advance;
- zero transaction retries/subdivision;
- solver work;
- mass terms and residual;
- origin lineage/revision;
- candidate/commit identity.

This is sufficient to prove that the qualification trajectory was not silently subdivided.

## Nonclaims

This capability does not establish temporal adequacy, application accuracy, production timestep policy, a universal head tolerance, or a ROM error envelope.

It only makes fixed-resolution committed Reference trajectories available for cross-resolution numerical-floor qualification.
