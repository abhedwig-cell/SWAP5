# F-PE-ELASTIC51 — candidate temporal metric characterization result

Date: 2026-09-29

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic51-candidate-temporal-metrics`

Qualified postimage:
`f56e9e72a90605a2de5bd5d860b3c6d035d3b51b`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36632500885`

Job:
`109624958127`

Conclusion:
SUCCESS.

## Question

Can a simple physically interpretable full-versus-two-half state norm replace
the information destroyed by the current identity-only temporal gate for the
difficult saturated ELAS cases?

ELASTIC51 does not select or change a production tolerance.

## Frozen bank

ELASTIC51 preserves the ELASTIC50 direct-solve bank exactly:
- real BRO profile `90116260`;
- 16-node variable grid;
- bottom mode 7;
- explicit fixed-flux top boundary;
- default-MvG hydraulics;
- OFF, FIXED_1E6 and GENERATED ELAS regimes;
- h0 = 2 and 10 cm;
- delta = +/-0.05 cm/day;
- retry ladder from 0.015625 day with factor 0.5 through retry index 8.

Qualification:
- 108 comparison points executed;
- 29 points had converged full, half1 and half2 solves;
- all reported metrics finite and nonnegative;
- O0/O2 outputs identical;
- no production source changes.

## Candidate metrics

For converged full state F and two-half state H:

1. `H_INF = max |h_F-h_H|`;
2. `H_RMS_DZ = sqrt(sum(dz*dh^2)/sum(dz))`;
3. `THETA_INF = max |theta_F-theta_H|`;
4. `STORAGE_L1 = sum(dz*|dtheta|)`;
5. `STORAGE_SIGNED = abs(sum(dz*dtheta))`.

Relative unsigned and signed storage metrics were also recorded against the
larger full/two-half total-storage checksum.

## Primary result

No simple candidate in this family is ready to become a temporal acceptance
metric.

The candidates split into two classes:

### Bulk signed storage is too insensitive

`STORAGE_SIGNED` remains at machine/balance-noise scale in the active-ELAS
converged pairs.

Typical values are approximately:
- `1e-17` to `2e-15 cm` water absolute;
- relative total-storage differences approximately `1e-19` to `5e-17`.

The ratio

`STORAGE_SIGNED / STORAGE_L1`

is typically only about `1e-11` to `1e-9`.

Thus almost all node-local full-half water-content differences cancel in the
bulk storage sum.

A temporal metric based only on signed total storage would therefore classify
these visibly different local states as essentially identical.

### Local metrics are informative but not asymptotically regular

`H_INF`, `H_RMS_DZ`, `THETA_INF` and `STORAGE_L1` all detect the local
surface discrepancy.

However, in the principal active-ELAS sequences these metrics increase when
the requested dt is initially reduced.

Example:
`h0=10 cm, delta=-0.05, FIXED_1E6`

| dt day | H_INF cm | H_RMS_DZ cm | STORAGE_L1 cm water |
|---:|---:|---:|---:|
| 0.015625 | 0.00494407 | 0.00324602 | 3.48814e-7 |
| 0.0078125 | 0.00905701 | 0.00591321 | 6.34971e-7 |
| 0.00390625 | 0.0153402 | 0.00990053 | 1.06145e-6 |
| 0.001953125 | 0.0227286 | 0.0143171 | 1.53174e-6 |

The same pattern occurs for GENERATED.

Example:
`h0=10 cm, delta=-0.05, GENERATED`

| dt day | H_INF cm | H_RMS_DZ cm | STORAGE_L1 cm water |
|---:|---:|---:|---:|
| 0.015625 | 0.0101746 | 0.00689774 | 1.91747e-6 |
| 0.0078125 | 0.0165348 | 0.0110354 | 3.06950e-6 |
| 0.00390625 | 0.0229382 | 0.0148082 | 4.12109e-6 |
| 0.001953125 | 0.0254946 | 0.0153297 | 4.25513e-6 |
| 0.0009765625 | 0.0222921 | 0.0116397 | 3.23249e-6 |

The final point turns downward, but the sequence is not a simple monotonic
temporal-convergence curve.

## OFF contrast

Where OFF yields multiple fully converged comparisons, the local metrics do
behave more like conventional temporal-error measures.

For `h0=10 cm, delta=+0.05`:

| dt day | H_INF cm | H_RMS_DZ cm | STORAGE_L1 cm water |
|---:|---:|---:|---:|
| 0.00390625 | 1.21594 | 0.362606 | 3.19010e-4 |
| 0.001953125 | 0.700562 | 0.195784 | 1.52140e-4 |
| 0.0009765625 | 0.339067 | 0.0901731 | 6.73550e-5 |

This decreases with decreasing dt in the expected direction.

The non-monotone behavior is therefore specifically associated with the
active-ELAS saturated route rather than being an unavoidable property of the
measurement method.

## Water-content and elastic-storage relation

For active ELAS, `THETA_INF` tracks `H_INF` through the elastic storage slope.

For FIXED_1E6:
`THETA_INF approximately 1e-6 * H_INF`.

For GENERATED, the larger node-local generated Ss gives proportionally larger
water-content and unsigned-storage discrepancies.

This reinforces the ELASTIC50 attribution that the mismatch is dominated by
the saturated elastic response near the top node.

## Hypotheses

H1, signed storage remains near machine/balance noise:
SUPPORTED.

H2, unsigned storage exposes local elastic redistribution:
SUPPORTED.

H3, head metrics are surface-dominated and may be non-monotone:
SUPPORTED.

H4, a water-storage-based metric is more physically interpretable than bit
identity:
PARTLY SUPPORTED.

Unsigned local storage is physically interpretable and reveals the hidden local
difference, but it is not yet a satisfactory temporal-error estimator because
its retry-ladder behavior is non-monotone.

Signed bulk storage is physically meaningful for conservation, but is too
insensitive to diagnose the local temporal discrepancy.

## Relation to the existing Richards temporal indicator

Canonical already contains
`mod_reference_richards_temporal_indicator`, which constructs a defect-based,
mass-weighted head bound.

That indicator is explicitly qualified only for bottom modes 2 and 5.

The ELASTIC46-51 difficult route uses bottom mode 7.

ELASTIC51 therefore does not reuse or extrapolate that indicator outside its
admitted boundary envelope.

## Interpretation

The chain now establishes:

1. ELASTIC48: active ELAS reduces nonlinear solver rejection and exposes the
   temporal gate.
2. ELASTIC49: that gate is identity-only, not a continuous error metric.
3. ELASTIC50: rejected full-versus-two-half differences can be small, finite,
   localized and bulk-storage neutral.
4. ELASTIC51: simple head or local-storage norms detect those differences, but
   active-ELAS sequences are not monotonically reduced by the retry ladder;
   signed bulk storage is almost blind because of cancellation.

Therefore the immediate problem is not merely choosing a better scalar
tolerance.

The next bounded question is why the active-ELAS full-versus-two-half
difference grows over the first retry halvings.

That mechanism must be understood before defining a replacement acceptance
metric.

## Decision

Classification:
`QUALIFIED_NEGATIVE_SIMPLE_TEMPORAL_METRIC_RESULT`.

No candidate metric is selected for production.

No temporal tolerance, retry policy, solver policy or physical parameter is
changed.

The next safe workunit is a mechanistic active-ELAS retry-ladder attribution,
focused on the top-node full/half trajectories and the elastic-storage /
fixed-flux boundary interaction.
