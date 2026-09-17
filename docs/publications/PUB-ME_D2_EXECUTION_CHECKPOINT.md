# PUB-ME D2 execution checkpoint

Status: **RECONCILED_DESIGN_BOUNDARY_BEFORE_D2_MUTANT_EXECUTION**

Publication owner: `PUB-ME`

Experiment family: `D2 — retry double-counts scientific exchange/accounting`

## Immutable design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D2 design semantics: rejected attempt contributes to accepted accounting; later retry succeeds and is published again
- required B2 oracle: accepted ledger unchanged after rejected attempt and exactly one accepted publication after acceptance

The preregistered B0/B1/B2 hierarchy, interpretation classes and paper-level falsification rules remain immutable.

## Execution authority

- current canonical at D2 start: `dba238b4b20551dcc36e9121ffe25f19a5b1ac0e`
- D1 is admitted on this canonical and classified `STRUCTURAL_PREVENTION`
- D1 result does not alter D2 design or scoring

## Reconciled retry capability

Current `tests/transaction/test_transaction_reference.f90` contains a bounded deterministic retry scenario in which:

- one temporal attempt is rejected;
- one rollback is recorded;
- retry scale is 0.5;
- the subsequent retry is accepted;
- the accepted endpoint is reconstructed from the committed checkpoint.

This scenario is suitable for validating D2 qualification-only fault instrumentation, but it is not by itself sufficient as the primary publication result because it uses a synthetic scalar transaction model rather than SWAP physical mass publication.

## Primary D2 evidence rule

D2 primary classification must use a real SWAP Reference production/production-equivalent route with:

1. non-zero physical water exchange so double accounting is observable;
2. real physical solver execution;
3. at least one rejected attempt followed by an accepted retry or accepted re-execution from the same committed origin;
4. normal accepted mass publication available from the runtime result/ledger;
5. a qualification-only faulty publication path that additionally records the rejected attempt without changing production `src/**` or `reference/**`;
6. matched clean control under identical physical parameters, forcing, accepted start state and accepted final interval.

If no current route satisfies these requirements without changing production semantics, D2 must stop `BLOCKED_MISSING_PRIMARY_FIXTURE`; it must not be replaced post hoc by a weaker synthetic claim.

## Frozen two-stage execution plan

### Stage A — fault-instrumentation validation

Use the existing deterministic transaction-reference retry scenario only to prove that the qualification harness can distinguish:

- candidate/rejected attempt contribution;
- accepted retry contribution;
- deliberately faulty cumulative publication containing both.

Stage A may validate the mutant mechanics but cannot determine the publication classification.

### Stage B — primary SWAP Reference experiment

Recover or construct, using existing public/admitted test interfaces only, a non-zero-flux Reference fixture that rejects after real physical execution and then accepts a retry/re-execution.

Before inspecting D2 comparative results, freeze:

- exact fixture source and parameters;
- forcing and sign convention;
- rejection mechanism;
- accepted retry mechanism;
- expected clean accepted mass-publication identity;
- B1 oracle set;
- B2 transition oracle set;
- faulty publication insertion point.

No result-dependent adjustment of flux, tolerance or timestep is allowed after the primary fixture freeze except as an explicitly failed/repreregistered experiment.

## Comparator interpretation

B1 must include all existing credible conventional checks applicable to the fixture, especially final accepted mass closure. D2 is therefore allowed to produce `NO_INCREMENTAL_VALUE` if ordinary accepted mass-balance checks already detect the double count at the same boundary.

Potential `EARLIER_DETECTION` is only valid if B2 rejects the invalid publication at the rejected-attempt boundary while B1 detects the consequence only later in accepted cumulative accounting.

Potential `UNIQUE_DETECTION` requires the matched B1 suite to remain green while B2 detects the seeded D2 fault.

## Hard exclusions

- no `src/**` mutation;
- no `reference/**` mutation;
- no weakening of accepted mass gates;
- no omission of B1 mass/conservation checks to manufacture incremental value;
- no claim from Stage A alone;
- no reuse of D1 as evidence for D2;
- no D3-D6 execution in this workunit;
- no post-result change to the preregistered interpretation rules.

## Next permitted action

Locate and pin a current-canonical non-zero-flux SWAP Reference fixture satisfying the Stage-B requirements. In parallel, Stage-A qualification instrumentation may be implemented because its result cannot determine the primary D2 classification. Stop fail-closed if the primary fixture cannot be established without production changes.

## Stage-B fixture freeze before primary D2 execution

Status: **FROZEN_FROM_PREEXISTING_FSI38_EVIDENCE**

This fixture is selected from F-SI38 evidence produced before PUB-ME D2 existed, not by trial-and-error on D2.

Historical F-SI38 authority:
- status authority: `integration/f-si/F-SI38_STATUS.json`;
- qualified workflow run: `34815146569`;
- qualified job: `103884165405`;
- exact historical measurements for prescribed-qbot Reference Richards:
  - `q = +1.0e-6 cm/day, dt = 1.0e-2 day -> Binf = 3.70914014642538750e-6 cm`;
  - `q = +1.0e-6 cm/day, dt = 1.0e-4 day -> Binf = 1.23637538907952566e-7 cm`.

Frozen Stage-B physical/numerical fixture:
- Reference Richards / serialized typed route;
- bottom mode = 2 prescribed qbot;
- hydrostatic accepted initial state;
- top flux = `+1.0e-6 cm/day`;
- bottom flux = `+1.0e-6 cm/day`;
- requested interval = `[0.0, 0.01] day`;
- temporal mode = `TX_TEMPORAL_MODEL_CERTIFICATE`;
- explicit temporal head budget = `1.0e-6 cm`;
- retry scale = `0.01`;
- max retries = `1`;
- mass tolerance = `1.0e-12 cm`;
- unchanged Reference solver tolerances and physics from the admitted FMR44R/FSI38 route.

Pre-run prediction frozen from historical evidence:
1. initial `dt=0.01` principal solve is physically solvable but its temporal certificate exceeds the frozen `1e-6 cm` budget and is rejected;
2. the retry duration is exactly `0.0001 day`;
3. the historical F-SI38 `dt=0.0001` certificate lies below the frozen budget and is therefore the expected accepted retry regime;
4. nonzero prescribed throughflow makes accepted/rejected transfer accounting observable.

Fail-closed rule:
- if the unchanged clean route does not produce exactly one certificate rejection followed by an accepted retry at `dt=0.0001 day`, classify D2 Stage B as `BLOCKED_PRIMARY_FIXTURE_PREDICTION_FAILED`;
- do not change flux, head budget, retry scale, solver tolerances or duration after observing the clean result;
- if the primary mutant cannot be instrumented without changing `src/**` or `reference/**`, classify `STRUCTURAL_PREVENTION` only when the admitted public interface itself demonstrably prevents the preregistered early accepted-ledger publication; otherwise classify `BLOCKED_MISSING_PRIMARY_FAULT_INSTRUMENTATION`.

The existing FMR44R accepted `q=1.0e-10, dt=1.0e-4` production fixture is not reused as the primary D2 case because it has no rejected attempt.
