# F-PE-ELASTIC61 — scaled direct-defect calibration and third-profile blind holdout preregistration

Date: 2026-09-30

Status: PREREGISTERED_CALIBRATION_THEN_BLIND_HOLDOUT

Parent authorities:
- F-PE-ELASTIC59 — QUALIFIED_DIRECT_DEFECT_HEAD_RESEARCH_CANDIDATE;
- F-PE-ELASTIC60 — QUALIFIED_DIRECT_DEFECT_HEAD_BLIND_SAFE_BUT_SATURATED_IMPRACTICAL.

Parent postimage:
`research/f-pe-elastic60-direct-defect-holdout@1a037b88845ecfef76860105a7a0dbf669e17556`

Canonical authority:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Can one global multiplicative scale derived only from the ELASTIC59 development
bank convert direct defect head into a safe and practically usable saturated
temporal-error signal on a third independent profile set?

## Frozen physical limits

Inherited unchanged from TEMPORAL04/05:

- head limit: `0.01 cm`;
- theta limit: `1e-5`.

Hard mass acceptance remains separate and unchanged.

## Calibration authority

Use only the exact ELASTIC59 development profiles:

- 11060;
- 10260;
- 8016;
- 3030.

Use the exact ELASTIC59 bank:
- h0 = -75, -20, +2, +10 cm;
- delta = +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- mode 7, swkimpl=0;
- same direct defect indicator.

For every paired full+half1+half2 observation with
`DEFECT_HEAD_INF > 0`, define:

`r = H_INF / DEFECT_HEAD_INF`.

Freeze:

`alpha_D1 = max(r)`

over the ELASTIC59 development bank only.

No ELASTIC60 numeric result may enter this calculation.

No intercept, regime factor, state factor, profile factor, saturation factor or
other fit is permitted.

## Candidate

Scaled direct-defect head:

`E_D1 = alpha_D1 * DEFECT_HEAD_INF`.

C-SAFE accepts the first available dt on the fixed refinement ladder satisfying:

`E_D1 <= 0.01 cm`.

No monotonicity assumption is allowed.

## Third independent profile holdout

Use the frozen BRO artifact and ELASTIC55 eligibility/diversity rules.

Exclude before selection:

- original profile 90116260;
- ELASTIC55 profiles 11060, 10260, 8016, 3030;
- ELASTIC60 profiles 11020, 8120, 4015, 3011.

Then:
1. enumerate eligible unique diversity keys in ascending profile id;
2. partition by horizon_count;
3. order remaining non-empty horizon-count classes ascending;
4. select the smallest profile id from each of the first four remaining classes;
5. fail closed if fewer than four classes remain.

This selection is source-only and independent of ELASTIC61 numerical output.

## Holdout bank

Per selected profile:
- same 16-node profile representation;
- admitted Staringreeks retention fields;
- profile-specific generated Ss;
- parent Ksat/lambda fixture retained;
- bottom mode 7;
- swkimpl=0;
- same solver/tolerances.

States, perturbations, regimes and dt ladder are identical to calibration.

Requested holdout:
`4 * 432 = 1728 cases`.

## Blind safety gates

For every paired selected holdout observation:

- realized `H_INF <= 0.01 cm`;
- realized `THETA_INF <= 1e-5`.

Any paired selected head failure falsifies the scaled candidate.

## Practicality observations

Report:
- selected/exhausted sequences;
- saturated selected count;
- unsaturated selected count;
- paired selected count;
- max selected H_INF;
- max selected THETA_INF;
- dt distribution.

Compare selected counts with unscaled D1 on the same holdout, observation-only.

## Gates

A1. Calibration uses exactly the four ELASTIC59 development profiles and no
ELASTIC60 numeric data.

A2. `alpha_D1` is frozen before any third-profile holdout solve executes.

A3. Exactly four third-profile holdouts selected by the source-only rule with no
overlap with original, ELASTIC55 or ELASTIC60 profiles.

A4. All calibration and holdout requested cases execute.

A5. O0/O2 semantic identity.

A6. Direct defect observables finite/nonnegative when available.

A7. Paired selected head and theta gates enforced.

A8. No refit after holdout starts.

A9. Zero production `src/**` changes.

## Decision

A green ELASTIC61 may qualify a scaled direct-defect research candidate.

It does not authorize:
- production temporal policy;
- F-CI14 completion;
- relaxation of mass acceptance;
- runtime admission.
