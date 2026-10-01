# F-PE-MIQUAL05 result — dynamic-top pre-failure event-window qualification

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL05_DYNAMIC_TOP_EVENT_WINDOW`

Qualification authority:

- workflow run: `36822212173`;
- job: `110240027775`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked after execution:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

The canonical delta since MIQUAL05 preregistration is documentation/status-only PPA-WU05A8 material and does not touch the MIQUAL05 dependency surface.

## Aggregate result

All 20/20 frozen 64-interval reference windows complete.

Reference-valid by rainfall:

- DRY: 5/5;
- MODERATE: 5/5;
- WET: 5/5;
- PONDING: 5/5.

All 20/20 adaptive windows also complete and pass the physical and manager-route gates.

Classification:

`QUALIFIED_MIQUAL05_DYNAMIC_TOP_EVENT_WINDOW`.

## Dynamic-top exposure

The qualification bank genuinely exercises the intended surface physics.

Reference route exposure across the bank:

- surface-flux intervals: 1,135;
- ponded-head intervals: 33;
- ponded-head-linear-runoff intervals: 112.

Examples:

- B12_N64_T49 / PONDING:
  - 8 surface-flux intervals;
  - 7 ponded-head intervals;
  - 49 linear-runoff intervals;
  - cumulative runoff about 0.43483 cm.
- B12_N32_T25 / WET:
  - 39 surface-flux intervals;
  - 19 ponded-head intervals;
  - 6 linear-runoff intervals;
  - cumulative runoff about 0.00216 cm.
- B12_N32_T25 / PONDING:
  - 1 surface-flux interval;
  - 6 ponded-head intervals;
  - 57 linear-runoff intervals;
  - cumulative runoff about 0.57266 cm.

Thus the positive result is not a dry/flux-only surrogate.

## Physical equivalence

Across all 20 adaptive windows:

- reduced route = 64/64 intervals;
- reduced fraction = 100%;
- fallback count = 0;
- bypass count = 0;
- accepted-origin leak = 0;
- theta difference = zero at reported precision;
- pressure-head difference = effectively machine precision;
- ponding-depth difference = zero at reported precision;
- cumulative runoff difference = zero at reported precision;
- physical ledgers remain around 1e-14 to 1e-13 cm or zero;
- final saturated-tail identity agrees.

Dynamic-top and moving-interface ownership are exercised together.

B12_N32_T25 / WET and / PONDING each contain two ownership events on both full and adaptive trajectories with identical direction/order.

## Work result

Geometric-mean deterministic work ratio:

`0.77204`.

Equivalent deterministic nonlinear-work reduction is about 22.8%.

The diagnostic geometric-mean wall ratio is about:

`0.93403`.

Because the frozen window contains only 64 intervals, MIQUAL05 does not promote this wall ratio to a stable end-to-end speed claim.

## Interpretation

MIQUAL05 closes the principal single-column physical uncertainty left after MIQUAL03.

The moving-interface manager has now qualified across:

- fixed-flux drying and infiltration diversity;
- dynamic surface-flux behavior;
- ponding;
- linear runoff;
- simultaneous dynamic-top and moving-interface events;
- two geometries;
- multiple hydraulic archetypes within the repository-backed bank.

The remaining important question is no longer local moving-interface physics. It is whether this capability produces useful end-to-end speed in production-shaped SWAP Heritage execution once wrapper, process and orchestration overhead are included.

## Qualified claim boundary

Qualified:

- 20/20 bounded dynamic-top reference/adaptive windows;
- true ponding and runoff exposure;
- exact practical physical equivalence under frozen gates;
- 100% reduced-route use;
- zero fallback/bypass;
- about 22.8% deterministic work reduction.

Not qualified:

- long-horizon WET/PONDING reference solvability;
- whole-SWAP wall-clock speedup;
- MultiSWAP throughput gain;
- production-default replacement.

## Consequence

Proceed to production-shaped SWAP Heritage end-to-end integration and benchmarking.

Do not open another local moving-interface micro-study unless a production-shaped run exposes a specific manager failure.

## Production boundary

No production-default change.

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
