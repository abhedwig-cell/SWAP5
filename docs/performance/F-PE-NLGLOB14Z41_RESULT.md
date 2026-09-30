# F-PE-NLGLOB14Z41 result — real reduced HeadCalc active-dimension/profile-size scaling

Date: 2026-09-30

Status:

`QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY`

Qualification authority:

- workflow run: `36774027882`;
- job: `110087301246`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z41-headcalc-scaling@a771d63a0b6198ee5beeabf699a621fb0a388538`

## Aggregate result

All six frozen physical cases pass.

The scaling benchmark classifies:

`QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY`.

The reduced HeadCalc timing becomes increasingly favorable as profile size and removed nonlinear-tail size increase, but the preregistered full gain class is not reached because neither N=64 case crosses the strict <0.90 threshold.

## Case results

### N16_A13

- full / active nodes: 16 / 13;
- active fraction: 0.8125;
- nonlinear iterations: 2 / 2;
- Jacobian builds: 2 / 2;
- timing ratio: `0.96091`;
- full/reduced physical differences: effectively zero.

### N16_A12

- full / active nodes: 16 / 12;
- active fraction: 0.75;
- timing ratio: `0.95078`;
- physical differences: effectively zero.

### N32_A26

- full / active nodes: 32 / 26;
- active fraction: 0.8125;
- nonlinear iterations: 3 / 3;
- timing ratio: `0.94703`;
- physical differences: effectively zero.

### N32_A24

- full / active nodes: 32 / 24;
- active fraction: 0.75;
- timing ratio: `0.91726`;
- physical differences: effectively zero.

### N64_A52

- full / active nodes: 64 / 52;
- active fraction: 0.8125;
- nonlinear iterations: 3 / 3;
- timing ratio: `0.92776`;
- physical differences: effectively zero.

### N64_A48

- full / active nodes: 64 / 48;
- active fraction: 0.75;
- timing ratio: `0.90506`;
- physical differences: effectively zero.

## Scaling interpretation

The timing signal is monotone in the intended direction.

At comparable active fractions:

- N=16 gives roughly 4–5% solve-service gain;
- N=32 gives roughly 5–8% gain;
- N=64 gives roughly 7–9.5% gain.

At fixed profile size, removing a larger tail is consistently faster:

- N16: 0.75 active fraction beats 0.8125;
- N32: 0.75 beats 0.8125;
- N64: 0.75 beats 0.8125.

The N64_A48 case is close to the preregistered 10% gain boundary but remains just above it at about 0.905.

## Physical result

Across all six cases:

- both services converge;
- full and reduced saturated-tail identity agree;
- h differences are at or below extreme roundoff-scale values;
- theta differences are zero;
- top-flux differences are zero;
- candidate ledger differences are zero;
- nonlinear-iteration counts match;
- Jacobian-build counts match.

Thus the scaling trend is a performance effect, not a consequence of altered convergence or physics.

## Qualified claim boundary

Qualified:

- real reduced HeadCalc scales favorably with increasing profile size;
- larger reconstructed-tail fraction improves timing;
- N=32 and N=64 cases show material directionally favorable solve-service gains;
- physical equivalence is preserved across the frozen scaling matrix.

Not qualified:

- the full Z41 timing-gain class;
- >=10% gain at N=64 under the frozen matrix;
- trajectory-level wall-clock gain;
- whole-SWAP speedup;
- production admission.

## Consequence

The next useful step is no longer another microkernel scaling point.

Open one representative larger-profile trajectory-level production-shaped benchmark using the real reduced HeadCalc manager route.

That benchmark should measure:

- adaptive/full physical trajectory comparison;
- fallback incidence;
- active-dimension occupancy;
- cumulative solve-service work;
- actual wall-clock timing for the trajectory;
- manager overhead inside the real service path.

The purpose is to determine whether the measured per-solve scaling benefit survives trajectory orchestration.

## Production boundary

Research scaling only.

`LEGACY_NUMERICS` remains production default.
