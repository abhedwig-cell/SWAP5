# PUB-ME D2 result

Status: **BLOCKED_REFERENCE_RETRY_AUTHORITY**

Publication owner: `PUB-ME`

Experiment family: `D2 — retry double-counts scientific exchange/accounting`

## Design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D2 execution checkpoint: `docs/publications/PUB-ME_D2_EXECUTION_CHECKPOINT.md`
- execution base: `integration/f-ci-canonical@dba238b4b20551dcc36e9121ffe25f19a5b1ac0e`

## Intended fixed retry authority

The prospective D2 design selected the existing FCI14 Reference temporal-policy route because its historical qualification establishes:

- one temporal rejection;
- one rollback/retry;
- acceptance on the shortened interval;
- hard mass checks.

The D2 design explicitly prohibited tuning a new retry case after execution began.

## Execution history

The D2 publication runner was built around the current canonical FCI14 source chain without changing production or reference source.

The first runs did not reach the D2 fault model:

1. current `mod_transaction_reference.f90` emitted pre-existing compare-real warnings under strict `-Werror`;
2. current `mod_canonical_contracts.f90` required admitted directional-publication dependencies absent from the historical FCI14 compile list;
3. current `mod_b1_10_reference_model.f90` required the solver contract, result bridge and legacy trial capsule absent from the historical FCI14 compile list;
4. after mechanically adding those current dependencies, `mod_b1_10_legacy_trial_capsule.f90` could not compile against the historical FCI14 stubs because the stubs no longer provide the complete current legacy capsule dependency surface, including `MOD_arrays::macp/madr` and the required `variables` module surface.

No D2 CLEAN/MUTANT transaction was executed and no D2 fault outcome was observed.

## Verdict

**D2-A = BLOCKED_REFERENCE_RETRY_AUTHORITY**

The selected historical retry authority is not directly reconstructable against the current canonical Reference dependency graph using its own bounded historical harness.

This is a research-method blocker, not evidence that retry accounting is scientifically incorrect.

The workunit stops here because expanding or rewriting the old FCI14 stub environment after seeing the dependency failures would change the prospective execution context.

## What this result does not establish

This result does not establish:

- `EARLIER_DETECTION`;
- `UNIQUE_DETECTION`;
- `NO_INCREMENTAL_VALUE`;
- `STRUCTURAL_PREVENTION`;
- any double-counting defect in production SWAP5;
- any weakness in the accepted mass ledger;
- that a different current retry route could not support D2.

## Methodological significance

The blocker is itself relevant to PUB-ME's longitudinal-evidence theme: a historically valid qualification route can become non-replayable when its harness dependency surface no longer follows the evolved implementation, even when the intended scientific semantics have not been declared changed.

That observation is **secondary evidence only** and may not be converted into the primary D2 result or used to rescue the transition-authority hypothesis.

## Next permitted action

Proceed to D3 as an independent preregistered defect family from current canonical.

A future D2 remediation requires a new pre-result execution design that selects a currently replayable retry authority for independent reasons. It must be labeled post-blocker follow-up and may not overwrite this result.
