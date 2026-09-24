# F-PE-PROFILE01 — Compute-core baseline and runtime attribution

Date: 2026-09-24

Status: `PREREGISTERED_ACTIVE`

## Scope

This workunit establishes a reproducible compute-core performance baseline for SWAP5 and determines where execution time is spent between input and output.

Protocol:

`RECONCILE -> PREREGISTER -> BASELINE -> PROFILE -> ATTRIBUTE -> NECESSITY_AUDIT -> QUALIFY -> PERSIST -> CLOSE`

The primary research question is:

> Where does SWAP5 compute time go between completed input preparation and output emission, why is that work executed, and which measured costs are inherent physics/numerics versus avoidable implementation overhead or redundant work?

This workunit does **not** optimize production code yet. No hotspot may be repaired before the baseline and attribution evidence are frozen.

## Canonical authority at start

- repository: `abhedwig-cell/SWAP5`
- branch: `integration/f-ci-canonical`
- commit: `506c36aab6f84b74dffdf5c37fe572c1e0b46610`
- tree: `97e6b7c361c4cda8a150373a375b55e2c1297449`

Work branch:

- `work/f-pe-profile01`

## Relation to existing performance work

F-PE-PROFILE01 reuses the existing MP measurement architecture rather than defining an incompatible profiler.

Existing MP evidence already provides:

- semantic timing categories for constitutive, residual, Jacobian, linear solve, Newton control, process physics, transaction, runtime batching, diagnostics and other kernel work;
- a workload catalog with Hupsel single-column, scaling, difficult hydraulic and optional-physics benchmark families;
- repeatability and observer-overhead methodology;
- a controlled CPU-baseline protocol;
- tooling under `tools/performance/`.

However, current MP records do not yet provide a complete production SWAP5 compute-core attribution and do not explicitly classify redundant or unnecessary work. F-PE-PROFILE01 adds that necessity layer.

## Timing boundary

Runtime is administratively decomposed as:

```text
T_total = T_input + T_compute + T_output
```

The primary metric is `T_compute`.

Definitions:

- `T_input`: external input loading, parsing and run preparation before the first computational interval is ready;
- `T_compute`: model execution from the ready initial state through the final accepted computational state, excluding external output emission;
- `T_output`: external output formatting and file emission after or around accepted model execution.

I/O must be measured and reported where possible, but it must not be mixed into the compute-core attribution.

For coupling-oriented workloads, in-memory API or coupling exchange is not automatically classified as file I/O. Its cost must be attributed according to actual semantics, e.g. transaction, runtime orchestration, coupling adapter or data movement.

## Compute-core attribution taxonomy

The initial stable attribution classes are:

1. `constitutive`
   - theta(h), C(h), K(h), dK/dh, hydraulic interpolation/table evaluation and required constitutive derivatives;

2. `residual`
   - nonlinear residual assembly/evaluation excluding constitutive work where exclusive timing is available;

3. `jacobian`
   - Jacobian/coefficient construction excluding linear solve;

4. `linear_solve`
   - tridiagonal or alternative linear-system solution;

5. `newton_control`
   - nonlinear convergence checks, backtracking and solver control;

6. `soil_water_other`
   - remaining soil-water solver work not yet assigned above;

7. `process_physics`
   - surface/atmosphere, ET/root uptake, drainage/irrigation, macropore, thermal, solute, crop and nutrient processes, with subcategories retained when available;

8. `timestep_control`
   - trial construction, timestep selection, reductions, retries and step-doubling control outside solver-internal work;

9. `transaction`
   - checkpoint, capture, restore, rollback, commit and accepted/trial-state administration;

10. `data_movement`
    - array/state copies, packing/unpacking, conversions and other measured movement of data not already charged to a required physical operation;

11. `allocation_memory`
    - dynamic allocation/deallocation, scratch resizing and repeated initialization where separately observable;

