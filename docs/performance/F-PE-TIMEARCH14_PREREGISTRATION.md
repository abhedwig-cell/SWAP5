# F-PE-TIMEARCH14 preregistration — trial-detected dynamic-top boundary events

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@133cf2693a911f2c3ab1a1b0c2dbeb17c14e4672`

Parent authority:

- TIMEARCH01-11: timestep architecture and AUTO_REFERENCE interfaces qualified;
- TIMEARCH12: effort-only automatic controller rejected;
- TIMEARCH13: pre-solve dynamic-top boundary-risk prediction rejected as insufficiently selective;
- BOFEK/STATESTEP evidence: normalized accepted-state movement exposes substantial large-step performance headroom;
- DYNERR01: severe false-safe traced to within-step dynamic-top regime-path change.

## Purpose

Test a controller architecture that treats detected dynamic-top regime changes as numerical events.

The controller does not need to predict the transition before the trial.

Instead:

1. propose a large step from accepted-state evolution;
2. execute one transactional candidate trial;
3. inspect the candidate final surface-boundary mode;
4. when the mode differs from the previous accepted mode, do not commit the full candidate;
5. replace the interval with two sequential half-step solves from the same accepted origin;
6. commit only the refined endpoint.

Safe same-mode large steps therefore pay no refinement overhead.

Research-only. No production activation.

## Base proposal

Use the normalized accepted-state signal:

`r_h = max_i(|h_i(k)-h_i(k-1)| / max(10 cm, |h_i(k-1)|))`

with frozen target:

`R = 0.40`.

Base factor:

`f = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`.

No normal operating DTMAX.

Internal bootstrap:

`dt0 = 0.005 d`.

Internal retry floor:

`0.001 d`.

Rejected attempts do not update accepted proposal memory.

## Surface mode

Each converged accepted/trial endpoint is classified into one of:

- FLUX;
- HEAD_NO_RUNOFF;
- HEAD_RUNOFF.

HEAD_RUNOFF means dynamic-top head regime with positive resolved runoff depth.

The first accepted step establishes the previous accepted mode.

## Transition refinement

For every subsequent full candidate:

- if candidate final mode equals previous accepted mode:
  - commit full candidate;
- if candidate final mode differs:
  - discard the full candidate;
  - execute half1 over dt/2 from accepted origin;
  - execute half2 over dt/2 from half1 endpoint;
  - commit only the half2 endpoint;
  - count full-candidate work plus both half-step solve work.

Every substep must pass the unchanged ledger gate.

If full or refined solves fail:

- rollback;
- retry outer interval at half duration;
- accepted-state controller history remains unchanged.

## Post-transition proposal memory

Two frozen variants:

### RESET

After refined transition interval, proposal base becomes `dt/2` before applying the normalized state-change factor.

### RETAIN

After refined transition interval, proposal base remains the pre-transition preferred-step memory before applying the normalized state-change factor.

Outside transition refinement, both variants update proposal memory normally from the accepted full step.

Candidate matrix:

- TRANSITION_RESET
- TRANSITION_RETAIN

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

Comparator:

LEGACY_NUMERICS current corrected Reference route.

P-C1 gates remain unchanged.

## Advancement

Candidate advances only if:

1. >=15/16 P-C1 pass;
2. all WET/POND cases pass;
3. median total deterministic work reduction >=15%, including discarded full trials and refinement solves;
4. no hydrologic regime has median work regression >5%;
5. retry-work fraction is no more than 5 percentage points above LEGACY_NUMERICS;
6. every committed transition-refined interval has complete mass/ledger accounting.

Selection:

- higher median work reduction;
- tie-break RESET over RETAIN.

If neither advances, close event-detected refinement as insufficient.

If one advances, freeze it before creating any new validation bank.

## Production boundary

No production timestep behavior, parser or AUTO_REFERENCE activation changes in TIMEARCH14.
