# F-PE-NLGLOB14Z41 preregistration — real reduced HeadCalc active-dimension/profile-size scaling

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z40: `QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`;
- real full/reduced HeadCalc physical equivalence qualified on the focused 16-node set;
- Z40 geometric-mean timing ratio ~0.974;
- Z39: remaining persistent manager overhead is <0.3% of actual Richards solve cost.

## Purpose

Determine how actual reduced Heritage/reference solve-service timing scales with:

- full profile node count;
- active nonlinear node count;
- active fraction of the profile.

Z41 uses the exact real reduced HeadCalc route qualified in Z40.

## Frozen case matrix

### O05 scaling matrix

Full profile sizes:

- N = 16;
- N = 32;
- N = 64.

For each N evaluate:

- active fraction 0.75:
  - n = 12, 24, 48;
- active fraction 0.50:
  - n = 8, 16, 32.

Total O05 cases: 6.

### B12 large-profile holdout

At N = 64 evaluate:

- n = 48;
- n = 32.

Total frozen cases: 8.

## Common physical setup

Reuse the Z40 compiled full/reduced HeadCalc route.

For each case:

- dz = 10 cm;
- hydrostatic accepted origin:
  `h_i = 10*(i-n)` cm;
- contiguous saturated tail n:N;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- K implicit mode = 0;
- conductivity mean method = 1;
- max iterations = 8.

The stub geometry is compiled separately for N=16, 32 and 64. Material parameters and n are runtime inputs.

## Frozen physical gates

Reuse Z40 gates for every case:

- full and reduced service converge;
- finite candidate state;
- reduced active dimension equals frozen n;
- manager route = reduced;
- published candidate has N nodes;
- full/reduced tail identity equal;
- max head difference <= 5e-5 cm;
- max theta difference <= 5e-8;
- top-flux difference <= 5e-8 cm/d;
- ledger difference <= 5e-7 cm;
- immutable accepted origin.

Any failure:

`Z41_SCALING_PHYSICAL_MISMATCH`.

## Frozen timing protocol

Reuse Z40:

- 50 warm-up calls/path;
- 5 blocks;
- 200 calls/block;
- alternating path order;
- persistent full/reduced workspaces and manager context;
- `cpu_time`;
- report median reduced/full ratio.

## Frozen scaling diagnostics

Report per case:

- N;
- n;
- active fraction n/N;
- full/reduced nonlinear iterations;
- full/reduced Jacobian builds;
- full median time;
- reduced median time;
- timing ratio.

Aggregate:

1. geometric mean timing ratio across all 8 cases;
2. geometric mean for N=16 O05 pair;
3. geometric mean for N=32 O05 pair;
4. geometric mean for N=64 O05 pair;
5. geometric mean for N=64 B12 pair;
6. within each N/material, whether 50% active is faster than 75% active.

## Frozen classifications

### `QUALIFIED_Z41_REAL_RICHARDS_SCALING_GAIN`

Require:

- 8/8 physical cases pass;
- geometric mean across all cases <0.95;
- O05 N=32 pair geometric mean <0.95;
- O05 N=64 pair geometric mean <0.90;
- B12 N=64 pair geometric mean <0.95;
- for O05 N=16,32,64 and B12 N=64, the 50%-active ratio is no worse than the 75%-active ratio +0.03.

### `QUALIFIED_Z41_REAL_RICHARDS_SCALING_PHYSICAL_ONLY`

All physical gates pass but the speedup scaling criteria above are not all satisfied, provided aggregate timing is not a regression.

### `Z41_REAL_RICHARDS_SCALING_REGRESSION`

All physical gates pass, but aggregate geometric mean ratio >1.05.

### `Z41_SCALING_EXECUTION_INVALID`

Build/timer/checksum invalid.

## Interpretation boundary

Z41 is still a single-step solve-service benchmark.

It may establish dimension-dependent HeadCalc speedup, but not trajectory-level or whole-SWAP wall-clock gain.

## Consequence

If scaling gain qualifies, proceed to one small trajectory-level production-shaped manager benchmark.

If physical-only, identify which fixed HeadCalc components limit scaling before trajectory timing.

If physical mismatch, localize only the newly exposed profile-size dependency.

## Stop rules

Do not:

- broaden beyond the frozen 8 cases;
- change manager physics;
- change forcing/dt after exposure;
- infer whole-SWAP speedup;
- change production default.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z41

BASELINE: `657a7d5419fe83bbe2fb4f3a5a47386b0e5d4134`

BRANCH: `research/f-pe-nlglob14z41-real-richards-scaling`

NEXT SAFE STEP: compile the Z40 fixture at N=16,32,64 and execute the frozen 8-case scaling matrix.

## Production boundary

Research scaling only.

`LEGACY_NUMERICS` remains production default.
