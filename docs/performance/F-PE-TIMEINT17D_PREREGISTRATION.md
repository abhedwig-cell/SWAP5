# F-PE-TIMEINT17D preregistration — static-route dynamic-top residual/Jacobian attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17B: `TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`;
- TIMEINT17B secondary: `TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`;
- TIMEINT17C: `TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT`;
- TIMEINT17C secondary: `TIMEINT17C_SHARED_ROUTE_PATH_BLOCKER`.

Canonical authority at preregistration:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Question

Why do the shared dynamic-top endpoint solves fail while the provider remains on one route throughout Newton/backtracking?

TIMEINT17D distinguishes:

1. an algebraic mismatch between the static-route residual and the analytic Jacobian used by HeadCalc;
2. a correct provider derivative but incorrect embedding of that derivative in the top-row Jacobian;
3. a residual/Jacobian pair that is locally consistent but whose Newton/backtracking composition is insufficiently contractive;
4. a different shared static-route implementation defect.

This is an attribution work unit. It does not repair the solver.

## Frozen scope

Reuse the frozen TIMEINT17A2 fixtures and numerical settings.

No changes to:

- rain;
- initial head or ponding;
- dt ladders;
- MAXIT=8;
- backtracking limit=8;
- head, balance or ponding tolerances;
- conductivity staging;
- dynamic-top provider algebra;
- physical mass ledger;
- production source.

Primary routes remain:

- FLUX;
- HEAD;
- RUNOFF.

Both TG and matched KLAG remain diagnostic comparators where the same endpoint equation is exercised.

## Residual authority

For a fixed accepted origin and a fixed trial hydraulic-coefficient field, define the top-row endpoint residual exactly as the solver does after dynamic-top provider evaluation.

For top node 1:

`F_1(h_1) = storage_1(h_1) + internal_face_2(h_1,h_2) + top_boundary_term(h_1)`

with all non-top candidate variables held fixed for the scalar partial derivative audit.

For FLUX route:

`top_boundary_term = q_top`

and the fixed-route provider supplies an h-independent q_top under the frozen fixed-K authority.

For HEAD/RUNOFF route:

`top_boundary_term = -K_face * ((h_surf(h_1)-h_1)/d_1 + 1)`.

The provider publishes `dh_surf/dh_1`.

The HeadCalc analytic top-boundary Jacobian contribution is therefore expected to be:

`K_face/d_1 * (1 - dh_surf/dh_1)`.

The full top-row diagonal also contains:

- storage derivative;
- internal face contribution;
- no hidden derivative of fixed predicted K in SWKIMPL=0.

## P0 — provider derivative audit

For every frozen A2 material/route/dt fixture, at the accepted origin and at representative failed endpoint candidates:

1. evaluate the provider on the unperturbed candidate;
2. perturb only top pressure head by symmetric `epsilon`;
3. keep previous ponding, dt, forcing, fixed top-node conductivity and all other state fixed;
4. require both perturbed evaluations to remain on the same route;
5. compute central finite differences for:
   - surface head;
   - actual top flux;
   - candidate ponding;
   - runoff depth;
6. compare provider-reported `surface_head_dpressure_head_top` where available.

Use an epsilon ladder, not one arbitrary epsilon:

- `1e-4 cm`;
- `3e-5 cm`;
- `1e-5 cm`;
- `3e-6 cm`.

A derivative comparison is eligible only where all perturbations required by that estimate stay on the same route and remain provider-available.

## P1 — top-row residual/Jacobian finite-difference audit

Using the same fixed-route candidates, construct the exact scalar top-row residual composition corresponding to the endpoint equation.

For each eligible epsilon:

`J_FD = [F_1(h_1+epsilon)-F_1(h_1-epsilon)]/(2 epsilon)`.

Compare to the analytic top-row diagonal contribution assembled from the same:

- retention capacity;
- internal fixed-K face term;
- dynamic-top derivative term.

No Newton update is applied in this audit.

## Frozen metrics

Per fixture and route record:

- provider route;
- provider availability;
- provider derivative available;
- analytic `dh_surf/dh_1`;
- FD `dh_surf/dh_1`;
- analytic top-boundary derivative contribution;
- FD top-boundary derivative contribution;
- analytic full top-row diagonal;
- FD full top-row diagonal;
- absolute and relative mismatch;
- epsilon sensitivity;
- residual magnitude at the candidate.

Aggregate separately for FLUX, HEAD and RUNOFF.

## Frozen gates

### PROVIDER_DERIVATIVE_MISMATCH

Classify:

`TIMEINT17D_PROVIDER_DERIVATIVE_MISMATCH`

if >=25% of eligible HEAD/RUNOFF observations have no epsilon-stable provider derivative estimate within:

`max(1e-7, 1e-5 * |FD derivative|)`.

### TOP_JACOBIAN_MISMATCH

Classify:

`TIMEINT17D_TOP_JACOBIAN_MISMATCH`

if provider derivatives pass but >=25% of eligible static-route observations have full top-row Jacobian mismatch exceeding:

`max(1e-7, 1e-5 * |J_FD|)`.

### JACOBIAN_CONSISTENT_NONCONTRACTIVE

Classify:

`TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE`

if:

- provider derivative gate passes;
- >=90% of eligible full top-row observations pass the Jacobian tolerance;
- TIMEINT17C endpoint failure remains reproduced under unchanged solve settings.

### MIXED_STATIC_ROUTE_DEFECT

Otherwise:

`TIMEINT17D_MIXED_STATIC_ROUTE_DEFECT`.

## Route coverage gate

A positive attribution requires eligible FD observations from all three route families and at least three hydraulic materials.

If this coverage is not achieved without changing the frozen A2 fixtures:

`BLOCKED_TIMEINT17D_FD_COVERAGE`.

Do not redesign the bank post hoc inside D.

## Consequences

If provider derivative mismatch:

- next work targets provider derivative algebra only;
- no event localization;
- no Newton tuning.

If top Jacobian mismatch:

- next work targets HeadCalc/provider Jacobian embedding;
- any repair must be separately preregistered and independently requalified;
- no MAXIT/tolerance change.

If Jacobian-consistent noncontractive:

- event semantics are still not the immediate blocker;
- next work attributes Newton step/backtracking geometry, residual norm evolution and coupling of ponding algebraic state to the head solve;
- do not increase MAXIT as first response.

## Mass and transaction invariants

This audit is read-only/test-only.

No trial is committed.

No physical mass is synthesized.

No storage-derived boundary flux is introduced.

No accepted-state mutation occurs.

## Stop rules

TIMEINT17D does not:

- change production `src/**`;
- change MAXIT;
- change backtracking;
- change tolerances;
- change dt;
- freeze a route inside the production solver;
- localize events;
- introduce a new nonlinear solver;
- alter K staging;
- tune the bank after results.

## Production boundary

Research attribution only.

`LEGACY_NUMERICS` remains production default.
