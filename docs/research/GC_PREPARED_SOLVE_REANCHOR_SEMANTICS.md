# Prepared-solve reanchoring and MODFLOW IMS history

Date: 2026-09-21
Status: RESEARCH SOURCE RECONCILIATION
MODFLOW authority: MODFLOW-ORG/modflow6 6.8.0
SWAP5 scope: read-only diagnosis of the current prepared-solve coupling route

## Observed problem

DSW-09 uses a transparent nonlinear storage law

```
V(x) = 0.15 x + 0.5 x^2
x = h - 8 m
V = 0.010 m
```

with exact root

```
h = 8.056155281280883 m.
```

Using the same coupling semantics as
`modflow6_groundwater_application_service.py`:

1. publish one affine tangent;
2. call one MODFLOW `solve()`;
3. evaluate the external nonlinear residual;
4. reanchor HCOF/RHS;
5. call `solve()` again in the same prepared solve;

the head reaches 8.056155281293620 m and then stalls. The head error is only
about 1.27e-11 m, but the exact nonlinear residual remains
-2.63e-12 m/day, above the fixed 1e-12 gate, while MODFLOW continues to report
`converged=false`.

A fresh prepared solve using the exact affine term from that stalled point
converges in two calls to the exact affine root. Fresh-session tests also solve
terms only 1e-12 m away from the nonlinear root.

Therefore the limitation is not the numerical resolution of HCOF/RHS itself.

## XMI iteration semantics

In MODFLOW 6.8.0 `srcbmi/mf6xmi.F90`:

`prepare_solve()` calls

```
bs%prepareSolve()
iterationCounter = 0
```

and each subsequent `solve()` performs

```
iterationCounter = iterationCounter + 1
bs%solve(iterationCounter, 0)
```

Thus an external change of HCOF/RHS does **not** create a new IMS outer
iteration sequence. It becomes the next `kiter` of the already prepared
numerical solution.

## Why kiter is not merely a counter

`NumericalSolution%solve(kiter,...)` passes `kiter` into, among other
things:

- backtracking;
- matrix/package formulation;
- the IMS linear solver;
- package convergence checks;
- nonlinear under-relaxation.

The current dummy harness uses `complexity="MODERATE"`, matching existing
live research fixtures unless otherwise declared.

MODFLOW 6.8.0 sets for MODERATE:

```
nonmeth = 3
theta   = 0.9
akappa  = 0.0001
```

`nonmeth=3` is delta-bar-delta nonlinear under-relaxation.

## Persistent delta-bar-delta state

In `NumericalSolution%sln_underrelax`, the delta-bar-delta arrays are
initialized only when

```
kiter == 1
```

including:

```
wsave  = 1
hchold = ...
deold  = 0
```

For later `kiter`, the new change is compared with and blended with state
from previous outer iterations.

That history is mathematically appropriate when IMS is iterating one fixed
nonlinear residual. It is not automatically appropriate if an external
coupler replaces the affine approximation itself between calls.

## Current SWAP5 application-service semantics

`src/adapter/modflow6_groundwater_application_service.py` currently follows
exactly this within-prepared-solve sequence:

```
publish_and_solve_iteration(current_terms)
trial SWAP at returned heads
evaluate coupled residual
if not jointly converged:
    discard candidates
    reanchor_terms(...)
    next solve() in same prepared solve
```

The route is transactionally coherent, but DSW-09 shows that solver-state
semantics and coupling-linearization semantics need separate qualification.

## Competing explanations

### A. IMS nonlinear-history contamination

Delta-bar-delta and/or other `kiter`-dependent state is valid for the old
tangent but is retained after the coupler changes HCOF/RHS. Repeated
reanchoring therefore changes the mathematical problem without resetting the
nonlinear acceleration history.

### B. More general prepared-solve state dependency

The effect could involve another `kiter`-dependent part of IMS or package
convergence rather than delta-bar-delta specifically.

### C. Coupling residual versus MODFLOW convergence mismatch

MODFLOW convergence certifies the currently assembled groundwater system,
while the coupler certifies an external SWAP/MODFLOW residual. The two stopping
criteria can legitimately close at different iterations. That alone, however,
does not explain why a fresh replay of the stalled affine term converges while
the in-place replay does not.

## Diagnostics

DSW-09N has already established that small affine corrections are resolvable
in fresh prepared solves.

DSW-09R replays every nonlinear reanchor using a fresh prepared solve.

DSW-09U compares the same within-prepared-solve reanchor sequence under IMS
MODERATE and SIMPLE. SIMPLE removes the MODERATE delta-bar-delta nonlinear
under-relaxation default while leaving the physical model and coupling law
unchanged.

These are post-observation numerical diagnostics, not blind physics tests.

## Decision boundary

Do not yet modify the production coupling service.

A production design decision needs to distinguish at least:

1. preserving one prepared solve and explicitly resetting only solver
   acceleration/history that is invalidated by a coupling reanchor;
2. treating each coupling reanchor as a new solve preparation while preserving
   the same candidate timestep state;
3. formulating the coupling so MODFLOW itself sees one fixed nonlinear residual
   throughout its outer-iteration sequence;
4. proving that the existing route is adequate within a declared response and
   tolerance envelope.

Option 2 in particular must not be implemented casually. `prepareSolve()`
and `finalizeSolve()` have model/package lifecycle semantics, so resetting
the solver is not equivalent to resetting a harmless iteration counter.
