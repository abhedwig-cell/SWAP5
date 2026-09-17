# PUB-ME D1-B result

Status: **BLOCKED_CONTINUATION_CONFIGURATION**

Publication owner: `PUB-ME`

Experiment family: `D1 — rejected candidate mutates committed physical state`

Substudy: **D1-B detection timing**

## Immutable design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D1-B execution checkpoint: `docs/publications/PUB-ME_D1B_EXECUTION_CHECKPOINT.md`

The clean/mutant continuation configuration and contamination magnitude were frozen before the first mutant execution.

## Execution history

### Run 1

Failed before experiment execution because the publication harness referenced a nonexistent `fmr_serialized_column_result_t%status` member.

Disposition: **tooling error**, corrected to the actually published `kernel_status` field. No scientific setting changed.

### Run 2

Reached the frozen B1-boundary assertion. Diagnostic output showed every preregistered B1 boundary observation was equal, but the compound Fortran expression evaluated false because unparenthesized `.eqv.` has lower precedence than `.and.`.

Disposition: **harness logic error**, corrected only by parenthesizing the two logical-equivalence terms. No criterion changed.

### Run 3

Reached the actual preregistered experiment.

Observed B1 boundary tuple:

- clean kernel status = 2;
- mutant-pre-fault kernel status = 2;
- clean/mutant completed = false;
- clean/mutant committed = false;
- accepted transaction count = 0 / 0;
- accepted total in = 0 / 0;
- accepted total out = 0 / 0;
- committed revision = 0 / 0;
- committed time = 0 / 0.

Therefore the frozen strong-conventional B1 observations remained matched at the rejection boundary after the qualification-only contamination was introduced.

The direct B2 physical-identity assertion was reached before the continuation and did not fail.

The frozen clean continuation then failed:

- classification emitted by the preregistered test: `BLOCKED_CONTINUATION_CONFIGURATION`;
- clean continuation `kernel_status = 2`;
- canonical meaning: `CANONICAL_STATUS_TRANSACTION_FAILED`.

Per the preregistration, this terminates D1-B without tuning the continuation tolerance, retry policy, contamination magnitude, forcing or case.

## Result

**D1-B = BLOCKED_CONTINUATION_CONFIGURATION**

This is not `NO_INCREMENTAL_VALUE`, `EARLIER_DETECTION`, or `UNIQUE_DETECTION`.

The experiment established one useful intermediate fact before the blocker:

> the frozen B1 status/ledger/revision/time observations can remain fully matched while the qualification-only D1 physical contamination is present and the B2 physical-identity oracle has already observed the state difference.

However, because the matched clean continuation did not complete, the preregistered later B1 detection point was not available. No B1-versus-B2 detection-timing classification is therefore authorized.

## Relationship to D1-A

D1-A is independent and has been admitted to canonical as `STRUCTURAL_PREVENTION` through PR #202 / merge `dba238b4b20551dcc36e9121ffe25f19a5b1ac0e`.

This blocked D1-B attempt does not weaken D1-A and must not be combined with it to manufacture a stronger classification.

## Nonclaims

This result does not establish:

- earlier or unique B2 detection;
- that the frozen continuation failure was caused by the injected contamination, because the CLEAN continuation itself failed;
- a production defect;
- that a different continuation case would succeed;
- any D2-D6 result.

## Next permitted action

Do **not** repair D1-B by tuning after result inspection.

Proceed to D2 as the next independent preregistered defect family from current canonical.

A future D1-B remediation is allowed only as a separately preregistered experiment with an independently justified continuation configuration, explicitly labeled as post-blocker follow-up rather than the original prospective D1-B test.
