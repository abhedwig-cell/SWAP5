# F-PE17 — S11 Richards worker-workspace recovery

Date: 2026-09-16

Status: `CLOSED_HISTORICAL_B_CURRENT_ARCHITECTURE_SUPERSEDED`

## Scope

This bounded workunit recovers the historical S11 Richards/Newton worker-workspace optimization and maps it to both requested targets.

Protocol:

`RECONCILE -> CLASSIFY -> MAP -> CLOSE`

No production mutation is performed here.

Explicit exclusions:

- no Energy Balance work;
- no RossFast work;
- no new Richards physics;
- no solver-tolerance change;
- no mechanical port of S11 into SWAP5;
- no claim of complete legacy solver thread safety;
- no widening of historical memory measurements into wall-time speedup claims.

## Authorities

SWAP5:

- canonical: `integration/f-ci-canonical`;
- current canonical commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`;
- canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`;
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`.

Recovered historical artifacts:

- `README_S11_RICHARDS_WORKER_WORKSPACE.md`;
- `qualification_summary.md`;
- exact `S11_from_S10.patch`;
- exact `S11_cumulative_from_pristine.patch`.

Historical status:

`RICHARDS_WORKER_WORKSPACE_TESTED`.

## Historical S11 optimization

S11 separates two roles that legacy `headcalc` had mixed through local/SAVE storage:

1. small solver history that influences later calls;
2. large disposable Newton/Richards execution scratch.

Historical `RichardsSolverState` contains:

```text
flwarn
iwarn
nstep
```

Historical `RichardsWorkspace` owns active-sized allocatable Newton arrays including the Jacobian bands, residual, source/sink, `dkdh`, old-head/update workspace, flux/head-gradient buffers and convergence flags. The rare band-solver fallback workspace is allocated separately/lazily.

S11 also makes workspace reuse hygiene explicit: when a worker previously ran `SWKIMPL=1`, later `SWKIMPL=0` use explicitly clears active `dkdh` rather than relying on historical SAVE/zero initialization.

No hydrological equation or boundary-condition formula is changed by the S10 -> S11 delta.

## Historical qualification

Recovered production regressions report exact normalized results for:

- full grassgrowth, `SWKIMPL=0`;
- five-day macropore;
- full grassgrowth, `SWKIMPL=1`;
- automatic-local versus mixed/static-local S11 builds for those applicable gates.

Normalized output hashes are unchanged between S10 and S11 and Newton iteration tables are unchanged.

Recovered component gates:

```text
RICHARDS_WORKSPACE_REUSE=PASS
RICHARDS_FALLBACK_DYNAMIC_STORAGE=PASS
RICHARDS_SOLVER_STATE_SNAPSHOT=PASS
RICHARDS_SOLVER_STATE_REINIT=PASS
RICHARDS_CROSS_GENERATION_RESTORE_REJECTED=PASS
```

The fallback linear solver was separately checked to `1e-12`, but the rare fallback was not naturally reached by the production regression cases.

Historical static-storage result for `headcalc.o`:

```text
                         automatic locals    SAVE-like locals
