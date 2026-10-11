# F-PE-NLGLOB05 closeout — floor-aware convergence certificate discrimination

Date: 2026-09-29

Final status:

`NLGLOB05_CERTIFICATE_NONSPECIFIC`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@01adcb51992615e7a09016f1ce63a244c40acf3c`

Qualification authorities:

- NLGLOB05A run `36540512902`: state-local certificate discrimination;
- strict NLGLOB05 run `36540909373`, job `109315813406`: preregistered correction/backtracking-aware C0 discrimination.

## Closure

The floor-aware certificate line is closed without replay.

Two preregistered discriminators were tested.

### NLGLOB05A snapshot certificate

Terminal endpoint failures:

- 96 / 96 certified.

Hard unresolved controls:

- all rejected.

But early-iteration false-positive fraction:

- about 49.3%;
- frozen maximum: 1%.

Conclusion:

`NLGLOB05A_MIXED_CERTIFICATE_SIGNAL`.

### Strict C0

Additional requirements:

- `z_h_inf <= 1e-8`;
- existing head contract satisfied;
- no >10% improvement among already tested backtracking factors.

Primary floor-stagnation coverage:

- 215 / 333 = about 64.6%.

All routes, materials, TG and KLAG remain represented.

Hard unresolved controls remain perfectly rejected.

But adequate-model false-positive rate:

- about 27.9%;
- frozen maximum: 5%.

Conclusion:

`NLGLOB05_CERTIFICATE_NONSPECIFIC`.

## Scientific conclusion

The nonlinear floor state is real, but terminal exhaustion is not identifiable safely from one Newton iteration, even when that iteration includes:

- storage-representation-floor proximity;
- balance-floor proximity;
- collapsed head correction;
- existing head convergence;
- lack of useful improvement among already tested backtracking factors.

The missing information is cross-iteration trajectory structure.

This is consistent with the full authority chain:

1. TIMEINT17 isolates endpoint globalization;
2. NLGLOB01 rejects simple state scaling;
3. NLGLOB02 identifies near-floor stagnation;
4. NLGLOB03 rules out final residual summation;
5. NLGLOB04 identifies the theta/storage representation floor;
6. NLGLOB05 shows that floor evidence is not temporally specific enough for safe termination.

## What is closed

Do not continue within NLGLOB05 by:

- changing the one-decade floor band;
- changing the storage-ULP threshold;
- tightening or loosening the tiny-step threshold;
- changing the 10% backtracking-improvement threshold;
- combining more same-iteration scalar conditions post hoc;
- opening NLGLOB05B acceptance replay.

Those would be outcome-conditioned tuning of the same rejected certificate family.

## Direct successor

Open:

`F-PE-NLGLOB06 — Newton-trajectory exhaustion discrimination`.

NLGLOB06 must be observational first.

It must preregister a cross-iteration feature set and decision rule before evaluating discrimination.

The mandatory negative-control authority includes:

- the 576 NLGLOB05A early iterations;
- the 433 strict-C0 adequate-model iterations;
- all above-floor, head-unresolved, storage-floor-absent and route-invalid controls.

Candidate trajectory evidence may use already available Newton history such as:

- consecutive-iteration persistence at the balance/storage floor;
- multi-iteration slope or range of normalized balance;
- persistence of collapsed head corrections;
- repeated backtracking non-improvement;
- sequence of model-quality rho.

No new Newton evaluations are needed for the first observational phase.

## Downstream gates

Only a positive NLGLOB06 discriminator may authorize a separately preregistered test-only endpoint replay.

Only a physically admissible replay may return to TIMEINT17 same-route dynamic-top qualification.

Event localization and TIMEINT18 remain downstream.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB05

BASELINE: `01adcb51992615e7a09016f1ce63a244c40acf3c`

STATUS: closed negative

FILES / COMPONENTS TOUCHED: docs/tests/workflows only

INTERFACES CHANGED: none

INVARIANTS AFFECTED: 7, 13, 23, 25, 26, 30

IMPLEMENTATION STATUS: observational discriminators persisted

TEST STATUS: focused runs PASS

QUALIFICATION STATUS: `NLGLOB05_CERTIFICATE_NONSPECIFIC`

DEPENDENCIES / BLOCKERS: no replay authorized; dynamic-top endpoint production path remains blocked

NEXT SAFE STEP: preregister NLGLOB06 trajectory-exhaustion discrimination

RECOVERY POINT: this closeout plus NLGLOB05A/NLGLOB05 results and their run authorities

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
