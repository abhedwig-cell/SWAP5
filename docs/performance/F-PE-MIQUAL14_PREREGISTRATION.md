# F-PE-MIQUAL14 preregistration — serialized manager break-even scaling

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Parent authorities:

- MIQUAL11: `MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`;
- MIQUAL13: `QUALIFIED_MIQUAL13_PARTIAL_DIMENSION_SCALING`.

## Purpose

Determine whether the production-shaped serialized moving-interface manager crosses runtime break-even at larger column dimensions already used by earlier qualified manager geometries.

## Frozen geometries

Exactly:

- N16 / tail start 13;
- N32 / tail start 25;
- N64 / tail start 49.

These correspond to active/full fractions:

- 13/16 = 0.8125;
- 25/32 = 0.78125;
- 49/64 = 0.765625.

N32/T25 and N64/T49 were already used in qualified pre-admission/MIQUAL work.

## Frozen runtime workload

For every geometry:

- equilibrium zero-flux physical state;
- top flux = 0;
- qbot = 0;
- no source/sink;
- no optional physics;
- SWKIMPL=0;
- conductivity mean method=1;
- MAXIT16 evidence profile;
- dt=0.00125 d;
- external full-half transaction mode;
- checkpoint -> serialized trial -> candidate -> kernel commit for every interval;
- 40,000 committed external intervals.

Variants:

- LEGACY: manager unconfigured;
- MANAGER: execution-ready manager profile.

## Preflight

Require both variants to complete 40,000/40,000 intervals with:

- zero retries;
- hard mass <=1e-8 cm;
- exact final state within 1e-12;
- MANAGER reduced route fraction =100%;
- zero fallback;
- zero bypass.

## Timing protocol

For each geometry:

- one warmup trajectory per variant;
- 7 paired repetitions;
- alternating order by pair;
- no sample deletion/substitution.

Report:

- all paired wall ratios;
- median wall ratio;
- geometric-mean wall ratio;
- median CPU ratio;
- deterministic work ratio.

## Frozen interpretation

Per geometry:

- `GAIN` if median wall <1.00 and median CPU <1.00;
- `NO_GAIN` otherwise.

Aggregate classifications:

- `QUALIFIED_MIQUAL14_BREAK_EVEN_REACHED` if at least one larger geometry (N32 or N64) is GAIN and all physical gates pass.
- `MIQUAL14_NO_BREAK_EVEN_IN_TESTED_RANGE` if N32 and N64 remain >=1.00.
- `MIQUAL14_PHYSICAL_OR_ROUTE_FAILURE` on semantic failure.
- `MIQUAL14_EXECUTION_INVALID` on invalid measurement.

## Consequence

If break-even is reached, retain the manager as a performance-relevant production candidate only for sufficiently favorable active/full dimension regimes; do not infer universal speedup.

If not reached through N64, the current manager route is not a production speed candidate and should remain research/opt-in capability until solver fixed cost is reduced.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