12. `runtime_orchestration`
    - wrappers, dispatch, runtime classification, scheduling and control-flow overhead;

13. `diagnostics_accounting`
    - balances, diagnostics and measurement/runtime bookkeeping;

14. `other_kernel`
    - compute-core work not yet attributable.

The existing MP category names remain authoritative where they overlap. New subcategories are diagnostic refinements and must reconcile back to the MP top-level accounting.

## Necessity classification

Every material hotspot must receive one of these classifications before an optimization is proposed:

- `N1_REQUIRED`: physically or numerically required work;
- `N2_REQUIRED_EXPENSIVE_IMPLEMENTATION`: required result, but implementation may be unnecessarily costly;
- `N3_CONDITIONALLY_REQUIRED`: valid work, but execution appears broader or more frequent than needed;
- `N4_REDUNDANT`: duplicate or avoidable repeated work whose result is already available or unnecessary on the current path;
- `N5_DEAD_OR_NONCONTRIBUTING`: executed work that cannot affect accepted model state or required diagnostics for the qualified configuration;
- `NX_UNRESOLVED`: evidence insufficient to classify.

N4/N5 status requires call-path and state-dependency evidence. Wall-clock prominence alone is insufficient.

## Optimization ordering for later workunits

No repair is performed in PROFILE01, but later work must prefer:

1. do not execute unnecessary work;
2. execute necessary work less often;
3. move or initialize less data;
4. execute the same required computation more efficiently;
5. approximation only in separately governed approximate-model workstreams.

Approximation is outside F-PE-PROFILE.

## Measurements required

The baseline must combine:

### Sampling or low-intrusion profiling
Used to identify whole-program hotspots without requiring dense timers everywhere.

### Semantic timers
Used for stable top-level and major compute categories. Timers must state whether they are inclusive or exclusive.

### Counters
At minimum where technically available:

- accepted computational intervals;
- nonlinear iterations;
- residual evaluations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- timestep reductions;
- retries/rejected trials;
- constitutive evaluations;
- process call counts for expensive or optional processes;
- checkpoint captures;
- checkpoint restores/replays;
- commits;
- major state/array copies when observable;
- dynamic allocations or scratch resizes where observable.

High call count is evidence for investigation, not by itself evidence of redundancy.

## Baseline workload matrix

PROFILE01 starts with four workload roles. Existing qualified or already versioned fixtures are preferred; no undocumented physical defaults may be invented merely to fill the matrix.

### P01-A — simple hydraulic/reference workload

Purpose: expose the reference Richards path with minimal optional-physics interference.

Candidate source: existing SWAP5 reference-mode test/fixture selected after execution-path reconciliation.

### P01-B — representative production workload

Purpose: characterize normal SWAP execution with realistic process composition.

Preferred starting candidate: Hupsel lineage where the current SWAP5 application path is qualified and executable.

### P01-C — numerically difficult hydraulic workload

Purpose: amplify nonlinear iterations, retries or known difficult hydraulic behavior.

The existing MP-B04 B12 row is parameter-locked but not a complete executable fixture. PROFILE01 must not invent the missing forcing/boundary/process configuration. If no qualified difficult production fixture is available, this slot remains explicitly blocked rather than fabricated.

### P01-D — physics-rich workload

Purpose: expose non-solver process costs and detect repeated process work, including ET/root uptake and, where qualified, oxygen stress or other expensive optional physics.

A fixture is admitted only when its current canonical path and expected outputs are already sufficiently qualified.

A later coupling-like short-window workload may be added, but it is not required to close the first single-column baseline.

## Repeatability and environment

Reuse the existing MP controlled-baseline principles:

- exact code commit;
- compiler and version;
- optimization flags;
- CPU/host information;
- worker/thread count;
- affinity where available;
- warm-up policy;
- repeated measurements;
- balanced or interleaved comparison order where variants are compared;
- no post-hoc deletion of timing outliers;
- physical-output identity or qualified numerical-equivalence check.

