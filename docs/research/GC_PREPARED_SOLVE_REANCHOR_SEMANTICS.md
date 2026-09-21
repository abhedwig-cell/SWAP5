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

## Resolved numerical decomposition

The initial observation could be explained by several mechanisms. The follow-up
diagnostics now separate them.

### Effect 1: MODERATE nonlinear under-relaxation history changes the reanchor path

DSW-09V holds the physical nonlinear storage law fixed and compares the same
within-prepared-solve reanchor sequence with and without MODERATE nonlinear
under-relaxation.

With the MODERATE default, the sequence stalls at approximately

```
h = 8.056155281293620 m
F_external = -2.63e-12 m/day
```

With nonlinear under-relaxation disabled, the same sequence reaches

```
h = 8.056155281280944 m
F_external = -1.25e-14 m/day
```

by the fourth coupling iteration.

This confirms that delta-bar-delta history is relevant when the external
coupler replaces the affine tangent between MODFLOW outer iterations. The
history belongs to the previous sequence of assembled equations and can alter
the trajectory after reanchoring.

### Effect 2: near-root strict residual certification can remain false

Removing nonlinear under-relaxation does not by itself make MODFLOW return
`converged=true` at the strict research settings.

DSW-09X sweeps the IMS residual closure while keeping the exact same physical
problem, reanchor sequence and no-under-relaxation setting:

```
rclose = 1e-15  -> no MODFLOW certificate
rclose = 1e-14  -> no MODFLOW certificate
rclose = 1e-13  -> certificate at coupling iteration 5
rclose = 1e-12  -> certificate at coupling iteration 5
```

All four variants reach the same physical head and the same external nonlinear
residual to the reported precision.

The distinction follows directly from the IMS strict convergence logic.
`ims_base_testcnvg` requires both the dependent-variable correction and the
linear residual to be within their respective closures. At the near-root
reanchor, the exact external response is already about

```
1.25e-14 m/day
```

away from zero. That is below the external DSW-09 physics gate of 1e-12 m/day
but still above an IMS `rclose` of 1e-14.

### Effect 3: fresh-solve success also depends on starting distance

DSW-09Y fixes one and the same affine equation at the near-root reanchor and
changes only the initial head of a fresh MODFLOW solve.

With `rclose=1e-15`:

```
start at 8.0 m
    -> converges in 2 calls to the affine root

start at 8.056155281280944 m
    -> remains uncertified for 100 calls
    -> head remains only about 6.0e-14 m from the affine root
```

With the same near-root start and `rclose=1e-13`, MODFLOW certifies the solve
in one call.

Therefore the earlier DSW-09N/DSW-09R fresh-session success must not be
interpreted as evidence for an unspecified hidden linear-solver history that is
cleared by `prepare_solve()`. Starting farther from the affine root changes
the floating-point path and allows the linear solver to land on an exactly
certifiable representation.

The remaining diagnosis is consequently more specific:

1. there **is** a demonstrated nonlinear-history effect from MODERATE
   delta-bar-delta under-relaxation across externally changed tangents;
2. there is a separate near-root floating-point/residual-certification effect;
3. no additional hidden prepared-solve linear-solver state is required to
   explain the current dummy observations.

## Why this matters for the coupling contract

The production service currently requires both

```
MODFLOW subsystem convergence
AND
external cell-flux residual convergence
```

before publication.

That conjunctive rule is structurally sound, but the tolerances and numerical
acceleration semantics must be qualified as separate objects.

A physically adequate coupled state can already satisfy the external
hydrological residual and mass gate while an unnecessarily strict subsystem
residual certificate remains false. Conversely, a green subsystem solve does
not prove that the coupled SWAP-MODFLOW residual or the complete water balance
is correct.

The coupling contract should therefore keep at least three criteria distinct:

1. MODFLOW numerical solve certification for the currently assembled system;
2. external SWAP-MODFLOW coupling residual;
3. physical mass/storage closure.

## DSW-05 supporting evidence

DSW-05 exposes the same distinction without nonlinear reanchoring.

For the irregular substep with `dt=0.13 day`, the analytic head is reproduced
to machine precision. Under-relaxation has no effect on the result. Changing
only IMS strict residual closure gives:

```
rclose = 1e-15 -> no certificate after 100 calls
rclose = 1e-14 -> certificate in 2 calls
rclose = 1e-13 -> certificate in 2 calls
```

Thus an extremely strict solver certificate can fail independently of physical
head accuracy even in a fixed linear problem.

## Restart/substep precision lesson from DSW-15

A separate harness issue initially looked like a memory/mass defect. A fresh
substep wrote the accepted previous head through a formatted MODFLOW input file,
rounding the state by several nanometres. The following substep then started
from a different physical state.

The harness now sets both X and XOLD directly through XMI after initialization
and before `prepare_time_step`. The original DSW-15 mass oracle then closes to
approximately machine precision.

This is not a MODFLOW coupling defect. It is evidence that restart/substep state
transfer itself is part of the conservation contract when very strict mass
oracles are used.

## Current production decision boundary

Do not modify the production coupling service from these dummy tests alone.

The research now supports more precise production questions:

1. Should MODFLOW nonlinear under-relaxation be active across external
   F-GC33 reanchors that replace the affine coupling response?
2. What independently justified numerical tolerance envelope should be used
   for MODFLOW subsystem convergence relative to coupling-flux and mass
   tolerances?
3. Can the existing production configuration be shown to remain well away from
   the near-root certification pathology over its admitted hydrological
   envelope?
4. If coupling acceleration is required, should it be owned explicitly by the
   outer coupling algorithm rather than implicitly inherited from a subsystem
   nonlinear accelerator whose residual is being changed externally?

A production change requires real F-GC application evidence in addition to
these analytic dummy oracles.

In particular, do not treat "fresh solve per reanchor" as the default repair.
`prepareSolve()` and `finalizeSolve()` have model/package lifecycle
semantics, and DSW-09Y shows that part of the apparent fresh-solve benefit came
from the changed starting distance rather than from the lifecycle reset itself.

