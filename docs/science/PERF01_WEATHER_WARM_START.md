# Weather solver warm start

Status: proposed numerical implementation, 22 October 2026.
Baseline: PR1361 at `3e23aa83de6637a8460e080e023abde89bca8127`.

The bounded weather Full Richards route may reuse a previous trial head as a
Newton initial guess when the immutable physical origin, geometry, hydraulic
parameters and forcing match. Scale its displacement from that origin by the
new/previous duration, only for equal or shorter same-origin trials. A previous
successful endpoint may also predict a continuation, only when its entire head,
water content, ponding and groundwater exactly match the new physical origin,
with unchanged geometry/parameters/forcing and duration at most twice the old
duration. The committed head,
water content, ponding, groundwater, root uptake and all accepted receipts remain
the original request. Recompute candidate water content and all hydraulic and
boundary terms. Never substitute a rejected endpoint for committed storage.

The cache belongs to the existing worker's Reference workspace. Clear its valid
flag before every external application interval; it is absent from physical
checkpoints and restart. No cache inheritance between columns, changed forcing,
changed geometry or changed hydraulic configuration is allowed. Direct solver
calls additionally compare their physical/forcing/parameter key. Default false
in the general solver numerical configuration and in the weather parameter
`weather_trial_warm_start`. An explicit selection enables the weather composition;
unrelated solver paths and RossFast scope stay unchanged. Before Newton, evaluate
both initial residuals. The predictor must reduce the squared residual norm by
at least a factor 100 to receive its bounded warm budget; otherwise use cold.

A failed warm solve is followed by one cold solve from an independently rebuilt
request state. The warm phase is capped at three Newton iterations (and the
existing bounded corner phase); the cold phase keeps the original limits and
unchanged physical convergence tests; diagnostics include all attempted work.
Cold corner fallback remains available. Prescribed source/root providers only;
head-dependent or unrecognized providers retain the cold route. There is no relaxed mass gate or new
acceptance shortcut. A warm solve may change the numerical path, so preservation
requires physical error/flux/refinement evidence, not a promise of bit identity.

Affected invariants: 3,5,7,8,13,23,24,25,26,30. This is numerical initialization,
not a different retention law, surface law or time-acceptance policy. Research
compares the same 97-day 1x/4x weather, with a dedicated view of day84 at 1e-3 cm.
That value is a comparison point, not an adopted production tolerance.

Seasonal screening requires independent daily gross closure below 1e-8 mm,
warm/cold daily storage spread at most 0.01 mm and total runoff and bottom
exchange differences at most 0.05 mm, with crop biomass/LAI/transpiration within
1e-10 in this prescribed-uptake fixture. These comparison thresholds do not
replace or relax the unchanged native water/temporal acceptance gates. Head
differences remain diagnostics, especially in algebraically saturated cells.

Required local checks: real production warm/cold driver, immutable request,
changed-base/forcing/parameter cache rejection, failed-warm cold fallback,
forced rejection/rollback, cache clear/restart, O0/O2 and full-horizon independent
gross water closure. Repeated paired CPU observations follow successful physical
screening. Existing source-owner admission is still unresolved; no canonical
admission follows from this implementation alone.
