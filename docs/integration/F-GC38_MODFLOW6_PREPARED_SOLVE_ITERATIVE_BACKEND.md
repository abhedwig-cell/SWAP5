> Authority reconciliation: F-GC38 is rematerialized from current canonical after F-GC34, F-GC35 and F-GC36 are closed. The production prepared-solve adapter is byte-identical to the historical owner-qualified F-GC38 implementation. Predictor/corrector ownership remains in the internal SWAP5–MODFLOW coupling service below iMOD Coupler; F-GC38 owns only the MODFLOW prepared-solve backend lifecycle.

# F-GC38 — MODFLOW6 prepared-solve iterative backend

## Status

**CURRENT-CANONICAL LIVE REQUALIFICATION — pending gate**

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

### Q5 — clean-origin numerical path equivalence in qualified envelope

Run an independent fresh MODFLOW kernel from the same initial accepted state with only response C.

The converged final head vector from the A→B→C iterative path must equal the clean C-only path within a floating-point path-equivalence guard of `sqrt(epsilon(real64)) * max(1, |H|)`. This is a numerical qualification guard, not a hydrological acceptance tolerance.

This proves that, for the qualified transient NPF+STO+API envelope, earlier external nonlinear iterates do not materially alter the accepted previous-time state or the final converged solution under the final affine response.

### Q6 — finalize exactly once

Call `finalize_solve(1)` exactly once after convergence.

The production backend must not call `finalize_time_step`.

### Q7 — fail closed at MODFLOW MXITER

Acquire live `MXITER` from `SLN_<solution_id>` when the prepared solve opens.

Refuse `MXITER+1` before calling `solve()`. This prevents an external coupling loop from driving MODFLOW outside its configured nonlinear-iteration envelope.

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

## 10. Qualified live evidence

The owner qualification uses the official MODFLOW6 6.8.0 Linux release, pinned xmipy and FloPy, and the real F-GC34 C bridge.

Green workflow evidence:

```text
run 35291325119
job 105434578628
head fc8f750fa900beb083849b0100db6e510e66e190
conclusion success
```

The live transient NPF+STO+API envelope demonstrated:

- exactly one `prepare_solve` for the coupled window;
- a fixed `XOLD` through all external nonlinear iterations;
- evolving current `X`;
- real F-GC34 HCOF/RHS republishing between successive `solve` calls;
- MODFLOW convergence under the final external response;
- exactly one `finalize_solve`;
- zero backend calls to `finalize_time_step`;
- explicit fail-closed enforcement of the live IMS `MXITER` value before another XMI `solve` call.

The A→B→C path and an independent fresh C-only kernel started from identical accepted `XOLD` and converged to:

```text
iterative: [0.9, 0.6072738889883155, 0.2]
clean:     [0.9, 0.6072738893643476, 0.2]
max |dH| = 3.7603209435133067e-10 m
```

Both final-response paths were additionally continued until their successive head changes were below approximately `5e-13 m`.

For comparison of two independent nonlinear iteration paths, the qualified numerical equivalence tolerance is:

```text
sqrt(machine_epsilon_float64) * max(1 m, head scale)
= 1.4901161193847656e-08 m for this case
```

The measured path spread is about forty times smaller than this threshold.

This tolerance is a numerical-equivalence criterion for independently converged nonlinear paths; it is not a hydrological accuracy tolerance.

## 11. Qualification history and rejected alternatives

The qualification retained the following failed experiments as evidence:

1. An initial overly tight direct path-equality threshold exposed the measurable `3.76e-10 m` nonlinear-path spread.
2. Continuing both final-response paths beyond MODFLOW's first convergence flag showed stabilization below `5e-13 m`, while the same `3.76e-10 m` inter-path spread remained.
3. Extremely strict IMS head/residual criteria caused an out-of-envelope repeated-XMI-solve route and exposed that external callers must respect MODFLOW `MXITER`.
4. After adding the live `MXITER` guard, the same overly strict criteria failed normally instead of overrunning the solver.
5. An isolated `rclose=1e-12` experiment proved unsuitable for this live case because a fresh C-only kernel did not report convergence inside the allowed outer-iteration budget.

