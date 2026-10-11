# Migration slices and qualification gates

**Status:** migration execution contract  
**Snapshot:** 2026-09-04  
**Scope:** incremental migration from the SWAP 4.3.1 reference baseline to the SWAP5 target architecture

This page converts the [legacy-to-target migration map](legacy-migration.md) into bounded implementation slices. A slice is complete only when its exit gate is satisfied; moving code into a new module is not sufficient.

!!! warning "Slices are architectural seams, not releases"
    Several slices may overlap in implementation. Their exit gates, however, are ordered by dependency. A later slice must not be declared qualified by bypassing an unmet prerequisite gate.

## Governing rules

Every slice follows the same rules:

1. preserve a runnable full-accuracy reference path;
2. identify affected architecture invariants before implementation;
3. keep physical behaviour separate from numerical policy;
4. make committed physical state and trial state distinguishable;
5. keep file I/O and system composition outside the kernel;
6. require a closed water balance for every accepted path;
7. record solver route, retries and fallback whenever numerical behaviour changes;
8. retain legacy behaviour until the replacement path has passed its stated gate;
9. do not promote an architecture capability in the implementation-status register unless new evidence actually justifies the change.

## Slice overview

| Slice | Purpose | Primary legacy seams | Main target boundary | Exit depends on |
| --- | --- | --- | --- | --- |
| **M0 Reference shield** | Freeze and automate the behavioural reference used by all later migration | whole 4.3.1 executable, current audit baselines | Verification / reference mode | none |
| **M1 Typed external boundary** | Separate files, parsing, output and external exchange from computation | `readswap*`, `swapoutput*`, `swap_main.f90`, environment/path logic | Adapters + Public API | M0 |
| **M2 Data ownership split** | Classify globals into parameters, committed state, forcing, numerics, results and scratch | `variables.f90`, `arrays.f90`, declarations across modules | Cross-cutting data domains | M0; M1 may proceed in parallel |
| **M3 Transactional interval execution** | Establish checkpoint/trial/retry/commit semantics independent of legacy day/control flow | `swap.f90`, `timecontrol.f90`, `soilwater.f90`, state snapshots | Runtime + Kernel transaction boundary | M0, M2 |
| **M4 Soil-water solver boundary** | Isolate reference Richards solver behind a clean hydraulic interface and worker scratch | `headcalc.f90`, `soilwater.f90`, constitutive/hydraulic helpers | Soil-water interface + solver implementation | M0, M2; qualification exit requires M3 |
| **M5 Process-contract extraction** | Move surface, drainage, crop/ET, optional and transport physics behind typed process contracts | boundary/process/crop/stress/solute module families | Kernel process components | M2, M3, M4 interface contract |
| **M6 Coupling kernel contract** | Make rollback-safe head/flux coupling and response information first-class | bottom-boundary/exchange logic, coupling prototypes | Public API + Coupler + solver sensitivity output | M3, M4; selected M5 contracts as required |
| **M7 MultiSWAP runtime and storage** | Introduce templates, batches, worker pools, SoA/pools and bounded-cost routing | legacy single-run orchestration/global allocation assumptions | Runtime / execution manager | M2-M6 contracts stable |
| **M8 Legacy retirement** | Remove obsolete globals, monolithic control paths and direct internal dependencies | legacy containers and bypass paths | Target architecture only | all applicable prior gates |

The ordering is deliberately not a simple waterfall. M1 and M2 can overlap. M3 and M4 can also advance in parallel, but M4 cannot claim end-to-end qualification until trial/rollback semantics are stable. Coupling concerns are present in M3 and M4 already; M6 qualifies the complete coupling-facing contract rather than adding coupling as an afterthought.

## M0 - Reference shield

### Purpose

Protect the scientific reference before structural migration. The reference is the arbiter when architectural movement changes call graphs, state ownership or solver organisation.

### Includes

- reproducible SWAP 4.3.1/reference execution;
- the existing qualified audit cases where applicable;
- representative easy and difficult soils, including known expensive/problem cases;
- water-balance extraction;
- state, flux and solver-route comparison facilities;
- explicit reference tolerances and test metadata.

### Must not do

- change production physics merely to simplify the future architecture;
- replace difficult cases with easier ones;
- accept visual similarity as qualification.

### Exit gate M0

M0 is exited only when:

