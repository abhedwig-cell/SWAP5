# F-PE-STATESTEP03 result — pre-ponding safeguarded normalized controller

Date: 2026-09-28

Status: `CLOSED_PREPONDING_SAFEGUARD_NO_GAIN`

Authority:

- canonical base: `integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`;
- Actions run: `36416400214`;
- prep-pond-screen job: completed SUCCESS.

## Frozen candidate

Normalized accepted-step signal:

`r_h = max_i(|dh_i| / max(10 cm, |h_i|))`

with target `R=0.40`.

The existing post-surface safeguard was retained. Three preregistered pre-surface top-head thresholds were tested:

- -20 cm;
- -10 cm;
- -5 cm.

If the accepted top head exceeded the threshold, the next dt was capped at the current Reference DTMAX.

## Result

All three thresholds produced the same aggregate outcome:

- P-C1 pass: 14/16;
- median deterministic work reduction: about 34.3%;
- wet/ponding preservation: FAIL;
- advancement: FAIL.

No threshold improved the pass set or the work result relative to the parent RH_SURF R=0.40 controller.

## Interpretation

A simple accepted top-head threshold does not predict the sensitive transition early enough.

The controller can produce large work savings, but the two failing trajectories cannot be separated from safe trajectories using only:

- previous accepted normalized head movement;
- current accepted ponding/runoff state;
- current accepted top head with the tested thresholds.

The relevant information is therefore likely tied to within-step temporal defect, boundary transition prediction, or a richer multi-state/history signal rather than a one-step scalar accepted-state rule.

## Decision

No STATESTEP03 candidate advances.

Per preregistration, no further safeguard is added in this accepted-state controller family.