S10                           160,040 B           700,576 B
S11                                 0 B               352 B
```

At 100 nodes the recovered workspace accounting is:

```text
main worker workspace       9,616 B
lazy fallback workspace     4,400 B
total if fallback used     14,016 B
```

These are memory/ownership measurements. S11 did not establish a whole-model wall-time speedup.

Historical limitations remain explicit:

- one transitional standalone workspace singleton still existed;
- many physical variables remained legacy globals;
- macropore/root-extraction callees were not proven reentrant;
- full long macropore regression was not rerun;
- the rare fallback was component-tested rather than naturally exercised in production regression.

## Historical classification

S11 is classified:

`B — EXACT_SEMANTICS_PRESERVING_MEMORY/OWNERSHIP PERFORMANCE OPTIMIZATION, QUALIFIED_WITHIN_S10->S11 LINEAGE`.

It is not a correctness fix and its measured memory reduction must not be presented as a measured wall-time speedup.

## Target A — SWAP 4.3.1 stable legacy line

The exact pure S11 child delta exists as `S11_from_S10.patch`, but its parent is the earlier S10 architecture state.

A broad `S11_cumulative_from_pristine.patch` also exists, but it contains the preceding S1-S10 architecture/memory changes and therefore is not a pure stable-maintenance S11 performance patch against pristine SWAP 4.3.1.

Bounded searches did not recover an independent exact `S10_cumulative_from_pristine.patch` / isolated authoritative S10 postimage suitable for treating S11 as a small direct maintenance patch.

Target-A disposition:

`D — LOCALLY_QUALIFIED B CANDIDATE, DIRECT STABLE-LINE ADMISSION NOT CLOSED`.

A direct legacy admission would first need a verified S10 parent/cumulative lineage or a new independently derived optimization against an admitted stable source. F-PE17 does not reconstruct that parent from the cumulative S11 patch.

## Target B — current SWAP5

The core S11 ownership problem is already represented by current SWAP5 architecture.

### Explicit active-sized Richards workspace

Current `src/solver/mod_reference_richards_workspace.f90` defines `reference_richards_workspace_t` with active-sized allocatable solver scratch including:

- lower/main/upper Jacobian bands;
- residual and update vectors;
- tridiagonal factorization scratch;
- source/sink vectors;
- constitutive-provider theta/K/capacity/dKdh buffers;
- current Newton dK/dh buffer;
- old-head and vertical-flux/head-gradient buffers;
- band-fallback matrix, RHS and pivots;
- convergence flags;
- optional warm-start scratch.

The workspace has explicit initialize/reset/release operations and payload accounting. It is therefore not relying on legacy procedure-local SAVE arrays for the Richards/Newton storage problem S11 addressed.

### Solver history separated from scratch

Current `src/runtime/mod_a23bu_worker_execution_context.f90` separately defines:

```text
a23bu_solver_history_t
  flwarn
  iwarn
  nstep
```

which is structurally the same three-value solver-history concern isolated by S11, while separate worker/reference workspace types own disposable numerical scratch.

Current qualification history for F-SI06/F-VQ13 explicitly records the ownership boundary that reporting/history stays separate from committed physical state while solver scratch remains worker/job-owned. Current semantics need not be byte-for-byte the historical S11 implementation in order for the old optimization to be superseded as a port target.

### Target-B classification

For the current admitted SWAP5 architecture, historical S11 is:

`E — ARCHITECTURALLY SUPERSEDED / EQUIVALENT OWNERSHIP SEMANTICS ALREADY IMPLEMENTED`.

This is an architectural disposition, not inheritance of S11 evidence by current SWAP5. Current SWAP5 remains governed by its own F-SI/F-KT/F-VQ qualification authorities.

Mechanical application of `S11_from_S10.patch` would conflict with current solver/runtime ownership and is prohibited.

## Important residual performance question

The fact that the S11 ownership model is already implemented does **not** prove that current SWAP5 reuses every workspace across the longest useful worker lifetime or that every current allocation is optimal.

Current allocation lifetime and reuse must be measured separately against current code. Any avoidable current per-call allocation would be a new SWAP5 performance candidate, not an unfinished S11 port.

That distinction is the natural next performance decision surface after F-PE17.

## IMPLEMENT decision

```text
TARGET_A = NO_MUTATION_S10_PARENT_LINEAGE_NOT_CLOSED
TARGET_B = NO_MUTATION_S11_ARCHITECTURE_ALREADY_SUPERSEDED
```

## Closeout

```text
F-PE17 = CLOSED_HISTORICAL_B_CURRENT_ARCHITECTURE_SUPERSEDED
HISTORICAL_S11 = B_EXACT_MEMORY_OWNERSHIP_OPTIMIZATION
TARGET_A = D_DIRECT_ADMISSION_NOT_CLOSED
TARGET_B = E_ARCHITECTURALLY_SUPERSEDED
PRODUCTION_SOURCE_CHANGE = NONE
LEGACY_SOURCE_CHANGE = NONE
WHOLE_MODEL_SPEEDUP_CLAIM = NONE
```

Next permitted action: measure current SWAP5 workspace/allocation lifetime on the admitted typed Richards route and determine whether current code has avoidable per-call materialization despite the correct ownership architecture. Do not reopen S11 merely because such a new hotspot is found.
