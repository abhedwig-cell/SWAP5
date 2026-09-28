# F-HYDROFIT01 P1 — forward and estimator design

Status: DESIGN FROZEN BEFORE IMPLEMENTATION

## Key finding from canonical SWAP5

The admitted default provider is not globally identical to the textbook Mualem-Van Genuchten equations.

For the common branch with `cofgen(9) > -0.01 cm`, SWAP5 uses a linear near-saturation retention continuation between `h=-0.01 cm` and saturation. Conductivity also contains explicit dry and near-saturation guards.

For `cofgen(9) <= -0.01 cm`, retention and conductivity use an entry-head/transition construction around `1.05*cofgen(9)`.

Therefore F-HYDROFIT01 must distinguish:

1. **textbook-MvG fit semantics**, useful for comparison and external datasets;
2. **SWAP-native fit semantics**, which evaluate the exact selected SWAP5 constitutive route.

The first production candidate for SWAP parameter generation should use SWAP-native semantics. A textbook fit followed by parameter transfer is not assumed equivalent.

## Initial SWAP-native parameter mapping

For the default MvG family, current canonical provenance binds:

- `cofgen(1)` -> residual/asymptotic water content, `theta_r`;
- `cofgen(2)` -> saturated water content, `theta_s`;
- `cofgen(3)` -> conductivity scale/cap, `Ks`;
- `cofgen(4)` -> `alpha`;
- `cofgen(5)` -> conductivity exponent `lambda/l`;
- `cofgen(6)` -> `n`;
- `cofgen(7)` -> `m`;
- `cofgen(9)` -> entry/transition head controlling the admitted branch family.

For the initial conventional Mualem restriction, `m=1-1/n`. The status and value of `cofgen(9)` must be explicit configuration. It must not be silently optimized until a dedicated identifiability experiment justifies doing so.

## P1 interfaces

### Observation

Each observation records:

- family: theta or K;
- pressure head in cm, using SWAP sign convention;
- observed value;
- optional standard deviation;
- optional provenance identifier.

K observations must be positive when log residuals are selected.

### Fit configuration

Explicit fields:

- forward semantics: textbook_mvg or swap_default_mvg;
- active/fixed parameter mask;
- initial parameter vector;
- lower/upper bounds;
- retention residual transform;
- conductivity residual transform;
- family scaling rule;
- multi-start seed set;
- optimizer tolerances.

### Fit result

Must expose:

- physical parameter vector;
- transformed optimizer coordinates where relevant;
- objective total and by family;
- residual vector;
- termination status;
- function/Jacobian evaluation counts;
- active bounds;
- local Jacobian;
- singular values/condition diagnostics;
- per-start result and selected optimum.

## P1/P2 implementation strategy

Research tooling will be Python because robust bounded least-squares and linear-algebra diagnostics are readily available there. The forward equations must be implemented independently and tested against canonical SWAP5 outputs. Production Fortran remains unchanged.

The optimizer abstraction must allow replacing the backend without changing observation, configuration or result semantics.

## First tests

T0 parameter transform round-trip.

T1 theta monotonicity and physical bounds for valid interior synthetic parameters.

T2 K positivity and saturation limit.

T3 textbook synthetic exact recovery.

T4 SWAP-native forward matrix compared with canonical Fortran provider across:
- saturated and near-saturated heads;
- ordinary unsaturated heads;
- very dry heads;
- both entry-head branch families.

T5 synthetic SWAP-native inverse recovery from multiple initial points.

T6 deliberate information removal produces degraded Jacobian singular-value diagnostics.

## Critical non-equivalence test

Construct a case containing observations close enough to saturation that textbook retention and the SWAP near-saturation continuation differ measurably. Fit both semantics to the same synthetic SWAP-native data.

Expected result: the textbook model may achieve a plausible fit but must not reproduce the exact generating curve. This test protects against later replacing the SWAP-native evaluator with a convenient library formula.
