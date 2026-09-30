# F-PE-ELASTIC52 — active-ELAS top-node mechanism attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic52-top-node-mechanism`

Qualified postimage:
`b4a148222b3853ccf0a9df99e582391a591d0b27`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36670245896`

Job:
`109743499344`

Conclusion:
SUCCESS.

## Question

Why does the saturated node-1 full-versus-two-half discrepancy increase over
the first retry halvings when ELAS is active?

## Frozen bank

The ELASTIC50 direct-solve bank was preserved exactly:
- real BRO profile `90116260`;
- 16-node variable grid;
- bottom mode 7;
- explicit fixed-flux top boundary;
- h0 = 2 and 10 cm;
- delta = +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- start dt = 0.015625 day;
- retry scale = 0.5;
- retry indices 0 through 8.

Qualification:
- all 108 comparison points executed;
- 29 points had converged full, half1 and half2 solves;
- all mechanism diagnostics were finite;
- O0/O2 outputs were identical;
- no production source changed.

## Node-1 balance

For the frozen route with no node-local source/sink/root sink, the converged
node-1 equation is:

`dz1 * (theta1_end-theta1_start)/dt + q_internal + qtop = 0`.

ELASTIC52 therefore observes:

- top-node pressure-head increment;
- top-node water-content increment;
- top-node storage rate;
- implied internal vertical flux term;
- node-2 pressure head;
- corresponding full, half1 and half2 values.

No replacement physics or solver equation is introduced.

## Primary attribution

The elastic constitutive response itself is internally consistent.

For every fully converged active-ELAS full, half1 and half2 solve:

`delta_theta1 / delta_h1 = Ss_node1`

to floating-point precision.

Examples:

FIXED_1E6:
- measured ratios remain approximately `1.000000000e-6`.

GENERATED:
- node-1 `Ss = 2.9981689952213786e-6 cm^-1`;
- measured full/half ratios remain approximately
  `2.9981689952e-6`.

Therefore the non-monotone full-versus-two-half discrepancy is not caused by a
break in the admitted saturated elastic-storage relation.

## Fixed top flux

`qtop` is identical across full, half1 and half2 by construction.

For positive perturbation:
- `qtop = -4.7 cm/day`.

For negative perturbation:
- `qtop = -4.8 cm/day`.

There is no top-boundary forcing mismatch between the compared trajectories.

## Internal-flux split

The difference appears in the internal vertical-flux response required by the
node-1 balance.

### h0 = 10 cm, delta = +0.05, GENERATED

| dt day | full h1 | two-half h1 | terminal dh1 | full internal term | two-half internal term | difference |
|---:|---:|---:|---:|---:|---:|---:|
| 0.015625 | 7.146983 | 7.136809 | +0.010175 | 4.704562 | 4.704578 | -1.627e-5 |
| 0.0078125 | 8.419083 | 8.402548 | +0.016535 | 4.705056 | 4.705109 | -5.288e-5 |
| 0.00390625 | 9.069191 | 9.046252 | +0.022938 | 4.705954 | 4.706100 | -1.467e-4 |
| 0.001953125 | 9.415726 | 9.390231 | +0.025495 | 4.707474 | 4.707800 | -3.261e-4 |

As dt shrinks, both trajectories approach the initial saturated head, but the
full and two-half routes require increasingly different interval-average
internal flux responses.

The full/two-half state discrepancy therefore grows because the internal
hydraulic redistribution histories diverge, not because qtop differs.

### h0 = 10 cm, delta = -0.05, GENERATED

The same mechanism appears with the opposite state-change direction.

| dt day | full h1 | two-half h1 | terminal dh1 | full internal term | two-half internal term | difference |
|---:|---:|---:|---:|---:|---:|---:|
| 0.015625 | 12.853017 | 12.863191 | -0.010175 | 4.795438 | 4.795422 | +1.627e-5 |
| 0.0078125 | 11.580917 | 11.597452 | -0.016535 | 4.794944 | 4.794891 | +5.288e-5 |
| 0.00390625 | 10.930809 | 10.953748 | -0.022938 | 4.794046 | 4.793900 | +1.467e-4 |
| 0.001953125 | 10.584274 | 10.609769 | -0.025495 | 4.792526 | 4.792200 | +3.261e-4 |

The magnitude sequence is essentially symmetric with forcing sign.

## Half-step trajectory asymmetry

The first and second half steps do not experience the same hydraulic state.

Example:
`h0=10 cm, delta=+0.05, GENERATED, dt=0.015625`.

Full:
- h1 change: `-2.853017 cm`;
- storage rate: `-0.00456204 cm/day`.

Half1:
- h1 change: `-1.580917 cm`;
- storage rate: `-0.00505585 cm/day`.

Half2:
- h1 change from half1 state: `-1.282274 cm`;
- storage rate: `-0.00410077 cm/day`.

The two half steps therefore partition the same interval into different
hydraulic-gradient states and different internal flux responses.

Their combined endpoint remains very close to the full-step endpoint, but exact
identity is not obtained.

## Node-2 evidence

Node 2 moves consistently with node 1 but is not identical between full and
two-half trajectories.

For the same GENERATED positive case at dt = 0.015625 day:
- full node-1 h = `7.146983 cm`;
- full node-2 h = `7.226699 cm`;
- two-half node-1 h = `7.136809 cm`;
- two-half node-2 h = `7.217334 cm`.

At dt = 0.001953125 day:
- full node-1 h = `9.415726 cm`;
- full node-2 h = `9.490332 cm`;
- two-half node-1 h = `9.390231 cm`;
- two-half node-2 h = `9.467800 cm`.

The top-node discrepancy is therefore embedded in a real vertical-gradient
trajectory difference rather than an isolated constitutive mismatch at node 1.

## FIXED_1E6 versus GENERATED

The same mechanism occurs for FIXED_1E6, but with smaller state differences.

At `h0=10 cm, delta=+0.05, dt=0.015625`:

FIXED_1E6:
- terminal node-1 discrepancy: `0.00494407 cm`;
- internal-flux difference: `2.63683e-6 cm/day`.

GENERATED:
- terminal node-1 discrepancy: `0.0101746 cm`;
- internal-flux difference: `1.62694e-5 cm/day`.

The generated physical prior therefore strengthens the same interaction rather
than changing its type.

## OFF contrast

OFF does not obey a saturated elastic linear-storage relation because
`Ss=0`.

Where OFF yields three converged direct solves, its node-1 behavior is
qualitatively different and the full-half discrepancy decreases with smaller
dt.

Example:
`h0=10 cm, delta=+0.05`:

- dt `0.00390625`: terminal dh1 `-1.21594 cm`;
- dt `0.001953125`: `-0.700562 cm`;
- dt `0.0009765625`: `-0.339067 cm`.

This supports the attribution that the anomalous active-ELAS pattern is tied to
the saturated elastic-storage / internal-gradient interaction rather than to
the generic full-half construction alone.

## Hypotheses

H1, growing discrepancy is associated with internal vertical-flux response, not
qtop or ponding:
SUPPORTED.

H2, active-ELAS theta/h increments obey the node-local Ss relation:
SUPPORTED exactly within floating-point tolerance.

H3, half2 samples a different hydraulic-gradient trajectory and this explains
the full/two-half split:
SUPPORTED by the measured substep states and balance-derived internal flux
terms.

H4, OFF and active-ELAS increment patterns differ qualitatively:
SUPPORTED.

## Interpretation

The ELASTIC49 identity gate is not merely over-sensitive to roundoff.

ELASTIC50-52 show a real, finite trajectory difference:

1. fixed qtop is identical;
2. elastic theta(h) is internally consistent;
3. full and two-half solves traverse different saturated hydraulic-gradient
   trajectories;
4. those trajectories imply different internal vertical-flux histories;
5. the resulting endpoint difference is small but nonzero;
6. the identity-only temporal gate maps that finite difference to complete
   rejection.

The key remaining question is therefore not whether ELAS is numerically
consistent. It is.

The unresolved question is what temporal-error model is appropriate for this
saturated storage/flux trajectory splitting.

## Decision

Classification:
`QUALIFIED_ACTIVE_ELAS_INTERNAL_FLUX_TRAJECTORY_SPLIT`.

No production change is authorized.

The next bounded workunit should test a trajectory-aware temporal indicator,
preferably using the already existing Reference Richards defect-indicator
framework, but only after explicitly extending or falsifying its mathematical
envelope for bottom mode 7.

That extension must be research-only first and must not silently reuse the
current bottom-mode-2/5 qualification.
