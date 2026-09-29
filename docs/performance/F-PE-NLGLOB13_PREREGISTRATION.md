# F-PE-NLGLOB13 preregistration — near-saturation temporal subdivision for TG admissibility

Date: 2026-09-29

Status: `AMENDED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ab151e5dcc3054f8be2bc0d7a25f905e44395f96`

Parent authority:

- TIMEINT16C: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- NLGLOB11: fixed half-step coefficient staging loses second order and does not resolve the domain failure;
- NLGLOB11A: head-space endpoint coefficient staging preserves second order but still leaves seven O05 TG near-saturation failures;
- NLGLOB12B: four of the residual still-descending failures are also TG HEAD cases and overlap the near-saturation temporal-admissibility line.

## Purpose

NLGLOB13 tests whether the remaining TG near-saturation failures are caused by attempting one nominal interval that crosses the accepted-state retention-admissibility boundary, and whether **event-local conservative step subdivision** can preserve the qualified TG mechanism without clipping accepted moisture.

This is a temporal execution experiment, not a constitutive clipping experiment.

## Frozen candidate: TG_NEARSAT_SUBDIV2

For TG only, before publishing an accepted state:

1. attempt the original nominal TG interval unchanged;
2. if the trial fails **only** because the prospective accepted TG moisture state is outside the constitutive retention domain, reject that trial;
3. cover the same nominal interval with two consecutive TG substeps of `h/2`;
4. the full probe and each half-step use the NLGLOB11A head-space endpoint coefficient staging, which preserved the TIMEINT16C second-order smooth authority;
5. each half-step must produce a constitutively admissible accepted state;
6. physical mass is accounted over each actual half-interval using the unchanged physical ledger;
7. the nominal interval is accepted only after both half-steps succeed;
8. rejected full-step trial state and numerical history must not leak into either half-step.

No accepted theta clipping, coefficient clipping, historical-K fallback or threshold relaxation is allowed.

## Trigger

Subdivision is allowed only for the exact near-saturation accepted-state admissibility failure class.

It is not allowed for:

- above-floor endpoint nonconvergence;
- route mismatch;
- nonfinite state;
- head or ponding failure;
- auxiliary coefficient-predictor failure alone. NLGLOB13 first uses the NLGLOB11A head-space stage so that the prospective accepted TG state can be evaluated without the already-falsified moisture-predictor domain exit.

Thus NLGLOB13 does not absorb NLGLOB12A endpoint robustness.

## Mandatory banks

### Bank S — smooth TIMEINT16C preservation

Use the original four smooth fixed-flux ladders with the NLGLOB11A head-space endpoint coefficient stage plus the NLGLOB13 subdivision wrapper.

Subdivision must remain inactive. The head-space stage must reproduce its already observed second-order behavior.

Require:

- 4/4 complete ladders;
- median refined head order >=1.6;
- median refined theta order >=1.6;
- at least 3/4 individual head orders >=1.5;
- physical and cumulative ledgers <=5e-8 cm;
- median work ratio versus KLAG BE <=1.15.

### Bank N — seven near-saturation TG failures

Reuse exactly the seven O05 TG HEAD/RUNOFF trajectories identified by NLGLOB11A. The prospective accepted-state domain failure is detected on the NLGLOB11A head-space-staged full probe before any full-step state is committed.

Require:

- 7/7 execute without accepted-state retention-domain failure;
- each subdivided half-step accepted state is finite and inside the retention domain;
- max accepted-interval ledger <=5e-8 cm;
- cumulative ledger <=5e-8 cm;
- no route mismatch introduced;
- no more than one level of subdivision in NLGLOB13.

### Bank D — full 96-case dynamic-top replay

Reuse the NLGLOB09 replay bank with unchanged S0 rule plus the NLGLOB13 temporal subdivision trigger.

Require:

1. complete requested horizon in at least 80% of all cases;
2. TG and KLAG represented;
3. all routes represented;
4. at least 3 materials represented;
5. no accepted-state retention-domain failure;
6. physical ledgers <=5e-8 cm;
7. all completed states finite and route-consistent.

## Amendment rationale

This amendment is persisted before any NLGLOB13 result exposure. NLGLOB11A already established that the original moisture-space auxiliary predictor itself exits the retention domain before the accepted-state admissibility question can be evaluated, while the head-space endpoint stage preserves second-order smooth behavior and exposes the actual accepted-state near-saturation failure. Using the head-space stage is therefore required to test the preregistered temporal-subdivision hypothesis rather than re-test the already closed auxiliary-predictor defect.

## Frozen classifications

If all three banks pass:

`QUALIFIED_TG_NEARSAT_SUBDIV2_RESEARCH`.

If the seven near-saturation failures persist:

`CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`.

If smooth second order regresses:

`CLOSED_TG_NEARSAT_SUBDIV2_ORDER_REGRESSION`.

If mass or accepted-state admissibility fails:

`CLOSED_TG_NEARSAT_SUBDIV2_PHYSICAL_ADMISSIBILITY_FAILED`.

If the full dynamic bank remains below 80% despite Bank N passing:

`TG_NEARSAT_SUBDIV2_QUALIFIED_BUT_ENDPOINT_BLOCKER_REMAINS`.

## Stop rules

Do not:

- recursively subdivide beyond two half-steps;
- tune the subdivision trigger after result exposure;
- clip accepted theta;
- change S0;
- change BALTOL02, MAXIT, backtracking or route physics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