PROFILE01 may produce diagnostic timing on shared CI hosts, but fine-grained percentage claims below the measured noise/resolution floor must not be presented as resolved effects.

## Hard scientific/technical gates

1. Instrumentation must not change accepted physical state.
2. Instrumentation must not change solver/timestep acceptance policy.
3. Instrumented versus uninstrumented runs must preserve the applicable VQ physical and mass-balance criteria.
4. Rejected trials may contribute cost but may not contaminate committed physical history.
5. Category totals must reconcile to the measured compute region within an explicitly reported unattributed remainder.
6. Call counters must reconcile with known control flow on at least one inspectable case.
7. Profiling overhead must be measured or bounded before fine-grained conclusions are used.
8. No production optimization is admitted in PROFILE01.
9. No solver, physics, tolerance, fallback or approximation change is permitted for performance.
10. I/O performance observations are persisted separately and are not used to claim compute-core speedup.

## Explicit audit targets

PROFILE01 must actively inspect for:

- duplicate process calls;
- repeated constitutive evaluations with unchanged inputs;
- repeated initialization or zeroing;
- loops over inactive/unneeded ranges;
- work performed for disabled physics;
- full-state copies when only a subset is required;
- repeated allocate/deallocate or scratch resizing inside hot paths;
- pack/unpack or representation conversions;
- repeated diagnostics or balance assembly;
- wrapper/control paths that recompute already available quantities;
- transaction capture/restore costs and their semantic necessity.

These are hypotheses, not predeclared defects.

## Predeclared interpretation rules

- A large solver share does not prove the solver should be changed.
- A large transaction/data-movement share does not prove copying is unnecessary.
- A high call count does not prove redundancy.
- A local speedup does not imply the same total-runtime speedup.
- A measured local fraction `f` and local fractional improvement `r` imply at most an approximate first-order total compute saving `f*r` before secondary effects; the actual whole-run result must still be measured.
- Negative findings are retained. If suspected redundancy is semantically necessary, that is a valid result.

## PROFILE01 deliverables

Before closeout:

1. frozen source identity and environment;
2. selected executable workload set with qualification provenance;
3. explicit compute-region boundaries;
4. whole-program sampling profile where technically available;
5. semantic timing decomposition;
6. call/counter evidence;
7. unattributed compute fraction;
8. hotspot table;
9. first necessity classification for material hotspots;
10. list of suspected redundancies with evidence status;
11. observer-overhead/noise statement;
12. recommendation for bounded PROFILE02 audit targets;
13. no production optimization patch.

## Initial reconciliation result

Current canonical already contains substantial MP measurement design and tooling. This workunit therefore **extends rather than replaces** MP.

Known starting facts:

- `benchmarks/performance/workload-catalog.json` defines MP-B01 Hupsel single-column as shadow-executable and identifies B12 as parameter-locked rather than a complete executable case;
- `docs/performance/mp-5-repeatability-overhead.md` demonstrates why measurement noise and observer overhead must be treated explicitly;
- `tests/fpe/run_fpe11_paired_surface_evaporation_timing.sh` provides a useful paired same-runner timing pattern for a bounded microbenchmark, but it is not a whole-compute profile;
- current runtime diagnostics already expose counts such as checkpoint captures/replays, attempts and retries, providing potential hooks for attribution;
- the full production SWAP5 compute path is not yet semantically timed at the granularity required here.

## Current status

```text
RECONCILE       = COMPLETE_FOR_START
PREREGISTER     = COMPLETE
BASELINE        = NEXT
PROFILE         = NOT_STARTED
ATTRIBUTE       = NOT_STARTED
NECESSITY_AUDIT = NOT_STARTED
REPAIR          = FORBIDDEN_IN_PROFILE01
CLOSE           = OPEN
```


## Initial source-path audit

The first source-path reconciliation identified an immediately testable baseline candidate and one concrete redundancy hypothesis.

