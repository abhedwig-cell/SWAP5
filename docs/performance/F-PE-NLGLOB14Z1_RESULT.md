# F-PE-NLGLOB14Z1 result — late-retreat timestep refinement

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB14Z1_REFINEMENT`

with preserved complete-ladder partial evidence at dt >= 3.125e-5 d.

Qualification authority:

- refinement run: `36610958316`;
- finest-dt attribution run: `36611358172`;
- finest-dt attribution job: `109553298440`.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`.

## Frozen question

Is the accepted physical late retreat:

`7:16 -> 8:16`

reproducible and timestep-refined on the preregistered complete four-level control ladder down to dt=1.5625e-5 d?

## Aggregate classification

The frozen aggregate classification is:

`BLOCKED_NLGLOB14Z1_REFINEMENT`.

The newly added finest dt does not complete the frozen 2.80 d horizon in either route family.

## Complete levels

The three retained levels remain complete, finite, mass-clean and geometrically consistent.

HEAD event times:

- dt 1.25e-4 d: 2.442875 d;
- dt 6.25e-5 d: 2.442875 d;
- dt 3.125e-5 d: 2.442875 d.

RUNOFF:

- dt 1.25e-4 d: 2.439750 d;
- dt 6.25e-5 d: 2.4396875 d;
- dt 3.125e-5 d: 2.43971875 d.

All expose exact accepted contiguous transition:

`7:16 -> 8:16`.

No reverse transition, skip or noncontiguous state occurs on these complete levels.

## Finest-level failure

At dt=1.5625e-5 d both route families fail long before the late retreat.

HEAD:

- failure time: about 0.171609375 d;
- last accepted time: about 0.17159375 d;
- accepted saturated tail at failure origin: nodes 5:16;
- top route: surface-flux;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: `SW_SOLVE_RETRY_ADVISED`.

RUNOFF:

- failure time: about 0.16509375 d;
- last accepted time: about 0.165078125 d;
- accepted saturated tail at failure origin: nodes 5:16;
- top route: surface-flux;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: `SW_SOLVE_RETRY_ADVISED`.

Both states remain finite and physical mass remains near roundoff.

## Solver-mechanism attribution

The reference Richards binding maps solver status 2 to `SW_SOLVE_RETRY_ADVISED`.

In HeadCalc, after normal nonlinear-loop exhaustion without convergence and while not at the minimum timestep, the solver:

1. restores the previous accepted soil state;
2. sets `fldecdt=.TRUE.`;
3. sets worker `request_dt_reduction=.TRUE.`;
4. returns the retry request.

Thus the finest-level failure is specifically a nonlinear-convergence retry request after rollback.

It is not caused by:

- physical mass failure;
- noncontiguous saturation;
- h/theta saturation inconsistency;
- dynamic-top route failure;
- late-retreat event ambiguity;
- process crash.

## Non-monotone timestep behavior

This behavior is numerically non-monotone.

The dt=3.125e-5 level completes 2.80 d and reaches the late retreat, while the smaller dt=1.5625e-5 level requests timestep reduction around 0.17 d.

Therefore “smaller fixed dt is automatically more robust” is falsified for this persistent-KLAG control trajectory.

The cause is not yet attributed below the HeadCalc nonlinear-convergence/retry layer.

## Scientific consequence

NLGLOB14Z1 cannot qualify the preregistered four-level late-retreat refinement because the finest level never reaches the event.

The three complete levels nevertheless preserve strong evidence that the late retreat is real and temporally stable.

The next bounded research question is the non-monotone retry mechanism at dt=1.5625e-5.

Do not repair this with MAXIT/BALTOL tuning.

A successor may test whether a single transaction-safe subdivision of the failed interval restores accepted progress, and whether that behavior is local or persistent, without changing the accepted physical trajectory or forcing.

## Production boundary

Research only.

No production `src/**` change.

No production temporal-ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
