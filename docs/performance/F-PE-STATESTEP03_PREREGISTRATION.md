# F-PE-STATESTEP03 preregistration — pre-ponding safeguarded normalized controller

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`.

Parent: F-PE-STATESTEP02.

## Frozen controller

Use the STATESTEP02 normalized signal:

`r_h = max_i(|dh_i| / max(10 cm, |h_i(t0)|))`

with fixed target:

`R = 0.40`.

Base dt rule remains:

`factor = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`

`dt_next = clamp(dt*factor,DTMIN,4*DTMAX_reference)`.

Keep the existing post-surface safeguard.

Add one causal pre-surface safeguard using only the accepted origin state for the next step:

if top pressure head `h_top(t1)` exceeds a threshold, cap next dt at Reference DTMAX.

Frozen thresholds screened independently:

- -20 cm;
- -10 cm;
- -5 cm.

No rainfall/material/regime lookup is allowed.

## Calibration and gates

Reuse the exposed 16-case calibration bank.

P-C1 unchanged.

A threshold advances only if:

- >=15/16 P-C1 pass;
- every WET/POND case passes;
- median deterministic work reduction >=15%;
- no retry pathology.

Select highest median work reduction; tie-break the more conservative threshold.

If none advances, close the accepted-state controller line. No additional rescue rule is permitted.

If one advances, freeze it before a new validation bank is defined.