### P01-A candidate selected for first instrumentation pass

`tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90` is a suitable first inspectable SWAP5 compute-path workload because it:

- executes the current serialized reference backend and real reference Richards/HeadCalc route;
- has an existing production-runtime gate at O0 and O2;
- checks completed status, hard mass balance, accepted/rejected trajectory semantics and physical identity;
- already exposes diagnostic counts for retries and linear solves;
- deliberately contains a discarded full trial alongside accepted half trials, making it useful for separating useful accepted work from real but rejected numerical work.

It is not yet a representative full production/Hupsel workload, so it is admitted only as P01-A, not P01-B.

### H01 — repeated Richards workspace reset/zeroing

Status: `SUSPECTED_N4_REDUNDANCY_UNMEASURED`.

Observed current path:

1. `mod_reference_richards_legacy_binding.f90` calls `initialize_reference_workspace(ws%richards, n)`;
2. immediately afterwards the same binding calls `reset_reference_workspace(ws%richards)`;
3. `initialize_reference_workspace()` itself already calls `reset_reference_workspace()` even when the workspace is already allocated at the correct size;
4. the subsequent `headcalc(..., fsi_workspace=ws%richards, ...)` path calls `initialize_reference_workspace(fsi_ws, numnod)` again;
5. that third initialization again invokes `reset_reference_workspace()`.

Because `reset_reference_workspace()` zeroes a substantial set of node-sized work arrays, matrices, integer/logical arrays, warm-start storage and diagnostics, the current route appears capable of performing multiple full-workspace zeroing passes per solve.

This is **not yet classified as a defect**. Before any repair, PROFILE01 must establish:

- exact reset count per solve/trial;
- whether any of the resets are semantically required for scratch independence or poison-safety;
- bytes/elements written per reset as a function of node count;
- measured contribution to compute time at representative node counts;
- physical/result identity for any later bounded removal experiment.

No source change is permitted in PROFILE01 on the basis of this observation alone.

### Existing counters

`a23bu_solver_diagnostics_t` already records:

- `headcalc_calls`;
- `nonlinear_iterations`;
- `jacobian_builds`;
- `linear_solves`;
- `backtracking_attempts`;
- `alternative_solver_calls`;
- `internal_retries`.

These should be reused rather than duplicated. PROFILE01 instrumentation should add only missing counts/times needed for attribution and redundancy diagnosis.

## Updated status

```text
RECONCILE       = COMPLETE_FOR_START
PREREGISTER     = COMPLETE
BASELINE        = P01-A_PATH_SELECTED
PROFILE         = INSTRUMENTATION_DESIGN_NEXT
ATTRIBUTE       = INITIAL_H01_HYPOTHESIS_RECORDED
NECESSITY_AUDIT = H01_PENDING_MEASUREMENT
REPAIR          = FORBIDDEN_IN_PROFILE01
CLOSE           = OPEN
```


## Technical qualification failure TQ-01

The first PROFILE01 CI execution on PR #599 did not reach the new observer assertion. The clean FKT22 build failed while compiling `mod_reference_richards_temporal_indicator.f90` because `mod_b110_root_sink_provider.mod` had not yet been built.

Classification:

- `TECHNICAL_TEST_HARNESS_FAILURE`;
- not a production-physics failure;
- not evidence for or against H01;
- caused by source ordering in `tests/fkt/run_fkt22_fmr_runtime_gate.sh` that could be masked in environments containing stale module files.

Repair:

- move `src/solver/mod_b110_root_sink_provider.f90` before `src/solver/mod_reference_richards_temporal_indicator.f90` in the clean compile list;
- no production source semantics changed by this repair.

The failed run is retained as evidence and the observation gate is re-run from the repaired harness.


### H02 — transaction state clone/data-movement cost

Status: `N1_OR_N2_PENDING_MEASUREMENT`.

