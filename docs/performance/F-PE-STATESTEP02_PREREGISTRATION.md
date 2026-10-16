# F-PE-STATESTEP02 preregistration — normalized accepted-step head controller

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`.

Parent: F-PE-STATESTEP01, which rejected absolute max|dh| because it over-refined strongly negative-head dry states.

## Controller signal

After an accepted step compute:

`r_h = max_i ( |h_i(t1)-h_i(t0)| / max(10 cm, |h_i(t0)|) )`.

The 10 cm denominator floor is frozen before results. It prevents singular behavior near saturation while making the signal dimensionless and relative in dry states.

For target `R`:

`factor = clamp(sqrt(R / max(r_h,1e-12)), 0.5, 2.0)`

`dt_next = clamp(dt * factor, DTMIN, 4*DTMAX_reference)`.

First step uses the Reference geometric initial dt. Failure reduction remains unchanged.

Two families:

- RH_ONLY;
- RH_SURF: same controller, but if accepted ponding >0 or runoff depth >0, cap next dt at Reference DTMAX.

Frozen targets:

- 0.025;
- 0.05;
- 0.10;
- 0.20;
- 0.40.

## Calibration

Use the already exposed BOFEK01 16-case screening bank.

P-C1 gates remain unchanged.

Candidate advances only if:

- >=15/16 P-C1 pass;
- all WET/POND cases pass;
- median deterministic work reduction >=15%;
- no retry pathology.

Select highest median work reduction, tie-break lower R, then RH_SURF.

If no candidate advances, close this controller family. Do not add another normalization within STATESTEP02.

If one advances, freeze it before creating a new validation bank.
