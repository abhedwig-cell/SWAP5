# F-PE-PZG23-03 — interval-B rejection-channel attribution result

Date: 2026-09-30

Status: QUALIFIED_SOLVER_REJECTION_DOMINANT_BLOCKER

Branch:
`research/f-pe-pzg23-03-rejection-channel-attribution`

Qualified postimage:
`72dcbadcf4234af04a04a1da79cdc92474b9016c`

Canonical baseline:
`integration/f-ci-canonical@f133e47f8f7899f3d70db79f9ea63fbb730b2da0`

Workflow run:
`36762761678`

Job:
`110049227230`

Conclusion:
SUCCESS.

## Question

Which explicit kernel rejection channel terminates the two localized pZg23
interval-B failures?

## Frozen cases

Origins:

- origin 10: h0=+2 cm, forcing delta=+0.035 cm/day;
- origin 11: h0=+2 cm, forcing delta=+0.050 cm/day.

Both are evaluated from a valid committed interval-A checkpoint with unchanged:

- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- caller-owned head budget=0.20 cm;
- retry policy;
- hard mass;
- nonlinear/balance tolerances.

## Origin 10

- completed = false;
- attempts = 20;
- retries = 16;
- accepted substeps = 3;
- solver rejections = 14;
- temporal rejections = 3;
- temporal-certificate unavailable rejections = 0;
- mass rejections = 0;
- admission rejections = 0;
- checkpoint rejections = 0;
- nonlinear iterations = 496;
- internal retries = 14;
- backtracking attempts = 2899;
- min accepted substep = 0.00128173828125 day;
- max accepted substep = 0.00341796875 day;
- max absolute accepted-step mass residual ~7.39e-15.

## Origin 11

- completed = false;
- attempts = 22;
- retries = 19;
- accepted substeps = 2;
- solver rejections = 20;
- temporal rejections = 0;
- temporal-certificate unavailable rejections = 0;
- mass rejections = 0;
- admission rejections = 0;
- checkpoint rejections = 0;
- nonlinear iterations = 663;
- internal retries = 20;
- backtracking attempts = 3698;
- min accepted substep = 0.00011444091796875 day;
- max accepted substep = 0.0009765625 day;
- max absolute accepted-step mass residual ~7.11e-15.

## Aggregate channel attribution

Across the two failures:

- solver rejections = 34;
- temporal rejections = 3;
- mass rejections = 0.

Classification:

`SOLVER_REJECTION_DOMINANT`.

## Hypotheses

H1 — solver rejection channel dominates:

SUPPORTED.

H2 — temporal-certificate rejection dominates:

FALSIFIED as the primary mechanism.

Origin 10 has three temporal rejections, but solver rejection remains the
dominant channel. Origin 11 has no temporal rejection at all.

H3 — hard mass causes the failure:

FALSIFIED.

No hard-mass rejection occurs.

## Interpretation

Together with PZG23-01 and PZG23-02, the causal narrowing is now:

1. not a broad pZg23 failure;
2. not worker/OpenMP related;
3. not invalid interval-A state construction;
4. not hard mass;
5. not accepted temporal-history content;
6. not hidden solver scratch outside the committed carrier;
7. localized to the wet positive-forcing accepted physical state and dominated
   by nonlinear solver rejection/backtracking.

## Decision

Final classification:

`QUALIFIED_PZG23_LOCAL_NONLINEAR_SOLVER_REJECTION_BLOCKER`.

No change is justified to:

- the 0.20 cm temporal budget;
- hard mass;
- temporal-history ownership;
- worker-count policy;
- GENERATED ELAS.

Any actual repair is a new solver workstream and must be justified separately
against its value to production, because the current blocker is only two
localized origins in a scheduler-calibration domain.
