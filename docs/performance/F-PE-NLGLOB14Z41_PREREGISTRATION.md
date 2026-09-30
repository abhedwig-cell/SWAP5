# F-PE-NLGLOB14Z41 preregistration — real reduced HeadCalc active-dimension/profile-size scaling

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z40: `QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`;
- the real Heritage/reference HeadCalc route executes at reduced active n=12/13 and reproduces the full candidate on the frozen four-case holdout;
- Z40 16-node geometric-mean reduced/full timing ratio = `0.97394`;
- Z39: residual persistent-manager overhead is <0.3% of actual Richards solve time.

## Purpose

Determine how real reduced HeadCalc wall-clock gain scales with:

1. full profile node count;
2. active nonlinear node count;
3. inactive/reconstructed lower-tail fraction.

Z41 reuses the exact Z40 reduced-provider / reduced-HeadCalc / manager-publication route.

It does not alter moving-interface physics, provider semantics, manager semantics, timing code shape or production defaults.

## Frozen material

Use O05 only.

This workunit isolates scaling, not material variability; O05 is already qualified in Z40 and the Z36 heterogeneous holdout established O14/B12 portability for same-origin reduced physics.

## Frozen scaling matrix

Use exactly these six geometries:

| Case | Full nodes | Active nodes | Reconstructed tail nodes | Active/full |
|---|---:|---:|---:|---:|
| N16_A13 | 16 | 13 | 3 | 0.8125 |
| N16_A12 | 16 | 12 | 4 | 0.7500 |
| N32_A26 | 32 | 26 | 6 | 0.8125 |
| N32_A24 | 32 | 24 | 8 | 0.7500 |
| N64_A52 | 64 | 52 | 12 | 0.8125 |
| N64_A48 | 64 | 48 | 16 | 0.7500 |

For N=32 and N=64, repeat the O05 hydraulic parameter columns consistently across the profile.

Common geometry/forcing:

- dz = 10 cm;
- hydrostatic qbot=0 lower tail;
- full accepted origin pressure head:
  `h_i = 10 * (i - tail_start)` cm;
- at least one node immediately above active guard remains unsaturated;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- prescribed qbot = 0;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- max iterations = 8;
- zero sources/sinks.

## Full path

For each case:

1. build full typed request at N;
2. call the actual Heritage/reference Richards service at N;
3. retain full candidate and diagnostics.

## Reduced path

From the same immutable origin:

1. derive reduced active geometry at A;
2. bind O05 constitutive/source-sink providers at A;
3. call the same actual Heritage/reference Richards service at A;
4. reconstruct nodes A+1:N analytically for qbot=0;
5. materialize a full N-node candidate through the qualified manager seam;
6. publish/select the reduced route.

The full result may not repair the reduced result.

## Frozen physical gates

For every case require:

- both solves converge;
- all candidate values finite;
- reduced active dimension exactly A;
- manager route = reduced;
- published candidate has N nodes;
- full/reduced saturated-tail identity equal;
- max |h reduced-full| <= 5e-5 cm;
- max |theta reduced-full| <= 5e-8;
- top-flux difference <= 5e-8 cm/d;
- candidate ledger difference <= 5e-7 cm;
- no accepted-origin mutation.

Any failure:

`Z41_SCALING_PHYSICAL_MISMATCH`.

## Frozen timing protocol

Use the same compiled-process method as Z40.

Per case:

- 50 warm-up calls per path;
- 5 measured blocks;
- 200 calls per block;
- immutable origin each call;
- persistent full/reduced workspaces and manager buffers;
- alternate full/reduced block order;
- `cpu_time`;
- checksum anti-optimization;
- compile both routes with identical `-O3`.

Report:

- median full time/op;
- median reduced time/op;
- reduced/full timing ratio;
- full/reduced nonlinear iterations;
- full/reduced Jacobian builds;
- active/full ratio.

## Frozen scaling questions

Q1. At fixed active fraction, does timing ratio decrease as N increases?

Q2. At fixed N, is active fraction 0.75 at least as fast as active fraction 0.8125?

Q3. Does any N>=32 case reach a material solve-service gain <0.95 timing ratio?

Q4. Does N=64 demonstrate >=10% solve-service gain (<0.90 ratio) in either active-fraction family?

## Frozen classifications

### `QUALIFIED_Z41_HEADCALC_SCALING_GAIN`

Require:

- all six physical cases pass;
- Q1 true in both active-fraction families within 0.02 timing-ratio tolerance for measurement noise;
- Q2 true at N=16,32,64 within 0.02;
- at least 3/4 N>=32 cases have timing ratio <0.95;
- both N=64 cases have timing ratio <0.95;
- at least one N=64 case has timing ratio <0.90.

### `QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY`

All physical cases pass and timing improves with scale, but the gain thresholds above are not fully reached.

### `Z41_HEADCALC_SCALING_NEUTRAL`

All physical cases pass, but no clear scale-dependent timing improvement is observed.

### `Z41_HEADCALC_SCALING_REGRESSION`

Any N>=32 case has timing ratio >1.10 or scaling systematically worsens with N.

### `Z41_SCALING_EXECUTION_INVALID`

Build/timer/checksum invalid.

## Consequence

A positive scaling gain authorizes a small trajectory-level production-shaped timing benchmark and preparation of a production-admission candidate.

A trend-only result authorizes one representative larger-profile trajectory benchmark before admission work.

Neutral/regression requires profiling the actual reduced HeadCalc path before broader rollout.

## Stop rules

Do not:

- change matrix after timing exposure;
- tune profile geometry;
- alter Z40 physics/provider binding;
- infer whole-SWAP speedup directly;
- broaden to BOFEK-wide runs;
- change production default.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z41

BASELINE: `657a7d5419fe83bbe2fb4f3a5a47386b0e5d4134`

BRANCH: `research/f-pe-nlglob14z41-headcalc-scaling`

NEXT SAFE STEP: adapt the Z40 compiled A/B harness to the frozen six-case scaling matrix and execute one compact timing run.

## Production boundary

Research scaling only.

`LEGACY_NUMERICS` remains production default.
