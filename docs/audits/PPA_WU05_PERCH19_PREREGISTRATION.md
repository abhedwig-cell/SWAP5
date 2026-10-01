# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `PREREGISTERED / PRODUCTION_ADMISSION_PATH`

Baseline:
`integration/f-ci-canonical@59048478a7ddff4df90beb81a1f9c4ee99b0f5d0`

Research authority:

- A18 source-backed Andelst 112-node perched fixture;
- SWAP5 Reference baseline run `36859002384`;
- active inner-exchange research run `36860834649`;
- A18 decision:
  `QUALIFIED_ACTIVE_PERCHED_INNER_EXCHANGE_REQUIRES_SOURCE_REDUCTION_STATE_MACHINE_FOR_PRODUCTION`.

## Governance

Current canonical contains a separate RFM workstream that owns the generic
`PPA-WU05-A11...` documentation/status namespace.

PERCH19 therefore starts from current canonical and carries forward only the code and
bounded test evidence required for the perched route.

Historical perched A11-A18 documentation/status files are not imported into canonical.

## Exact B1.11 source contract

Exact SWAP 4.3.1 uses:

`FrReduQ = 0.1 ** IDecMpRat`

with `IDecMpRat = 0..3`.

Thus the retry factors are exactly:

`[1.0, 0.1, 0.01, 0.001]`.

When Richards fails at minimum timestep with macropores active and
`IDecMpRat < 3`, HeadCalc increments `IDecMpRat`, requests a retry and evaluates the
next attempt with the reduced macropore rates.

On successful later steps, legacy HeadCalc can reduce `IDecMpRat` again after its
recovery counter/time-step conditions are met.

## PERCH19 bounded production contract

PERCH19 owns the **within-trial bounded retry ladder** required by the A18 authority.

For one SWAP5 transaction attempt:

1. start at factor 1.0;
2. if the inner-Richards macropore solve returns retry-advised/non-converged, discard all
   trial-local candidate/scratch;
3. retry from the same accepted matrix and seven-field macropore state with factor 0.1;
4. continue at 0.01 and 0.001 only if required;
5. accept the first converged factor;
6. if all four fail, return retry/failure without committed physical mutation.

The reduction index/factor is numerical trial scratch, not physical continuation state.

PERCH19 deliberately does not claim the multi-step legacy recovery hysteresis
(`NStep/dtold`) as persistent production state. That broader optimization/recovery
policy requires a separate workunit if later evidence shows it is needed. The accepted
physical result for each transaction remains reproducible by restarting the ladder from
1.0.

## Gates

### G1 — exact ladder semantics

The implementation exposes only the exact factors:

`1.0 -> 0.1 -> 0.01 -> 0.001`.

No adaptive interpolation or tolerance-driven factor is allowed.

### G2 — rejected-attempt isolation

Every failed reduction attempt must begin from the same accepted matrix state and accepted
seven-field macropore state.

Failed attempts may not publish sorptivity history, geometry continuation, macropore
storage or restart state.

### G3 — A18 Andelst authority

On the source-backed 112-node perched fixture:

- factor 1.0 must reproduce the qualified retry/non-convergence;
- factor 0.1 must converge;
- accepted factor must be 0.1;
- active perched exchange must be nonzero;
- internal exchange residual and macropore balance residual must pass existing gates.

The caller/test must not preselect 0.1.

### G4 — deterministic replay/restart

A repeated transaction from the same accepted checkpoint must select the same factor and
produce the same candidate.

Restart before the interval must reproduce factor selection and accepted candidate without
persisting the reduction index.

### G5 — preservation

With inner-Richards perched mode disabled, current canonical behavior remains unchanged,
including the admitted A8-A10 macropore route and current canonical RFM optional-state
work.

### G6 — decision

If G1-G5 pass on one persisted postimage:

`QUALIFIED_PERCHED_REDUCTION_LADDER_PRODUCTION_ADMISSION_CANDIDATE`.

Canonical admission remains a separate explicit step.

## Hard constraints

- no weakening mass or nonlinear convergence tolerances;
- no hardcoded production factor 0.1;
- no committed physical mutation on failed attempts;
- no new physical restart field;
- no reuse of the conflicting generic A11-A18 documentation namespace;
- no change to default outer macropore execution when inner mode is disabled.


## Current-canonical reconciliation

PERCH19 was reconstructed onto current canonical `59048478a7ddff4df90beb81a1f9c4ee99b0f5d0` after the first pre-reconciliation CI attempt.

The only overlapping canonical delta on the carried perched dependency surface was the serialized FMR backend RFM extension. PERCH19 retains that canonical RFM configuration/forcing surface and adds only the bounded inner-macropore observation fields required by the perched route.

Backup of the pre-reconciliation branch:
`backup/ppa-wu05-perch19-pre-reconcile-20261001@5b6d1597f17465fc4c6522f2569528ee68bce96a`.
