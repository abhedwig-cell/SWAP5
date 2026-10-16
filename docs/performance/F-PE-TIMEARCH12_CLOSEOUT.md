# F-PE-TIMEARCH12 closeout — AUTO_REFERENCE effort-only discovery

Date: 2026-09-28

Final status:

`CLOSED_EFFORT_ONLY_AUTO_CONTROLLER_REJECTED`

## Decision

TIMEARCH12 confirms that the new timestep architecture should not simply replace legacy NUMBIT logic with a continuous nonlinear-iteration formula.

The architecture remains qualified.

The tested algorithm does not.

## Architectural implication

AUTO_REFERENCE needs a signal tied more directly to temporal/state evolution and process-regime risk.

Required successor:

`F-PE-TIMEARCH13 — state-and-boundary-risk AUTO_REFERENCE controller discovery`.

TIMEARCH13 should:

- use no soil/material/regime identifiers;
- use no normal operating DTMAX;
- combine accepted-state evolution with dynamic-top boundary-risk information;
- keep retry ownership unchanged;
- retain exact hard-event scheduling;
- use LEGACY_NUMERICS as fallback/comparator;
- remain research-only until independent validation.

## Production boundary

No production timestep behavior changes.
