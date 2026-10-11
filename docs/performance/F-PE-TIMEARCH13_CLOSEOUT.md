# F-PE-TIMEARCH13 closeout — look-ahead boundary-risk discovery

Date: 2026-09-28

Final status:

`CLOSED_LOOKAHEAD_BOUNDARY_RISK_NOT_SELECTIVE`

## Decision

Cheap pre-solve prediction of dynamic-top boundary risk does not provide enough discrimination for AUTO_REFERENCE.

The architectural seam remains valid. The candidate algorithm is rejected.

## Required successor

`F-PE-TIMEARCH14 — trial-detected boundary-transition refinement`.

TIMEARCH14 should:

- keep the normalized accepted-state proposal;
- use no normal operating DTMAX;
- execute one candidate full step;
- compare candidate final surface-boundary mode with the last accepted mode;
- only when the mode changes, discard the full candidate and replace it transactionally with two half steps;
- count all discarded and refinement work;
- leave safe same-mode large steps at one solve;
- preserve hard-event and retry ownership;
- remain research-only until independent validation.

## Production boundary

No production timestep behavior changes.
