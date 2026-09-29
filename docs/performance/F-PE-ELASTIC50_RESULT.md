# F-PE-ELASTIC50 — full-versus-two-half state discrepancy characterization result

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic50-full-half-discrepancy`

Qualified postimage:
`c1780a0d77f986a26e884e689cc18f6ed11969bf`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36631916401`

Job:
`109622986127`

Conclusion:
SUCCESS.

## Question

What are the actual physical state differences between one full Reference
Richards solve and two sequential half solves on the retry ladder that the
current identity-only temporal gate rejects?

## Method

ELASTIC50 bypasses the transaction identity gate for measurement only.

It uses the admitted `reference_richards_legacy_solver_t` directly with the
same:
- real BRO profile `90116260`;
- 16-node variable grid;
- default-MvG hydraulic fixture;
- bottom mode 7;
- explicit-flux top boundary;
- forcing;
- numerical tolerances;
- OFF, FIXED_1E6 and GENERATED ELAS regimes.

For each retry-ladder duration, one full solve and two sequential half solves
were executed from the same frozen initial state.

No production source changed.

## Qualification coverage

Frozen comparison points:
- 2 initial heads;
- 2 perturbation signs;
- 3 ELAS regimes;
- 9 retry-ladder durations.

Total:
`108` direct comparison points.

Results:
- all 108 executed;
- 29 points had converged full, half1 and half2 solves;
- all 29 produced finite physical discrepancy values;
- 0 / 29 were bit-identical;
- O0/O2 classifications and discrepancy values were identical;
- zero `src/**` changes.

## Primary finding

The temporal mismatch is finite and localized, not catastrophic.

For every fully converged comparison:
- `dpond = 0`;
- `dgwl = 0`;
- maximum pressure-head discrepancy occurs at node 1;
- maximum water-content discrepancy also occurs at node 1;
- full and two-half integrated storage checksums agree to roundoff-level
  differences.

Thus the identity gate is rejecting finite surface-near state differences while
the bulk storage trajectory is essentially unchanged.

## Active ELAS, negative perturbation

### h0 = 10 cm, FIXED_1E6

As requested dt is reduced:

| dt day | max abs dh cm | max abs dtheta |
|---:|---:|---:|
| 0.015625 | 0.00494407 | 4.94407e-9 |
| 0.0078125 | 0.00905701 | 9.05701e-9 |
| 0.00390625 | 0.0153402 | 1.53402e-8 |
| 0.001953125 | 0.0227286 | 2.27286e-8 |

The discrepancy increases as dt is halved over this fully converged sequence.

### h0 = 10 cm, GENERATED

| dt day | max abs dh cm | max abs dtheta |
|---:|---:|---:|
| 0.015625 | 0.0101746 | 3.05051e-8 |
| 0.0078125 | 0.0165348 | 4.95741e-8 |
| 0.00390625 | 0.0229382 | 6.87725e-8 |
| 0.001953125 | 0.0254946 | 7.64370e-8 |
| 0.0009765625 | 0.0222921 | 6.68355e-8 |

Again, the discrepancy is not monotonically reduced by smaller dt.

The same qualitative active-ELAS pattern occurs for `h0 = 2 cm`,
`delta = -0.05`.

## Active ELAS, positive perturbation

At `h0 = 10 cm, delta = +0.05`, the fully converged active-ELAS points show
the same structure.

FIXED_1E6:
- `dt=0.015625`: `dh_inf = 0.00494407 cm`;
- `dt=0.0078125`: `0.00905701 cm`;
- `dt=0.00390625`: `0.0153402 cm`;
- `dt=0.001953125`: `0.0227286 cm`.

GENERATED:
- `dt=0.015625`: `0.0101746 cm`;
- `dt=0.0078125`: `0.0165348 cm`;
- `dt=0.00390625`: `0.0229382 cm`;
- `dt=0.001953125`: `0.0254946 cm`.

The sign of the perturbation therefore does not explain the full-versus-half
surface discrepancy pattern in the strongly saturated active-ELAS cases.

## OFF behavior

OFF converges for far fewer direct comparison points.

Example, `h0=10 cm, delta=+0.05`:
- `dt=0.00390625`: `dh_inf = 1.21594 cm`;
- `dt=0.001953125`: `0.700562 cm`;
- `dt=0.0009765625`: `0.339067 cm`.

Where OFF does yield three converged solves, decreasing dt does reduce the
full-versus-half discrepancy in the expected direction.

This contrasts sharply with the active-ELAS sequences.

## Water-content relation

For the saturated active-ELAS cases, the water-content mismatch tracks the
pressure-head mismatch through the elastic storage slope.

For FIXED_1E6:
`dtheta_inf ≈ 1e-6 × dh_inf`.

For GENERATED the proportionality is correspondingly larger, consistent with
the generated node-local Ss at the surface node.

This supports the interpretation that the discrepancy is dominated by the
elastic saturated storage response at the top node rather than by ponding or
groundwater-state divergence.

## Storage conservation observation

Despite nonzero node-local discrepancies, full and two-half storage checksums
are equal to approximately machine-roundoff precision at the converged points.

Examples:

`h0=10 cm, delta=-0.05, GENERATED, dt=0.015625`
- full storage: `50.763879081900171`;
- two-half storage: `50.763879081900164`.

`h0=10 cm, delta=-0.05, FIXED_1E6, dt=0.015625`
- full storage: `50.761981249999991`;
- two-half storage: `50.761981249999991`.

The identity-only temporal rejection is therefore not identifying a visible
bulk-storage inconsistency in these cases.

## Hypotheses

H1, active-ELAS temporal-rejected attempts have finite nonzero discrepancies:
SUPPORTED.

H2, discrepancy decreases with retry dt:
FALSIFIED for the principal active-ELAS converged sequences.

H3, pressure head is the dominant state discrepancy:
SUPPORTED. The maximum discrepancy is at node 1; ponding and groundwater-level
differences are zero.

H4, GENERATED and FIXED_1E6 differ:
SUPPORTED. GENERATED produces larger node-1 pressure-head/water-content
full-half differences over the shared converged sequence.

## Interpretation

ELASTIC48 showed that active ELAS changes the limiting layer from nonlinear
solver rejection toward temporal rejection.

ELASTIC49 showed that the current Reference temporal metric maps any state
difference to `huge()`.

ELASTIC50 now shows that the underlying difference can be small, finite,
localized at the top node and compatible with essentially identical total
storage.

More importantly, the active-ELAS discrepancy does not show ordinary monotonic
decay with decreasing dt over the converged retry sequence.

Therefore the present full-half identity route should not be interpreted as a
continuous timestep-error estimator for these saturated ELAS cases.

## Decision

Classification:
`QUALIFIED_FINITE_LOCALIZED_FULL_HALF_DISCREPANCY`.

No production temporal policy change is authorized.

The next bounded workunit should compare candidate physically scaled error
measures against these observed discrepancies, including at minimum:
- pressure-head scale;
- water-content/storage scale;
- a mixed normalized norm;
- explicit treatment of saturated elastic storage.

The candidate metric must be evaluated observationally first, without replacing
the canonical gate.
