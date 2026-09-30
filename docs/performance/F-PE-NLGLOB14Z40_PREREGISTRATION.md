# F-PE-NLGLOB14Z40 preregistration — real reduced Heritage solve-service binding and focused A/B timing

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z39: `QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED`;
- Z38: persistent manager fast path established;
- Z36: compact O05/O14/B12 holdout physical equivalence;
- Z29/Z31R: reduced moving-interface physics and independent driving qualified in research scope.

## Purpose

Bind the actual compiled Heritage/reference Richards solve service to the reduced active dimension and compare it directly with the full 16-node service.

This is the first compiled full-vs-reduced HeadCalc A/B benchmark.

## Key binding contract

HeadCalc explicit geometry is authoritative from:

`parameter_set%active_nodes`.

Therefore a reduced solve may call the same reference solver with active n=12 or n=13.

All evaluation providers must be shape-consistent with the reduced request.

Z40 therefore constructs explicit reduced provider views:

- reduced constitutive parameter/provider with the first n node parameter columns;
- reduced source/sink provider with n-node zero source/sink arrays;
- unchanged fixed-flux top-boundary provider.

No new constitutive physics or solver kernel is introduced.

## Frozen case set

Use exactly four cases:

1. O05_T13 — O05, tail 13:16, active n=13;
2. O05_T12 — O05, tail 12:16, active n=12;
3. O14_T13 — O14, tail 13:16, active n=13;
4. B12_T13 — B12, tail 13:16, active n=13.

Common geometry and forcing:

- full profile: 16 nodes;
- dz = 10 cm;
- full accepted origin pressure head:
  `h_i = 10 * (i - tail_start)` cm;
- contiguous saturated lower tail;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- prescribed qbot = 0;
- K implicit mode = 0;
- conductivity mean method = 1;
- max iterations = 8;
- zero sources/sinks.

## Full path

From the immutable full origin:

1. call the actual reference Richards solver on n=16;
2. retain the full candidate and diagnostics.

## Reduced path

From the same immutable full origin:

1. derive the manager active view;
2. prepare persistent reduced geometry/request at n;
3. bind reduced constitutive/source-sink providers at n;
4. call the same actual reference Richards solver at n;
5. reconstruct nodes n+1:16 analytically for qbot=0 from the solved guard-node head;
6. set reconstructed tail water content to theta_s;
7. materialize the full 16-node candidate through the persistent manager;
8. publish/select the reduced manager route.

The full result may not repair the reduced candidate.

## Frozen physical gates

For each case require:

- both services converge;
- all candidate values finite;
- reduced active dimension exactly frozen n;
- manager route = reduced;
- published candidate has 16 nodes;
- full and reduced resulting saturated-tail identity equal;
- max |h_reduced-full| <= 5e-5 cm;
- max |theta_reduced-full| <= 5e-8;
- top-flux difference <= 5e-8 cm/d;
- candidate storage/flux ledger difference <= 5e-7 cm;
- no accepted-origin mutation.

If any case fails a physical gate:

`Z40_REAL_REDUCED_PHYSICAL_MISMATCH`.

If reduced provider/service binding fails:

`Z40_REDUCED_PROVIDER_OR_SOLVER_BINDING_FAILED`.

## Frozen timing protocol

Only after physical gates pass.

For each case:

- 50 warm-up calls per path;
- 5 measured blocks;
- 200 calls per block;
- immutable origin/request per call;
- persistent full and reduced workspaces;
- persistent manager buffers;
- alternate full/reduced block order;
- use `cpu_time`;
- report median time per operation;
- checksum output to prevent elimination.

The reduced timing includes:

- manager view/request refresh;
- reduced provider bindings already allocated/persistent;
- reduced Heritage solve;
- tail reconstruction;
- full candidate materialization;
- manager selection.

## Frozen timing classifications

### `QUALIFIED_Z40_REAL_REDUCED_RICHARDS_GAIN`

Require:

- all 4 physical cases pass;
- reduced/full median timing ratio <0.95 in at least 3/4 cases;
- geometric mean timing ratio <0.95;
- no case ratio >1.05.

### `QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`

All physical gates pass, but timing does not satisfy the gain criterion and does not exceed regression criterion.

### `Z40_REAL_REDUCED_RICHARDS_REGRESSION`

All physical gates pass, but geometric mean timing ratio >1.05 or any case >1.10.

### `Z40_TIMING_EXECUTION_INVALID`

Timer/build/checksum invalid after physical gates pass.

## Consequence

A positive timing gain authorizes a small trajectory-level production-shaped benchmark and production-admission candidate preparation.

A physical-only or timing-regression result requires profiling the actual reduced solve-service path, not reopening moving-interface physics.

## Stop rules

Do not:

- tune physical gates after exposure;
- change case geometry or forcing;
- alter HeadCalc physics;
- introduce a benchmark-only solver;
- silently use the full result as reduced state;
- broaden to long trajectories inside Z40;
- change production default.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z40

BASELINE: `371a8a986d94690878fcb0c22ac6c4d0676e9692`

BRANCH: `research/f-pe-nlglob14z40-real-reduced-richards-ab`

NEXT SAFE STEP: implement reduced provider views and run one compiled four-case full/reduced Heritage A/B benchmark.

## Production boundary

Research binding only.

`LEGACY_NUMERICS` remains production default.
