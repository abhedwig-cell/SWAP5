# F-PE-TIMEARCH14 closeout — trial-detected boundary-event controller

Date: 2026-09-28

Final status:

`CLOSED_BOUNDARY_EVENT_REFINEMENT_INSUFFICIENT`

## Architectural conclusion

Treating dynamic-top transitions as explicit numerical events is more defensible than static DTMAX tuning or pre-solve regime guessing.

However, a single full-step mode comparison plus two-half replacement is not yet robust enough.

The next valid design is a state-machine controller with a conservative fallback once the surface leaves the flux-controlled regime.

## Required successor

`F-PE-TIMEARCH15 — flux-regime AUTO with refined transition and legacy-safe fallback`.

No further global timestep ceiling tuning is authorized by this line.