These rejected variants are not production requirements.

The admitted envelope uses the normal convergent IMS settings from the live reference case plus the explicit `MXITER` guard.

## 12. Remaining failure/retry boundary

F-GC38 does not prove whole-window rollback after an abandoned prepared solve.

If coupling fails before accepted timestep publication:

- the prepared-solve session is invalid;
- it must not be reused as accepted groundwater state;
- a retry with a smaller whole coupling window requires a separately qualified reconstruction/restart route.

This does not affect repeated nonlinear coupling iterations inside a successful prepared solve; those are the intended MODFLOW XMI usage and are now qualified.

## 13. Next bounded step

Reconcile F-GC37's groundwater-participant abstraction against this qualified backend:

- replace the per-outer-iteration rollback-able groundwater-candidate model with one prepared MODFLOW solve session;
- treat fixed `XOLD` as the accepted previous-time groundwater origin;
- treat `X` as the evolving groundwater nonlinear iterate;
- retain transactional same-origin SWAP correctors;
- retain whole-window failure/retry as a separate restart concern;
- keep predictor/corrector ownership entirely below iMOD Coupler.

Only after that reconciliation should the real internal SWAP5–MODFLOW coupling service be materialized.


## 11. Qualified live evidence

Owner qualification head:

`fc8f750fa900beb083849b0100db6e510e66e190`

GitHub Actions run `35291325119`, job `105434578628`: **SUCCESS**.

Pinned runtime evidence:

- official MODFLOW6 6.8.0 Linux release asset SHA-256: `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`;
- pinned xmipy commit `9769f8cd4bc6153c71bcc360f602a931b102d902`;
- pinned FloPy commit `1a783da6582f8203190a8d6b1d7a60659022afdb`;
- real F-GC34 C bridge built in the gate.

Measured live results:

- one `prepare_solve` per coupling window: PASS;
- `XOLD` unchanged through all external iterations: PASS;
- `X` evolves through the prepared solve: PASS;
- repeated live F-GC34 publication between `solve()` calls: PASS;
- final response C converges: PASS;
- iterative A→B→C final middle-cell head: `0.6072738889883155 m`;
- clean C-only final middle-cell head: `0.6072738893643476 m`;
- maximum final-head path difference: `3.7603209435133067e-10 m`;
- path-equivalence guard: `1.4901161193847656e-08 m`;
- final response stabilization increments: `4.5929926528742726e-13 m` and `1.680877659282487e-13 m`;
- solve counts: iterative `13`, clean `9`;
- exactly one `finalize_solve`: PASS;
- backend never calls `finalize_time_step`: PASS;
- explicit `MXITER` overrun is blocked before an extra kernel solve: PASS.

The earlier failed qualification iterations are retained as useful evidence: overly strict IMS residual/head closure was not admitted, and an attempted out-of-envelope solve exposed the need for the explicit live-`MXITER` guard. No such failure was converted into a PASS by weakening production semantics.

## 12. Qualification verdict

`OWNER_QUALIFIED_MODFLOW6_PREPARED_SOLVE_ITERATIVE_BACKEND`

The qualified contract is intentionally narrow:

1. prepare one MODFLOW timestep;
2. acquire one prepared solve and its fixed accepted `XOLD`;
3. republish typed F-GC34 API-package terms between successive MODFLOW `solve()` calls;
4. never exceed live `MXITER`;
5. expose current `X` upward to the internal SWAP5–MODFLOW coupling service;
6. finalize the MODFLOW solve exactly once after coupled convergence;
7. leave timestep acceptance/finalization to the higher transaction boundary.

Whole-window abort/retry/reconstruction is not qualified by F-GC38 and remains a separate bounded workunit.
