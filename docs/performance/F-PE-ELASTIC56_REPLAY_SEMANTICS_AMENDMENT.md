# F-PE-ELASTIC56 — replay semantics amendment

Date: 2026-09-30

Status: HARNESS_SEMANTICS_CORRECTION_BEFORE_QUALIFIED_RESULT

Parent preregistration:
`F-PE-ELASTIC56_MONOTONICITY_ATTRIBUTION_PREREGISTRATION.md`.

## Reason

The first ELASTIC56 replay harness counted every increasing retained-dt
transition as a separate violation and also admitted two-point retained
sequences.

That does not reproduce the quantity reported by ELASTIC55.

ELASTIC55 defined an eligible sequence as a profile/state/forcing/regime
sequence with at least three full-converged, indicator-available points, and
incremented its monotonicity-violation count at most once per eligible sequence
when any adjacent retained pair increased.

Therefore:
- ELASTIC55 reported 15 violating eligible sequences;
- the first ELASTIC56 harness reported 51 increasing transitions across 18
  sequences.

The difference is a replay-definition mismatch, not a physical result.

## Corrected replay contract

ELASTIC56 shall reproduce the ELASTIC55 count exactly:

1. retain only sequences with at least three full-converged,
   indicator-available points;
2. classify the sequence as violating if any adjacent retained pair increases
   by more than 1e-12 relative;
3. count at most one violation per eligible sequence;
4. for attribution, retain the increasing pair with the largest Binf growth
   factor as the representative transition;
5. additionally record the number of increasing transitions inside that
   sequence;
6. classify the representative transition as CONTIGUOUS or GAP and
   SMALL/MODERATE/LARGE using the original preregistered thresholds.

No profile, state, forcing, dt, solver, indicator, alpha or numerical criterion
is changed.

## Qualification expectation

The corrected harness must reproduce:
- 170 eligible sequences;
- 15 violating eligible sequences.

If it does not, ELASTIC56 is not qualified.