- the reference executable/path is reproducibly runnable;
- reference inputs and expected outputs are version identified;
- state and integrated-flux comparison is automated for the chosen qualification set;
- water balance is machine-checkable;
- solver route/cost can be recorded where relevant;
- known qualified audit fixes are distinguishable from the untouched 4.3.1 baseline.

**Primary invariants:** 13, 24, 25, 26, 30.

## M1 - Typed external boundary

### Purpose

Make files and external representations adapter concerns without first redesigning legacy formats.

### Primary legacy seams

Typical responsibilities currently found around `swap_main.f90`, `readswap*`, meteorological/file readers, output routines, environment/path handling and external exchange entry points.

### Target result

A caller can construct typed parameters/state/forcing/numerical configuration and request computation without the kernel knowing a file name, file unit, directory or parser.

### Allowed transition state

Legacy file readers may remain fully functional as adapters that populate the typed request model. Legacy output may serialize typed results.

### Exit gate M1

- a non-file in-memory invocation path reaches the computational boundary;
- kernel-facing interfaces contain no path, file-unit or parser semantics;
- legacy file runs still reproduce reference results through adapters;
- output serialization does not mutate physical state;
- non-midnight or non-day requests are not rejected merely because an adapter historically used daily files.

**Primary invariants:** 1, 2, 3, 9, 28, 29, 30.

## M2 - Data ownership split

### Purpose

Destroy broad global ownership while preserving all information that is actually required.

### Classification

Every migrated field must be assigned to exactly one logical category:

- shared immutable/effectively immutable parameters;
- committed physical column state;
- interval forcing/boundary data;
- numerical configuration/policy;
- typed results/diagnostics;
- worker/job scratch.

### Important constraint

A field is not physical state merely because the legacy program stores it between calls. Newton vectors, Jacobians, factorisations and constitutive work arrays remain numerical scratch unless they are demonstrably required to continue physical evolution.

### Exit gate M2

- a reviewed inventory exists for the fields needed by M3-M5;
- committed state contains only continuation-relevant physical quantities;
- inactive optional modules do not force equivalent persistent state allocation;
- immutable parameter sets can be shared by reference/ID;
- solver scratch is absent from authoritative column state;
- order-independent scratch reuse has a test plan and ownership contract;
- no migrated field has ambiguous ownership between two target components.

**Primary invariants:** 3, 4, 5, 6, 16, 27, 30.

## M3 - Transactional interval execution

### Purpose

Make one SWAP interval a transaction:

```text
committed state0
    -> trial [t0,t1]
    -> TrialResult
    -> accept / retry / reject
    -> commit or discard
```

### Primary legacy seams

`swap.f90`, `timecontrol.f90`, `soilwater.f90`, legacy state-save arrays and timestep-reduction/control-flow flags.

### Required separation

- **Kernel:** computes a trial from the correct committed physical start;
- **Runtime/retry policy:** decides accept/retry/fallback and timestep policy;
- **Committed state store:** changes only on commit;
- **Warm-start numerics:** may survive rejected attempts but are never authoritative physics.

### Active-work trace

The current transactional-controller refactoring maps here directly: replacing broad snapshots with explicit trial results, removing redundant endpoint copies, making solver-attempt status explicit, moving timestep reduction behind retry policy, and extracting interval orchestration from `swap.f90` are all M3 work.

### Exit gate M3

Dedicated automated tests demonstrate:

- rejected trials do not mutate committed state;
- accepted endpoint is committed exactly once;
- integrated fluxes are not double counted across retry paths;
- rerunning from the same committed state is deterministic or tolerance-consistent;
- changing only warm-start numerics does not change the accepted physical solution outside qualification tolerance;
- retry/fallback route is visible in diagnostics;
- execution works over generic `[t0,t1]`, including at least one non-midnight start and one non-day interval;
- water balance closes for normal and retry paths;
- no retry policy silently changes physical options.

**Primary invariants:** 7, 8, 9, 10, 13, 23, 24, 26, 29, 30.

## M4 - Soil-water solver boundary

### Purpose

Preserve the qualified reference Richards mathematics while preventing `HeadCalc` internals from defining the architecture of the rest of SWAP5.

### Primary legacy seams

`headcalc.f90`, `soilwater.f90`, hydraulic constitutive functions, lower/upper boundary contributions, source/sink contributions, groundwater calculations and linear-algebra work arrays.

### Target contracts

