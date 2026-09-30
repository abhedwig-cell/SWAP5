# F-PE-ELASTIC58 — independent temporal-budget bridge feasibility preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent branch head:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Frozen ELASTIC54/55 conservative scaling:

`alpha_global = 0.17320259355765216`.

## Independent external authority

PUB-P2E08/P2E09 is independent of the ELASTIC46-57 result chain.

It froze Reference-only coarse-versus-two-half head-infinity envelopes over:
- materials: B01, B12, O01, O05, O14, O18;
- exact effective saturation levels: 0.65, 0.85, 0.98;
- forcing classes: DRYING, NOMINAL, WETTING;
- selected common coarse dt: 0.0064 day;
- two half steps: 0.0032 + 0.0032 day.

Frozen P2E09 head-infinity envelopes:

- Se=0.65: `0.002329984405367469 cm`;
- Se=0.85: `0.024875926496918055 cm`;
- Se=0.98: `1.0304935719866082 cm`.

These are empirical Reference self-disagreement envelopes for the exact P2E08
domain. They are not production tolerances and are not extrapolated outside the
three discrete Se levels.

## Question

At the exact P2E08/P2E09 material/state/forcing/dt domain, is the already
qualified defect-indicator scaling

`E_bound = alpha_global * Binf`

small enough to fit inside the independently frozen P2E09 head-infinity
envelope?

This tests budget compatibility only.

## Boundary overlap

Use the exact P2E08 prescribed-flux bottom-mode-2 construction.

Bottom mode 2 is already inside the admitted Reference Richards temporal
indicator envelope through F-SI38.

ELASTIC58 does not exercise the research-only bottom-mode-7 extension.

This deliberately tests the budget bridge first where both authorities overlap
without a boundary-semantics extrapolation.

## Bootstrap convention

The P2E08 calibration consists of isolated first intervals and therefore does
not provide a previous accepted right derivative for the history-based defect
indicator.

For ELASTIC58 only, use:

`previous_right_derivative = 0`.

Interpretation:
- research bootstrap proxy for a pre-perturbation stationary origin;
- not a production startup policy;
- not an admitted history initialization rule.

A negative result may therefore mean either:
- the conservative scaling is too large for the independent P2E09 budget; or
- the zero-history bootstrap is too conservative.

ELASTIC58 must not distinguish those two post hoc.

## Exact bank

Run exactly 54 cases:
- 6 materials;
- 3 exact Se levels;
- 3 forcing classes;
- coarse dt = 0.0064 day.

For every case:
1. execute the same Reference coarse solve used by P2E08;
2. evaluate the admitted bottom-mode-2 defect indicator on that coarse result;
3. use zero previous right derivative;
4. execute the two half steps exactly as P2E08;
5. recompute realized `U_h_inf`;
6. compare:
   - `U_h_inf <= P2E09_limit(Se)`;
   - `alpha_global * Binf <= P2E09_limit(Se)`.

## Gates

A1. All 54 exact P2E08 physical cases execute.

A2. All coarse/half1/half2 trajectories satisfy the original P2E08 validity
rules at dt=0.0064 day.

A3. Production mode-2 temporal indicator is AVAILABLE for every coarse solve.

A4. Recomputed realized U_h_inf values remain inside the frozen P2E09
Se-specific envelopes.

A5. Frozen `alpha_global` is used bit-for-bit and not refit.

A6. Report budget-bridge pass/fail count and the maximum
`alpha_global*Binf/P2E09_limit` ratio.

A7. O0/O2 semantic outputs agree.

A8. Zero `src/**` and `reference/**` changes.

## Decision

If all 54 scaled Binf values lie inside the independent P2E09 envelopes:

`QUALIFIED_INDEPENDENT_BUDGET_BRIDGE_FEASIBILITY_CANDIDATE`.

If any case exceeds its P2E09 envelope:

`FALSIFIED_DIRECT_P2E09_BUDGET_BRIDGE`.

Either result remains research-only.

No F-CI14 numeric profile, production temporal budget, startup-history policy,
mode-7 production indicator, or controller integration is admitted by
ELASTIC58.
