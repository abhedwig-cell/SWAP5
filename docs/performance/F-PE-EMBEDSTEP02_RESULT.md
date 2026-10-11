# F-PE-EMBEDSTEP02 result — Reference-owned hybrid split controller

Date: 2026-09-28

Status: `CLOSED_SAFE_BUT_INSUFFICIENT_GAIN`

Authority:

- canonical base: `integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`;
- Actions run: `36417521067`;
- hybrid-split-screen job: `108912105485`;
- conclusion: SUCCESS.

## Frozen architecture

Inside the existing Reference timestep envelope, historical TimeControl remained owner.

Only when the normalized accepted-state signal requested dt > 0.02 d did the hybrid path activate.

Large requested intervals were executed as two sequential half intervals. No speculative full solve was performed.

## Result

- P-C1 pass: 15/16;
- every WET/POND screening case passed;
- median split intervals: 2 per case;
- median deterministic work reduction: about 5.7%;
- required work reduction: 15%;
- advancement: FAIL.

The sole failing case was B12/TRANSITION, which entered a solver nonconvergence path at DTMIN.

## Interpretation

Keeping historical TimeControl authoritative inside its current envelope solves most of the trajectory-preservation problem.

Selective splitting also avoids the large speculative overhead seen in EMBEDSTEP01.

However, once the work of the two half solves is counted, only about 5.7% median deterministic work remains. This is too small to justify a second timestep-control architecture and its complexity.

## Decision

Do not advance the hybrid split controller.

Per preregistration, no further controller rescue is permitted in this workunit.
