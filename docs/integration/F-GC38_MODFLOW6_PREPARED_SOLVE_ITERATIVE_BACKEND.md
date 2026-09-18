# F-GC38 — MODFLOW6 prepared-solve iterative backend

## Status

**DESIGN / IMPLEMENTATION AUTHORITY NOT YET QUALIFIED**

F-GC38 corrects the groundwater-backend model after direct inspection of MODFLOW6 6.8.0 XMI and solver code.

The key finding is that MODFLOW6 XMI is explicitly designed for external nonlinear coupling inside one prepared solve. The coupling backend therefore does not need to create and rollback a separate MODFLOW kernel candidate for every SWAP corrector iteration.

Instead, one MODFLOW timestep is prepared, one numerical solve is opened, and external coupling terms may be updated between successive MODFLOW nonlinear iterations.

## 1. Ownership

F-GC38 sits below the internal SWAP5–MODFLOW coupling service defined by F-GC37.

```text
iMOD Coupler
    |
    v
internal SWAP5-MODFLOW coupling service
    |
    +--> SWAP5 transactional participant
    |
    +--> F-GC38 MODFLOW6 prepared-solve backend
             |
             v
          MODFLOW6/XMI
```

iMOD Coupler does not own the predictor/corrector loop.

## 2. MODFLOW6 source evidence

Pinned target:

- MODFLOW6 release 6.8.0;
- `srcbmi/mf6xmi.F90`;
- `src/Solution/NumericalSolution.f90`;
- `src/Model/GroundWaterFlow/gwf.f90`.

The XMI documentation explicitly gives the intended external-coupling lifecycle:

```text
prepare_time_step()
prepare_solve()

while external nonlinear iteration is active:
    exchange_data()
    solve()
    solve_external_model()
    exchange_data()
    convergence_check()

finalize_solve()
finalize_time_step()
```

This is the authoritative lifecycle for F-GC38.

## 3. Accepted groundwater origin

During `prepare_solve()`, the groundwater model executes `gwf_ad()`.

For a normal step, `gwf_ad()` copies:

```text
X -> XOLD
```

once and then advances model/package state.

Storage terms are subsequently formulated using:

```text
hold = XOLD
hnew = X
```

Thus the accepted previous-time groundwater state is represented by fixed `XOLD`, while `X` is the current nonlinear iterate.

Repeated XMI `solve()` calls update `X`; they do not recopy `X` into `XOLD`.

Therefore the correct coupling interpretation is:

```text
accepted groundwater origin = prepared timestep state + fixed XOLD
candidate coupling iterate   = current nonlinear X
```

not:

```text
one independently rollback-able MODFLOW candidate per coupling iteration
```

## 4. Iterative boundary publication

F-GC34 affine boundary terms may change between successive `solve()` calls.

For coupling iteration `k`:

1. SWAP service supplies current affine response;
2. F-GC38 publishes the corresponding HCOF/RHS/NODELIST/NBOUND through the real F-GC34 bridge;
3. F-GC38 calls exactly one MODFLOW XMI `solve(solution_id)`;
4. current `X` is returned to the coupling service;
5. the service runs the SWAP corrector and evaluates the coupling residual;
6. if not converged, new affine terms are published and another `solve()` is executed inside the same prepared solve.

`prepare_solve()` is called once per coupling window and `finalize_solve()` once after coupled convergence.

## 5. Relation to F-GC35

F-GC35 remains valid for the one-shot package-publication smoke envelope used by F-GC36.

However, its `close_before_prepare_solve` one-publication guard is intentionally too strict for an iterative external nonlinear coupling.

F-GC38 therefore introduces a separate prepared-solve session rather than silently weakening F-GC35.

Shared semantics remain:

- exact XMI package identities;
- live NODELIST/HCOF/RHS/NBOUND arrays;
- F-GC34 as the sole typed publication authority;
- fail-closed package validation.

## 6. Backend state machine

```text
NEW
  |
  v
acquire_after_prepare_time_step()
  |
  v
PACKAGE_READY
  |
  v
open_prepared_solve()
  |
  v
SOLVE_OPEN
  |
  +--> publish_and_solve_iteration() --+
  |                                    |
  +------------------------------------+
  |
  v
finalize_prepared_solve()
  |
  v
SOLVE_FINALIZED
```

The backend does not call `finalize_time_step`. Final timestep acceptance belongs to the internal coupling-service transaction boundary.

## 7. Failure boundary

There is no XMI `abort_solve` or rollback method.

Therefore:

- failed/nonconverged coupling before `finalize_solve` MUST NOT be represented as a reusable accepted MODFLOW state;
- the prepared solve session is invalidated;
- retry of the entire coupling window requires a separately qualified timestep-restart/reconstruction path if such retry is required.

This is much narrower than requiring rollback after every outer coupling iteration.

MODFLOW's internal ATS retry mechanism does contain explicit state restoration through `iFailedStepRetry`, but that internal retry path is not exposed as an external XMI rollback contract and is outside the first F-GC38 envelope.

## 8. Live qualification

Use official MODFLOW6 6.8.0 `libmf6.so`, pinned xmipy and FloPy, and the real F-GC34 C bridge.

Construct a transient nonlinear 1x3 GWF model:

- one convertible layer;
- storage active;
- fixed-head cells at both ends;
- one API package on the middle cell.

### Q1 — one prepare solve

Prove `prepare_solve(1)` is called exactly once while three or more externally changed API responses are consumed through successive `solve(1)` calls.

### Q2 — fixed XOLD

Capture live `GWF_1/XOLD` immediately after `prepare_solve`.

Verify bitwise/numerically unchanged `XOLD` after every external coupling iteration while `X` changes.

### Q3 — live republishing

Use F-GC34 to publish three distinct affine responses A, B and C between solve calls.

Verify the same live API package receives each response without another `prepare_time_step` or `prepare_solve`.

### Q4 — convergence under final response

After A and B each receive one MODFLOW iteration, hold response C fixed and continue `solve(1)` until MODFLOW convergence.

### Q5 — clean-origin equivalence in qualified envelope

Run an independent fresh MODFLOW kernel from the same initial accepted state with only response C.

The converged final head vector from the A→B→C iterative path must equal the clean C-only path within strict tolerance.

This proves that, for the qualified transient NPF+STO+API envelope, earlier external nonlinear iterates do not change the accepted previous-time state or the final converged solution under the final affine response.

### Q6 — finalize exactly once

Call `finalize_solve(1)` exactly once after convergence.

The production backend must not call `finalize_time_step`.

## 9. Explicit exclusions

F-GC38 does not:

- put predictor/corrector logic in iMOD Coupler;
- perform SWAP scientific trials;
- define coupling convergence;
- implement whole-timestep rollback/retry;
- expose MODFLOW ATS retry as an external transaction API;
- couple Ribasim;
- implement irrigation;
- admit to canonical.

## 10. Next bounded step

If the live prepared-solve envelope qualifies, reconcile F-GC37's groundwater-participant abstraction:

- replace per-iteration rollback-able groundwater candidates with one prepared MODFLOW solve session;
- retain fixed accepted-time origin through `XOLD`;
- keep SWAP correctors transactional from one SWAP accepted origin;
- keep whole-window failure/retry as a separate backend restart concern.

Only then materialize the real internal SWAP5–MODFLOW coupling service.