The current transaction path deliberately clones physical state to preserve accepted/trial isolation. For external full/half stepping, the reference transaction creates a checkpoint clone and then trial clones for the full and half routes. The B1.10 physical-state clone currently allocates and copies the pressure-head and water-content arrays and, when active, copies optional snow and soil-temperature state.

This copying is **not preregistered as redundant**. Transactional isolation is a scientific invariant. PROFILE01 must instead measure:

- physical-state clone count per requested interval and per accepted interval;
- allocated/copied bytes by state family;
- fraction associated with rejected/discarded trials;
- whether repeated allocate/deallocate is a measurable implementation cost;
- whether later implementation alternatives can preserve exact accepted/trial isolation without changing ownership semantics.

Pointers, aliasing or move-based alternatives are not authorized merely because copying is measured as expensive. Any later repair must prove that committed state cannot be mutated by speculative work.


## Instrumentation qualification log

### Q01 — first observation compile attempt

Result: `FAIL_EXPECTED_REPAIRABLE_OBSERVER_PLUMBING`.

The first P01-A workflow attempt failed at compile time because reset counters were accumulated in `transaction_result_t` code paths before the corresponding result fields had been added to the type. No model execution occurred and no physics evidence was produced.

Repair: add the missing total and accepted reset/byte fields to `transaction_result_t` and retain the same preregistered observation semantics.

### Q02 — canonical diagnostics propagation compile attempt

Result: `FAIL_EXPECTED_REPAIRABLE_OBSERVER_PLUMBING`.

After Q01 repair, compilation progressed to `mod_kernel_transactions.f90` and failed because the new reset counters were mapped from `canonical_run_diagnostics_t` before that canonical diagnostics type and its transaction accumulator exposed the fields.

Repair: add `workspace_full_resets` and `workspace_zeroed_bytes` to `canonical_run_diagnostics_t` and accumulate the corresponding `transaction_result_t` totals in `mod_canonical_interval_runtime`.

These failures are observer-plumbing defects only. Neither attempt reached model execution; neither is evidence about SWAP performance or physics.


### Q03 — P01-A runner dependency closure

Result: `FAIL_TEST_RUNNER_DEPENDENCY_DRIFT`.

After observer-plumbing compilation progressed, the existing FKT22 runtime runner failed before model execution because the current serialized backend imports modules that were not present in the runner's explicit source list. The first missing module was `mod_b110_smooth_freatic_projection`; after adding it, the next missing module was `mod_fmr_drainage_qbot_directional_binding`, whose ordering also had to follow the smooth-projection module.

These failures are test-runner source-closure drift caused by the current backend dependency graph. They do not indicate a physics, solver or profiling defect. The bounded repair is limited to completing and ordering the runner compile list.

### H01 static quantitative prediction before runtime observation

For the current P01-A four-node workspace, `reference_workspace_payload_bytes()` accounts for the node-sized real, integer and logical workspace payload touched by a full reset. From the current layout this is approximately 812 bytes per full reset on the GNU runner representation used by the gate.

The source path predicts three full reset calls for each Reference solve:

1. reset inside `initialize_reference_workspace()` called by the legacy binding;
2. immediate explicit `reset_reference_workspace()` in that binding;
3. reset inside the second `initialize_reference_workspace()` call in `HeadCalc`.

Because the P01-A external full/half transaction normally evaluates one full trial plus two half trials, the preregistered source-level prediction is:

```text
predicted workspace resets per requested interval = 9
predicted reset payload touched at n=4       ~= 7308 bytes
```

This remains a prediction until the runtime observer passes. A mismatch is evidence to investigate, not a reason to alter the counter or gate after observation.


## First measured result — H01 per-solve reset observation

Workflow run 36061582716 completed successfully on GNU Fortran 13.3.0 after bounded runner dependency repair.

Observed for the P01-A Reference solve path, identically at O0 and O2:

