# PPA-WU05-A26 preregistration — bounded RFM serialized-backend dispatch

Date: 2026-10-01
Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS
Baseline: integration/f-ci-canonical@acdcccfd1ad95bb3693524907b378d8e06d33475

## Purpose
Replace the A20 RFM NOT_ADMITTED guard only together with an actual serialized-backend dispatch to the canonically admitted A25 orchestrator and A24 Richards source seam.

## Required same-postimage behavior
For FMR_OPTIONAL_STATE_LAYOUT_RFM:
- require valid explicit rfm_configuration and rfm_surface forcing;
- require fmr_b110_rfm_state_t committed/candidate carrier;
- derive only the A15/A16 eligible unponded, runoff-free flux route;
- invoke A11-A25 composition from accepted state;
- bind A25 matrix internal transfers through A24 source_sink_provider;
- run the existing Reference Richards solver;
- publish matrix candidate plus RFM candidate only on successful trial;
- account MB deep receipt exactly once as external output;
- rejected/retry trials leave committed state unchanged;
- ponded/head-controlled/runoff-active cases remain fail-closed;
- legacy/zero-RFM Reference path remains unchanged.

## Hard rule
Deleting the guard without demonstrable RFM dispatch is forbidden.

## Qualification
A focused serialized-backend fixture must prove:
1. RFM layout actually changes candidate fast state under eligible forcing;
2. whole-column mass closes;
3. accepted origin is immutable;
4. replay is bit-identical;
5. deep receipt is externally accounted exactly once;
6. unsupported surface regime is rejected;
7. non-RFM template follows unchanged Reference route.

Stop on any ownership ambiguity rather than adding a second surface/runoff law.
