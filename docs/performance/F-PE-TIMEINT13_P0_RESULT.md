# F-PE-TIMEINT13 P0 result — smooth extrapolated-K BDF2

Date: 2026-09-29

Status: `P0_NOT_ADVANCED_COMMON_SHORTSTEP_LIMIT`

Authority:

- preregistration: `docs/performance/F-PE-TIMEINT13_PREREGISTRATION.md`;
- canonical base at execution: `integration/f-ci-canonical@2b6a82c4c89ba759a0c89df53971c725827d2b88`;
- Actions run: `36518507496`;
- job: `109246056111`;
- conclusion: SUCCESS.

## Candidate

Constant-step P0 instance of the preregistered semi-implicit method:

- BDF2 storage derivative;
- `h_pred = 2 h^n - h^{n-1}`;
- constitutive `K_pred = K(h_pred)`;
- `K_pred` fixed during Newton;
- candidate theta/capacity still updated normally;
- no dK/dh term;
- first step uses BE with current-state lagged K.

Comparator:

current BE_KLAG at identical dt.

## Frozen matrix result

Planned BDF2_KPRED trajectories: 16.

Completed:

15/16.

The only incomplete point is:

- B01;
- rain = 1 cm/day;
- dt = 0.000625 d.

At that same point the BE_KLAG comparator also fails, later in its trajectory.

Thus the original all-complete P0 gate fails, but the missing point is not candidate-specific.

## Temporal order on complete refinement triples

B01, rain 4 cm/day:

- refined order: about 1.972.

O05, rain 1 cm/day:

- refined order: about 1.972.

O05, rain 4 cm/day:

- refined order: about 1.949.

Across these three complete cases:

- median refined order: about 1.972;
- minimum refined order: about 1.949;
- 3/3 exceed 1.50.

This is consistent with genuine second-order behavior on the resolved smooth domain.

## Work

Median deterministic work per step:

- BDF2_KPRED: 12.0;
- BE_KLAG: 12.0625.

Ratio:

about 0.995.

No alternative solver calls occur.

Therefore coefficient extrapolation does not introduce the fully implicit K Newton-cost penalty in this matrix.

## Decision

The original P0 does not advance because its frozen all-complete gate is not met.

Do not reinterpret the missing B01/1 point post hoc.

The result nevertheless justifies one separately preregistered common-domain replication on entirely new dt values above the observed short-step failure zone.

No dynamic-top exposure is authorized yet.