The common soil-water interface must expose physical meaning rather than internal arrays. It should cover, as required:

- trial advancement over a requested interval/substep;
- pressure head/water-content endpoint information;
- top and bottom flux/head interface information;
- physically required hydraulic queries for process modules;
- solver-attempt/convergence status;
- water-balance/accounting contributions;
- response tangents such as `dh_b/dq_b` when qualified.

The solver implementation owns Newton/Jacobian/factorisation algorithms and borrows worker scratch. It does not own committed column state or runtime retry policy.

### Active-work trace

The current S12 `headcalc` state-extraction line belongs primarily to M4, with M2 dependencies. Moving global hydraulic state into explicit arguments/contracts and preventing other modules from reading solver-internal arrays are direct M4 objectives.

### Exit gate M4

- the reference Richards implementation runs through the common soil-water interface;
- crop/ET/drainage callers needed by the qualification set do not read `HeadCalc` internal arrays directly;
- Newton/Jacobian/factorisation storage is worker/job scratch;
- solver-attempt status is returned explicitly rather than inferred through legacy global control flags;
- reference state/flux regressions pass for the chosen qualification suite;
- difficult-soil cases retain bounded, diagnosable retry behaviour;
- water balance closes across normal/retry/fallback cases used in qualification;
- at least one interface sensitivity is checked against a finite-difference reference before production use if sensitivity output is enabled.

**Primary invariants:** 5, 7, 8, 13, 14, 20, 21, 22, 23, 24, 25, 26, 30.

## M5 - Process-contract extraction

### Purpose

Migrate physical process families without re-implementing their science merely to match new module boundaries.

### Families

M5 is executed family by family, for example:

- surface/atmospheric boundary physics;
- drainage and irrigation;
- crop, ET and root uptake;
- macropores and optional flow physics;
- snow/frost/thermal processes;
- solute/nutrient/WOFOST-soil interactions.

Each family gets its own sub-gate; M5 is not one giant rewrite.

### Contract rule

A process module consumes typed physical state/hydraulic queries and returns physical contributions/results. It must not receive Newton arrays, file handles, runtime scheduling state or unrelated optional-module storage.

### Exit gate per process family

- reference physics is retained or intentional changes are separately qualified;
- inputs/outputs have physical semantics and documented units;
- no direct dependency on solver implementation arrays remains;
- optional state exists only for columns/templates where the process is active;
- process contribution to water balance is explicit;
- disabling/enabling numerical execution policy does not alter the physical configuration;
- family-specific regression cases pass against reference mode.

**Primary invariants:** 3, 4, 13, 20, 21, 22, 23, 25, 27, 30.

## M6 - Coupling kernel contract

### Purpose

Qualify SWAP as a rollback-safe component in predictor-corrector groundwater coupling without putting MODFLOW composition inside the kernel.

### Important sequencing rule

Coupling requirements influence M3 and M4 from the beginning. M6 does not introduce rollback, bottom-boundary response or sensitivity concepts for the first time; it qualifies their combined external contract.

### Target behaviour

For direct coupling, the accepted interface seeks:

```text
H_SWAP = H_MF
q_SWAP = -q_MF
```

Head residual may be non-zero within a qualified tolerance. Flux accounting remains conservative.

### Exit gate M6

- predictor and corrector both start physically from the correct committed component state;
- rejected coupled windows roll back every participating physical component consistently;
- variable coupling windows work without a midnight/day assumption;
- head residual and flux residual are separately diagnosed;
- tile fractions and area-weighted aggregation are owned by the coupler, not SWAP;
- interface mass accounting closes exactly within the defined numerical tolerance;
- response tangents used in production are qualified against finite-difference references;
- the normal production path demonstrates approximately predictor + corrector cost, with extra solves only where nonlinearity requires them;
- any deep-vadose component preserves storage during transition between coupling modes.

**Primary invariants:** 7, 8, 10-19, 28, 29, 30.

## M7 - MultiSWAP runtime and scalable storage

### Purpose

Scale the already-separated contracts to large column counts without changing their physics.

### Target result

- model templates define homogeneous topology, active modules, discretisation structure, soil-water solver, numerical policy and state layout;
- columns retain individual parameter references, forcing and committed physical state;
- internal layouts may use SoA, pools or batches;
- workers reuse scratch across many columns;
- difficult columns may move to a different numerical execution class without changing physical configuration.

### Exit gate M7

