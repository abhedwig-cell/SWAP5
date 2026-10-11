# F-PE-TIMEINT17C result — in-Newton dynamic-top route-path attribution

Date: 2026-09-29

Status:

`TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT`

Secondary attribution:

`TIMEINT17C_SHARED_ROUTE_PATH_BLOCKER`

Canonical base incorporated before result write:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36531654069`;
- route-path-attribution job: `109286449150`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17C asked whether the shared dynamic-top endpoint failures identified by TIMEINT17B are caused by:

1. route switching/chatter inside Newton/backtracking;
2. failure while the provider remains on a single physical route;
3. provider availability/invalid-state failure.

No solver setting, timestep, forcing, conductivity staging, tolerance or physical equation was changed.

## Result

All 48 TG A2 terminal endpoint failures are:

`STATIC_ROUTE_ENDPOINT_FAILURE`.

Aggregate TG diagnostics:

- endpoint failures: 48;
- static-route fraction: 1.0;
- route-switch fraction: 0.0;
- provider-availability fraction: 0.0;
- total dynamic-top provider evaluations: 1161;
- total route transitions across those evaluations: 0;
- provider unavailable evaluations: 0;
- OTHER route evaluations: 0.

The frozen primary classification is therefore:

`TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT`.

## TG versus KLAG

All 48 matched KLAG endpoint failures have the same route-path class:

`STATIC_ROUTE_ENDPOINT_FAILURE`.

Matched same-class pairs:

`48/48`.

Shared route-path fraction:

`1.0`.

The frozen secondary classification is therefore:

`TIMEINT17C_SHARED_ROUTE_PATH_BLOCKER`.

## Interpretation

The dynamic-top endpoint failure is not caused by in-Newton FLUX/HEAD/RUNOFF switching.

It is also not caused by provider unavailability.

The provider remains on one well-defined physical route throughout each failed nonlinear solve.

The blocker is therefore inside the shared static-route endpoint equation/Jacobian/convergence composition.

This result strengthens TIMEINT17B:

- TIMEINT17B showed that the endpoint blocker is shared by TG and KLAG;
- TIMEINT17C shows that the shared blocker persists even when the boundary route is static throughout Newton/backtracking.

Therefore event localization is not the next repair.

A failed static-route endpoint solve must be understood before route-event qualification can resume.

## Mass and transaction consequence

No failed endpoint trial is accepted.

No failed-trial state or mass is published.

Previously accepted physical intervals retain the existing mass authority.

No history mass, storage-derived external flux or event debt is introduced.

## Next work unit

Open:

`F-PE-TIMEINT17D — static-route dynamic-top residual/Jacobian attribution`.

TIMEINT17D must keep the frozen A2 fixtures and numerical settings and determine whether the static-route endpoint failure is caused by:

1. an algebraic mismatch between the dynamic provider route equation and the solver residual;
2. an inconsistent or missing surface-head derivative/Jacobian term;
3. a residual/Jacobian that is internally consistent but insufficiently contractive under the current Newton/backtracking composition;
4. another shared static-route implementation defect.

No MAXIT or tolerance tuning belongs to TIMEINT17D.

## Production boundary

Research attribution only.

No production `src/**` change.

No event localization.

No adaptive timestep work.

`LEGACY_NUMERICS` remains production default.