```text
workspace_full_resets_per_solve = 3
workspace_zeroed_bytes_per_solve = 2436
runtime_gate_O0 = PASS
runtime_gate_O2 = PASS
O0_O2_semantic_identity = PASS
production_runtime_gate = PASS
```

The byte result implies 812 bytes of workspace payload are touched by each full reset for the four-node P01-A workspace. This matches the preregistered source-level workspace-layout calculation.

Interpretation:

- H01's existence claim is **confirmed**: the current Reference solve path performs three full workspace reset passes per solve;
- the observation remains a **redundancy candidate**, not yet a removal authorization;
- physical/runtime semantics remained qualified under the existing FKT22 gate at O0 and O2;
- the time significance of the repeated reset is still unmeasured and must be established before prioritizing a repair.

Current necessity classification: `N4_CANDIDATE_CONFIRMED_BEHAVIOR_COST_UNMEASURED`.


## First measured result — H01 workspace reset multiplicity

A successful P01-A runtime execution on GNU Fortran 13.3.0 reached the existing FKT22 production runtime oracle and preserved:

- rejected-trial isolation: PASS;
- physical identity: PASS;
- serialized runtime gate: PASS.

The observer measured for one Reference solve:

```text
workspace_full_resets = 3
workspace_zeroed_bytes = 2436
```

For the four-node P01-A workspace, one reset therefore corresponds to 812 bytes of zeroing under the current GNU storage sizes. The measured multiplicity confirms the source-path hypothesis that the same solver workspace is fully reset three times in one Reference solve.

H01 status is therefore advanced from `SUSPECTED_N4_REDUNDANCY_UNMEASURED` to:

`MEASURED_TRIPLE_RESET_NECESSITY_NOT_YET_ADJUDICATED`.

This is not yet an N4 verdict. PROFILE01 still has to establish which reset(s) are semantically required and measure the time contribution before a repair is authorized.

The external full/half transaction source path performs one full and two half Reference solves per successful no-retry interval. Current diagnostic assertions expect nine aggregate resets for that interval, but the interval-level value remains pending a successful run of the latest observer plumbing and must not be treated as measured evidence until that run passes.


## H01 necessity adjudication — first bounded verdict

Source-path inspection after the measured triple-reset result separates the three reset events:

1. `reference_richards_legacy_solve -> initialize_reference_workspace(ws%richards,n)`:
   - this call both ensures allocation/shape and performs a full reset;
   - one clean-scratch establishment at solve start is semantically defensible;
   - classification: `N1_REQUIRED_OR_RELOCATABLE` pending timing/design choice.

2. the immediately following explicit `reset_reference_workspace(ws%richards)`:
   - no workspace mutation occurs between reset 1 and reset 2;
   - it repeats the complete zeroing performed by `initialize_reference_workspace`;
   - classification for the current explicit Reference route: `N4_REDUNDANT_CONFIRMED`.

3. `HeadCalc -> initialize_reference_workspace(fsi_ws,numnod)`:
   - on P01-A, between reset 2 and this call only the separate state binding is initialized; it does not modify the Richards workspace;
   - on the optional interface-sensitivity route, `prepare_reference_tridag_factorization_capture` may resize `tridag_gamma`, but it explicitly zero-initializes the new/expanded storage itself;
   - no evidence was found that a second complete workspace zeroing is required before HeadCalc begins;
   - classification for the currently inspected explicit route: `N4_REDUNDANT_CONFIRMED_BOUNDED`.

Thus the current evidence supports a bounded statement:

> Of the three full workspace resets measured per explicit Reference solve, two are redundant on the inspected SWAP5 route. One full clean-scratch establishment remains semantically justified unless a later ownership design proves otherwise.

This does not yet authorize repair in PROFILE01. A later repair workunit must remove resets one at a time, preserve poison/scratch independence tests, preserve sensitivity-capture behavior, and demonstrate physical/result identity before claiming runtime benefit.
