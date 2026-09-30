# F-PE-ELASTIC53 — bottom-mode-7 defect-indicator feasibility result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic53-mode7-defect-indicator`

Qualified postimage:
`9b09b5fb604d0417882131f8eb836bc20acc8ece`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36672105068`

Job:
`109749127415`

Conclusion:
SUCCESS.

## Question

Can the existing Reference Richards defect-based temporal indicator be extended
mathematically to the bottom-mode-7, `swkimpl=0` free-drainage route without
changing production source or the production temporal acceptance policy?

## Existing authority

F-SI38 established:
- prescribed qbot, bottom mode 2, uses a Neumann defect operator with no added
  bottom stiffness;
- prescribed head, bottom mode 5, adds the Dirichlet bottom stiffness;
- other bottom modes fail closed.

For production HeadCalc with bottom mode 7:
- `qbot = -K_N`;
- under `swkimpl=0`, the production Jacobian adds no `dK/dh` bottom
  stiffness term.

ELASTIC53 therefore tested the narrow research hypothesis that the mode-7
defect operator for `swkimpl=0` should likewise use no extra bottom stiffness.

## Research implementation

Production source was not edited.

During qualification, a temporary research-only copy of
`mod_reference_richards_temporal_indicator` was materialized that:
- admits bottom mode 7;
- retains the existing mode-5-only Dirichlet bottom stiffness;
- changes no other operator terms;
- uses a separate research module/procedure name.

The production indicator remains fail-closed for mode 7.

## Independent operator oracle

A mode-7 oracle derived from the independent F-SI38 construction was run under
O0 and O2.

For every oracle case the research indicator reproduced:
- raw mass-weighted norm;
- defect norm;
- bounded norm;
- `Binf`.

The zero-added-bottom-stiffness operator therefore matches the independently
constructed operator for the declared `swkimpl=0` envelope.

The simple oracle cases are raw-bound, so an intentionally added Dirichlet
stiffness can produce the same final bounded `Binf`; that inherited F-SI38
separation-count check is not informative in this envelope. Exact independent
operator reproduction remains the controlling oracle.

Operator qualification:
`F_PE_ELASTIC53_A1_OPERATOR_ORACLE=PASS`.

## Real BOFEK/BRO bank

The frozen ELASTIC50/52 bank was reused:
- profile `90116260`;
- 16-node variable grid;
- bottom mode 7;
- fixed-flux top boundary;
- h0 = 2 and 10 cm;
- delta = +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- retry ladder from 0.015625 day with factor 0.5.

Results:
- 108 cases executed;
- 53 full solves converged;
- research indicator available for all 53 converged full solves;
- 29 of those also had converged full + half1 + half2 trajectories and hence a
  directly observed full-versus-two-half `H_INF`;
- O0/O2 outputs were identical;
- no `src/**` production change.

## Indicator behavior

For active ELAS, the research `Binf` decreases regularly as dt is reduced.

### h0 = 10 cm, delta = -0.05, FIXED_1E6

| dt day | Binf cm | observed full-half H_INF cm |
|---:|---:|---:|
| 0.015625 | 13.8162 | 0.00494407 |
| 0.0078125 | 6.91601 | 0.00905701 |
| 0.00390625 | 3.47253 | 0.0153402 |
| 0.001953125 | 1.76091 | 0.0227286 |

The direct endpoint discrepancy grows over this sequence, but the
trajectory-aware indicator decreases monotonically.

### h0 = 10 cm, delta = -0.05, GENERATED

| dt day | Binf cm | observed full-half H_INF cm |
|---:|---:|---:|
| 0.015625 | 5.30254 | 0.0101746 |
| 0.0078125 | 2.66743 | 0.0165348 |
| 0.00390625 | 1.35998 | 0.0229382 |
| 0.001953125 | 0.715919 | 0.0254946 |
| 0.0009765625 | 0.396045 | 0.0222921 |

Again `Binf` decreases cleanly with dt even though the endpoint full-half
difference is non-monotone.

The same decreasing trend occurs for the positive perturbation active-ELAS
sequences.

## Conservatism

The research indicator is very conservative relative to the directly observed
full-versus-two-half endpoint difference.

Across the 29 paired converged cases:

`Binf / H_INF`

ranges approximately from:
- minimum `7.52`;
- maximum `2.79e3`.

Examples:

FIXED_1E6, h0=10 cm, delta=-0.05:
- dt 0.015625: ratio about `2795`;
- dt 0.001953125: ratio about `77.5`.

GENERATED, same state/forcing:
- dt 0.015625: ratio about `521`;
- dt 0.001953125: ratio about `28.1`;
- dt 0.0009765625: ratio about `17.8`.

Therefore the mode-7 defect indicator is not calibrated to the observed
full-half endpoint error and must not yet be interpreted as an acceptance
threshold.

## Why this is still a positive result

ELASTIC51 showed that simple endpoint norms are physically interpretable but
behave poorly as retry-ladder temporal estimators under active ELAS.

ELASTIC53 shows that the existing trajectory-aware Richards defect framework:
- can be extended consistently to mode 7 under the narrow `swkimpl=0`
  linearization;
- remains finite and available on the real-profile bank;
- decreases regularly with decreasing dt;
- requires no additional nonlinear trajectory;
- preserves the established one-tridiagonal-solve defect construction.

This gives a substantially stronger research candidate than bit identity or a
simple endpoint norm.

## Hypothesis outcome

Mode-7 zero-bottom-stiffness operator consistency under `swkimpl=0`:
SUPPORTED.

Independent operator reproduction:
SUPPORTED.

Real-profile indicator availability:
SUPPORTED.

Regular retry-ladder behavior:
SUPPORTED for the observed active-ELAS sequences.

Direct calibration to endpoint full-half error:
NOT SUPPORTED. The indicator is strongly conservative and uncalibrated.

## Boundaries

ELASTIC53 does not qualify:
- production mode-7 indicator admission;
- `swkimpl=1`;
- a temporal acceptance tolerance;
- replacement of `fmr_serialized_temporal_identity`;
- default-on model-certificate temporal policy;
- a controller change.

The existing production mode-7 path remains unchanged.

## Decision

Classification:
`QUALIFIED_MODE7_DEFECT_INDICATOR_RESEARCH_CANDIDATE`.

The next bounded workunit should calibrate and falsify this candidate against
independent observed temporal error over a broader mode-7 bank, including:
- additional heads and forcing magnitudes;
- at least one unsaturated control;
- active and inactive ELAS;
- dt sequences with three or more converged reference points;
- explicit holdout cases.

Calibration should determine whether a stable scaling or normalized budget can
map the conservative `Binf` to a useful acceptance signal without weakening
mass conservation or solver/transaction separation.
