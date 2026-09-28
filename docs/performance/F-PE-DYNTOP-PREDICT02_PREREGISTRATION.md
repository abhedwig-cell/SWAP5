# F-PE-DYNTOP-PREDICT02 preregistration — two-step normalized-history classifier

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@94e265d18200b40d942184809e1e45694aea850f`.

Parent: F-PE-DYNTOP-PREDICT01.

## Purpose

Test whether two-step accepted-state history can separate the four non-ponded false-safe large intervals from genuinely safe large intervals without extra Richards solves.

## History features

For every accepted interval define:

`r_k = max_i(|h_i(t_k)-h_i(t_{k-1})| / max(10 cm, |h_i(t_{k-1})|))`.

At a proposed large-step origin record:

- `r_last`: normalized movement on the most recent accepted interval;
- `r_prev`: normalized movement on the preceding accepted interval;
- `trend = r_last / max(r_prev,1e-12)`.

The existing origin-frozen dynamic-top prediction is retained.

If two-step history is unavailable, every PREDICT02 rule predicts UNSAFE.

## Frozen candidate rules

All rules additionally require:

- origin-frozen predictor available;
- origin-frozen `runoff_potential = false`.

H0:
- `r_last <= 0.10`.

H1:
- `r_last <= 0.20`.

H2:
- `trend <= 1.00`.

H3:
- `r_last <= 0.20`;
- `trend <= 1.25`.

No other thresholds may be added after exposure.

## Labels and calibration

Reuse the PREDICT01 large-step generation and the same frozen local SAFE definition:

- max endpoint head difference <=0.50 cm;
- ponding difference <=0.01 cm;
- runoff-depth difference <=0.01 cm;
- storage difference <=0.01 cm;
- full and two-half routes solve.

Use the same exposed 16-case calibration bank.

## Advancement

A rule advances only if:

- at least 10 labelled intervals;
- false-safe count = 0;
- safe coverage >=50%.

Choose highest safe coverage; tie-break H3, H2, H1, H0 in that order only when coverage is exactly equal.

If none advances, close the cheap accepted-history classifier family.

If one advances, freeze it before creating a new validation bank.

## Production boundary

No production source change and no timestep authority in this workunit.
