# F-PE-TIMEINT17D result — static-route residual/Jacobian attribution

Date: 2026-09-29

Status:

`TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36532378914`;
- job: `109288729407`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17D asked whether the shared static-route endpoint failures identified by TIMEINT17B/C are caused by:

1. dynamic-top provider derivative algebra;
2. embedding of that derivative in the HeadCalc top-row Jacobian;
3. a locally consistent residual/Jacobian pair that nevertheless does not contract under the current Newton/backtracking composition.

No solver setting, tolerance, timestep, forcing, conductivity staging or physical equation was changed.

## Provider derivative certificate

Coverage:

- 4 hydraulic materials;
- HEAD and RUNOFF derivative-bearing routes;
- 32 eligible HEAD/RUNOFF material-dt fixtures;
- 4 epsilon levels per fixture.

Observed provider derivative mismatch fixtures:

`0 / 32`

Provider mismatch fraction:

`0.0`

Representative best absolute errors are order `1e-15 .. 1e-13`, with relative errors far below the frozen `1e-5` criterion.

Therefore:

`surface_head_dpressure_head_top`

is numerically consistent with the finite-difference derivative of the provider output on the frozen static routes.

FLUX correctly carries no surface-head derivative authority.

## Full top-row residual/Jacobian certificate

Coverage:

- FLUX, HEAD and RUNOFF;
- B01, B12, O05 and O14;
- 48 eligible material/route/dt fixtures;
- 4 epsilon levels per fixture.

Observed top-row Jacobian mismatch fixtures:

`0 / 48`

Mismatch fraction:

`0.0`

The absolute FD difference grows with the scale of the diagonal on fine dt, as expected from subtractive finite-difference error, while relative errors remain very small, approximately order `1e-11 .. 1e-9`.

Examples:

- B01/FLUX, dt 0.00025 d: relative error about `9.7e-11`;
- B12/HEAD, dt 0.00003125 d: about `2.7e-10`;
- O05/RUNOFF, dt 0.00003125 d: about `1.5e-10`;
- O14/RUNOFF, dt 0.00003125 d: about `6.0e-10`.

All pass the preregistered relative tolerance by several orders of magnitude.

## Classification

Frozen classification:

`TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE`

The shared dynamic-top endpoint blocker is not explained by:

- route switching;
- provider availability;
- provider surface-head derivative algebra;
- top-row dynamic-boundary Jacobian embedding.

The residual/Jacobian pair is locally consistent on all three static route families.

## Combined TIMEINT17 attribution chain

The current chain is now:

1. TIMEINT17A:
   `BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`
2. TIMEINT17A2:
   `BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT`
3. TIMEINT17B:
   `TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`
   and `TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`
4. TIMEINT17C:
   `TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT`
   and `TIMEINT17C_SHARED_ROUTE_PATH_BLOCKER`
5. TIMEINT17D:
   `TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE`

This sequence rules out progressively broader event/provider/Jacobian explanations without changing the solver.

## Interpretation

The immediate research target is now Newton/backtracking geometry itself.

The next work must determine, on the same failed static-route trials:

- residual norm before and after each Newton proposal;
- raw Newton step norm;
- backtracking scaling sequence;
- whether accepted backtracking trials actually reduce the residual;
- whether head or ponding constraints trigger clipping/rejection;
- whether repeated trial states cycle or stagnate;
- whether failure is dominated by one route family or shared across FLUX/HEAD/RUNOFF.

A larger MAXIT value is not an attribution method and is not authorized as the next step.

## Required successor

Open:

`F-PE-TIMEINT17E — static-route Newton/backtracking geometry attribution`.

TIMEINT17E is diagnostic only.

No production repair follows automatically from D.

## Mass and transaction consequence

No failed endpoint trial is accepted.

No failed-trial state or physical mass is published.

TIMEINT17D is a read-only derivative audit and introduces no state or mass semantics.

## Production boundary

No production `src/**` change.

No event localization.

No timestep-controller work.

No MAXIT, backtracking or tolerance change.

`LEGACY_NUMERICS` remains production default.
