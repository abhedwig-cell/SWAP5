# F-PE-MULTI04 — production application-context worker-local groundwater parallel admission

Date: 2026-09-27

Status: `PREREGISTERED_PRODUCTION_ADMISSION`

Parent authorities:
- F-PE-MULTI02 / PR #662
- F-PE-MULTI03 / PR #664

Canonical base:
`integration/f-ci-canonical@0ce2bbf8eb4bfdbbfc7702f1c10e11410f7aec88`

Branch:
`work/f-pe-multi04-production-groundwater-parallel-admission`

## Purpose

Production-admit the already qualified worker-local groundwater parallel execution architecture into the real groundwater application context.

This workunit is not allowed to change Richards physics, temporal policy, coupling equations, tangent mathematics or transaction semantics. It may only introduce the ownership, scheduling and execution plumbing required to run independent tile trials concurrently.

## Qualified research inputs

MULTI02 established:
- one shared mutable Reference backend may not be called concurrently;
- independent worker-local mutable backends can run real production-shaped groundwater trials concurrently;
- q and tangent remain exact;
- the discrete retry/nonlinear route remains exact;
- homogeneous N=1,000 speedup clears 1.5x at 2 workers and 2.2x at 4 workers.

MULTI03 established a bounded deterministic scheduler:
- compute the ordinary static worker assignment;
- compute predicted max/mean load from immutable pre-trial predecessor-history cost information;
- if predicted ratio <=1.20, retain static assignment;
- if predicted ratio >1.20, use deterministic descending-cost least-loaded-bin assignment;
- preserve canonical result slots and canonical aggregation/publication order.

The qualified P1 hybrid candidate produced:
- ordering 0: 1.854475x at 2 workers, 2.388483x at 4 workers;
- ordering 1: 1.873259x at 2 workers, 2.317263x at 4 workers;
- exact q/tangent;
- exact transaction/retry/nonlinear/backtracking diagnostics;
- correct accepted-origin/candidate lifecycle.

## Production architecture boundary

Current production bootstrap binds every groundwater participant to one shared mutable `fmr_serialized_reference_backend_t`.

Current `application_context_trial_cell_heads` iterates cell by cell and tile by tile and calls `registry%trial_from_origin` serially.

MULTI04 may change that execution plumbing, but must preserve the existing serial route as the default until admission closes.

### Required ownership model

- participant accepted-origin state remains per tile;
- committed state remains per tile;
- candidate state remains per tile;
- temporal-history state remains per tile;
- mutable Reference backend/workspace is worker-local;
- one worker-local backend may execute multiple tiles sequentially;
- no mutable backend may be active on two threads simultaneously;
- no tile may have more than one live candidate;
- the worker that created a live candidate must remain identifiable until discard or commit;
- discard and commit must not accidentally target a different mutable backend if backend-local state is relevant.

### Required execution model

Production context may expose an opt-in worker count.

Default:
`1 worker`

The default serial semantics must remain the existing authority.

For worker counts >1:
- determine assignment before trial execution;
- use only immutable pre-trial information;
- apply the MULTI03 bounded hybrid rule;
- execute worker-owned tiles concurrently;
- write all tile results into canonical tile-indexed slots;
- aggregate cells only after the parallel phase, in canonical cell/tile order;
- on any tile failure, terminate publication, discard all live candidates deterministically and return the existing application-context participant failure status.

No dynamic work stealing is admitted by MULTI04.

## Configuration boundary

Worker count must be explicit and bounded.

Initial admitted values:
- 1
- 2
- 4

Unsupported values must fail closed or resolve to the documented serial default. Silent arbitrary thread-count expansion is not admitted.

Parallel mode must not alter standalone production execution.

## Frozen physics and numerical semantics

MULTI04 may not change:
- Richards equations;
- hydraulic constitutive functions;
- SWKIMPL;
- nonlinear convergence tolerances;
- retry scale or retry limit;
- c = 0.65 history-aware temporal coefficient;
- temporal floor = 1e-5 cm;
- BALTOL02;
- tangent refresh mathematics;
- tangent cache semantics;
- MODFLOW6 equations;
- mass-ledger equations;
- accepted-state revision semantics;
- publication order.

## P0 — production ownership and default-off wiring

Required before parallel execution is considered admitted:
- worker-local backend storage has explicit lifetime under the production bootstrap;
- serial/default configuration remains byte-semantic equivalent at the application-context API;
- participant handles, committed state and ledgers are not duplicated or shared incorrectly;
- context release/close destroys worker-local storage only after no context/candidate is live;
- repeated context materialization does not leak worker state.

P0 must include a default/1-worker preservation test.

## P1 — production application-context parallel trials

Run real `application_context_trial_cell_heads` through the production bootstrap with 1/2/4 workers.

Require:
- exact per-tile q;
- exact per-tile tangent;
- exact cell aggregation;
- exact discrete-route diagnostics;
- deterministic assignment for repeated identical state;
- deterministic canonical result order;
- no candidate/state/ledger leakage;
- abort/discard returns context to quiescent state.

Frozen speed gates on sufficiently large N:
- 2-worker speedup >=1.5x;
- 4-worker speedup >=2.2x.

## P2 — heterogeneous production-shaped scheduling

Use the retained history-cost mixed authority and both frozen orderings through the real application context.

Require:
- bounded hybrid scheduler selects STATIC when predicted ratio <=1.20;
- bounded hybrid scheduler selects COST_AWARE when predicted ratio >1.20;
- selected predicted max/mean load <=1.20;
- 2-worker speedup >=1.5x;
- 4-worker speedup >=2.2x;
- selected runtime <=1.02 * ordinary static runtime;
- semantic identity remains exact.

## P3 — commit, abort and ledger semantics

Production qualification must exercise:
- trial -> tangent -> preflight -> prepare ledgers -> commit swaps -> commit ledgers;
- trial -> discard;
- trial failure -> global deterministic discard;
- prepublication abort;
- exactly-once committed revision increment;
- exactly-once ledger publication;
- no revision increment on discard or abort;
- no stale worker ownership after candidate resolution.

## P4 — live MODFLOW6 coupling

At least one admitted live MODFLOW6 application-context path must run with worker count >1.

Require:
- same MODFLOW package slot publication order;
- same hcof/rhs semantics;
- same accepted coupling decisions;
- same water/mass accounting within the existing exact authority;
- no production fallback to approximate coupling physics.

## Thread-safety qualification

Before final admission:
- OpenMP build/run must be green;
- available thread/race sanitization or equivalent repository-backed concurrency diagnostics must be run where supported;
- worker-local mutable objects must have no shared write surface;
- shared read-only configuration must be documented as such.

## Decision outcomes

MULTI04 closes with one of:
- `CLOSED_PRODUCTION_PARALLEL_ADMITTED`
- `CLOSED_PRODUCTION_PARALLEL_DEFAULT_OFF_ONLY`
- `CLOSED_REJECTED_THREAD_SAFETY`
- `CLOSED_REJECTED_SEMANTICS`
- `CLOSED_REJECTED_SPEED`
- a concrete external/live-coupling blocker.

No gate may be relaxed after observation.

## Immediate implementation sequence

1. add explicit default-serial parallel configuration to production bootstrap/context;
2. add worker-local backend ownership without changing trial execution;
3. qualify default/1-worker preservation;
4. add explicit registry/context trial-on-worker-backend path with candidate backend ownership tracking;
5. enable deterministic static parallel execution;
6. add bounded hybrid scheduler;
7. qualify commit/discard/ledger lifecycle;
8. qualify live MODFLOW6;
9. only then close and canonical-admit production parallel execution.
