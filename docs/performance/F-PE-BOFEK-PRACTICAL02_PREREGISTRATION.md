# F-PE-BOFEK-PRACTICAL02 preregistration — regime-aware practical-policy validation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_VALIDATION_RESULTS`

Canonical authority:

`integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`

Parent:

F-PE-BOFEK-PRACTICAL01 global screen.

## Purpose

Validate, on new and previously unexposed hydraulic/regime points, whether the regime structure observed in PRACTICAL01 supports a bounded practical coupling policy.

The candidate is data-derived from PRACTICAL01. Therefore none of the PRACTICAL01 screening cases may be used as validation evidence.

## Frozen candidate policy

Regime class -> numerical policy:

- DRY / TRANSITION:
  - `DTMAX = 4 * Reference DTMAX`;
  - initial dt remains geometric mean of DTMIN and candidate DTMAX.
- MOIST / WET:
  - Reference DTMAX;
  - initial dt = `0.5 * DTMAX`.
- POND:
  - Reference DTMAX;
  - initial dt = `DTMAX`.

All other numerical controls remain Reference:

- DTMIN unchanged;
- NUMBIT_CRIT unchanged;
- MAXIT unchanged;
- max backtracking unchanged;
- adaptation increase/decrease unchanged;
- failure reduction unchanged;
- head convergence unchanged;
- BALTOL02 unchanged;
- SWKIMPL=0.

No head-tolerance interaction is included because HEAD_X10/X100 did not independently meet the PRACTICAL01 performance gate.

## New validation bank

Use all four repository-backed hydraulic archetypes B01, B12, O05 and O14.

Use four new state/forcing points that were not part of PRACTICAL01:

- DRY2:
  - h0 = -200 cm;
  - rain = 1.5 cm/day;
  - policy class DRY.
- TRANS2:
  - h0 = -75 cm;
  - rain = 6.0 cm/day;
  - policy class TRANSITION.
- WET2:
  - h0 = -30 cm;
  - rain = 10.0 cm/day;
  - policy class WET.
- POND2:
  - h0 = -10 cm;
  - rain = 18.0 cm/day;
  - policy class POND.

Horizon remains 0.12 d.

This yields 16 new validation cases.

No validation-case parameters may change after result exposure.

## Comparator

Each validation case is paired against the current corrected adaptive Reference policy on the same hydraulic parameters and forcing.

P-C1 accuracy gates remain exactly as in PRACTICAL01:

- runoff <= 0.01 cm absolute when baseline <1 cm, otherwise <=1%;
- terminal storage <= max(0.01 cm, 0.5% of baseline terminal storage);
- terminal ponding <=0.02 cm;
- top/mid/bottom pressure-head <=2.0 cm each;
- max ledger <=5e-8 cm;
- no solver failure;
- rejected attempts <= max(2x baseline, 25% candidate attempts).

## Validation advancement

The regime-aware policy validates only if:

1. at least 15/16 validation cases pass P-C1;
2. every WET2 and POND2 case passes;
3. every hydraulic archetype has at least 3/4 passing validation regimes;
4. median deterministic work reduction across all 16 cases >= 20%;
5. no regime class has median deterministic work regression;
6. no new retry pathology occurs.

The 20% threshold is higher than the PRACTICAL01 global threshold because regime branching adds policy complexity.

## Timing

If deterministic validation passes, execute five paired repetitions for Reference and candidate for every validation case.

Because subprocess startup is material at these runtimes, wall-clock is supporting evidence only unless the within-case repeated timing signal is clearly separated.

A production qualification is not allowed from noisy process-level timings.

## Outcome boundary

Because the repository still lacks a complete BOFEK-ID catalogue, even a successful result is initially classified:

`PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY`

A production or BOFEK-class admission requires separate authority.