- batch results are order independent within qualification tolerance;
- worker scratch reuse shows no cross-column contamination;
- inactive optional functionality does not allocate equivalent persistent memory or compute on every column;
- representative large-batch memory footprint is measured;
- throughput and tail-cost behaviour are measured, including difficult columns;
- fallback/relaxed routes are bounded, visible and mass conservative;
- standalone execution uses the same kernel contracts rather than a separate physics implementation.

**Primary invariants:** 1, 4-6, 13, 16, 23-27, 30.

## M8 - Legacy retirement

### Purpose

Remove obsolete legacy ownership and bypass paths only after the replacement boundaries are proven.

### Candidates

- broad mutable global state containers;
- monolithic `swap.f90` orchestration responsibilities;
- direct `HeadCalc`-internal dependencies from other physics modules;
- solver-specific retry/control flags outside the solver/runtime contract;
- kernel file/path assumptions;
- duplicate standalone/coupled execution logic that violates the one-kernel rule.

### Exit gate M8

A legacy path may be deleted only when:

- every retained behaviour has an identified target owner;
- all dependent qualification suites pass without using the legacy bypass;
- water balance remains closed;
- no required diagnostic or fallback path has been lost;
- the implementation-status map reflects the new evidence;
- the affected invariant review is recorded;
- removal does not eliminate the reference mode required to qualify future work.

**Primary invariants:** 1-9, 13, 16, 20-30 as applicable.

## Dependency graph

```text
                     M0 Reference shield
                        /           \
                       v             v
          M1 Typed external      M2 Data ownership
              boundary              split
                       \             /
                        \           /
                         v         v
                    M3 Transaction seam
                         |       \
                         |        \
                         v         v
                 M4 Soil-water     coupling requirements
                    boundary       already constrain M3/M4
                      /   \
                     /     \
                    v       v
             M5 Process     M6 Coupling contract
              contracts       qualification
                    \       /
                     \     /
                      v   v
                M7 MultiSWAP runtime
                       |
                       v
                M8 Legacy retirement
```

This diagram expresses qualification dependency, not a prohibition on parallel implementation work.

## Gate evidence record

Every slice exit should produce a compact evidence record containing at least:

| Field | Required content |
| --- | --- |
| Slice | M0-M8 identifier and stated scope |
| Baseline | exact reference code/version/configuration |
| Changed boundary | responsibilities/data ownership moved |
| Affected invariants | explicit invariant numbers |
| Test set | cases and reason for inclusion |
| State tolerance | relevant endpoint/state tolerance |
| Flux tolerance | integrated-flux tolerance |
| Water balance | acceptance tolerance and result |
| Solver route | normal/retry/fallback counts where applicable |
| Coupling residual | head/flux residual where applicable |
| Sensitivity check | analytic/Jacobian versus finite difference where applicable |
| Cost | timing/work/iteration impact where applicable |
| Known limitations | scope not yet qualified |
| Decision | `EXITED`, `PARTIAL`, or `FAILED` with evidence link |

## Status update rule

The migration-slice gate and the [implementation status map](implementation-status.md) serve different purposes:

- a slice gate says whether one bounded migration seam has enough evidence to exit;
- the implementation-status map says whether a broader architecture capability is `TARGET`, `PARTIAL`, `IN_PROGRESS` or `QUALIFIED`.

Exiting one slice does not automatically promote every related capability. Promotion requires capability-level evidence.

## Current work alignment

At this snapshot:

- the transactional controller/execution-adapter work aligns primarily with **M3**;
- the systematic extraction of global state and `HeadCalc` dependencies aligns primarily with **M2 + M4**;
- existing API/coupler prototypes inform **M6** but do not yet satisfy its production qualification gate;
- existing solver/audit reference work contributes to **M0** and selected M4 evidence but does not by itself exit M4.

This alignment is descriptive. The authoritative implementation status remains the [implementation status map](implementation-status.md).

## Change discipline

When a migration task is proposed, it should identify a slice before code is changed. If a task spans several slices, either split the task or state why a cross-slice change is unavoidable and which gates must remain open.

The preferred migration unit is therefore:

```text
small ownership/interface cut
    -> compile/reference check
    -> targeted transaction/mass test
    -> affected invariant review
    -> gate evidence update
    -> only then remove legacy overlap
```

This keeps architecture migration reversible, testable and compatible with the reference-first development strategy.
