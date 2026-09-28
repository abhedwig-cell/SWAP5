# F-PE-DYNERR01 preregistration — dynamic-top temporal defect indicator

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`

## Trigger

F-PE-STATESTEP01-03 established that accepted-state history contains useful performance signal but cannot reliably predict wet/surface-boundary transitions.

The current production Reference temporal indicator already provides a defect-based `head_inf_bound`, but its admitted envelope requires an explicit fixed-flux top boundary.

The BOFEK00 dynamic-top provider now exposes the exact surface-head derivative used by the corrected HeadCalc Jacobian.

## Candidate extension

Start from the current production temporal-indicator algorithm unchanged.

For a dynamic top boundary:

- flux regime contributes no top-head stiffness;
- head regime contributes the already-qualified HeadCalc top Jacobian term:

`K_surface / d_surface * (1 - dHsurf/dh_top)`.

Use:

- `surface_face_conductivity` returned by the dynamic-top provider;
- `node_distance(1)`;
- `surface_head_dpressure_head_top`.

No new hydraulic approximation is introduced.

All interior, bottom-boundary, mass-weight, defect, tridiagonal solve and norm definitions remain identical to production.

This is test-only in DYNERR01.

## Evaluation bank

Use the 16 previously exposed BOFEK01 screening material/regime cases for mechanism characterization.

For every case:

1. initialize the same uniform state;
2. create a dynamic accepted origin using one strict history step of 0.005 d;
3. store the resulting previous right derivative;
4. from that exact origin evaluate requested dynamic-top steps at:
   - 0.005 d;
   - 0.010 d;
   - 0.020 d;
   - 0.040 d;
5. for each requested step:
   - execute one full step;
   - independently execute two half steps from the same origin;
   - compute actual full-vs-two-half endpoint error;
   - evaluate the candidate dynamic-top temporal indicator on the full-step candidate.

Maximum planned points: 64.

Failed physical full/two-half solves are recorded, not silently removed.

## Primary quantities

Per complete point record:

- candidate indicator `head_inf_bound`;
- actual `max|h_full-h_twohalf|`;
- ponding endpoint difference;
- runoff-depth difference;
- storage difference;
- full and two-half solver work;
- boundary regime and derivative;
- mass/ledger status.

## Frozen mechanism gates

DYNERR01 advances only if all are true:

1. at least 48/64 points produce complete full and two-half physical solutions;
2. candidate indicator is available and finite for every complete point;
3. Spearman rank correlation between `head_inf_bound` and actual max head error >= 0.80;
4. using a frozen strict local head threshold of 0.01 cm:
   - zero false-safe points, where indicator <=0.01 cm but actual head error >0.01 cm;
5. at least 20% of complete points are classified safe at the 0.01 cm indicator threshold, preventing a trivial always-reject result;
6. no mass/ledger regression is introduced by the test harness.

If gate 4 fails, no multiplicative safety factor is fitted post hoc in DYNERR01.

If correlation passes but strict calibration fails, a separately preregistered calibration workunit may be considered.

## Production boundary

No production `src/**` change in DYNERR01.

Possible outcomes:

- `DYNAMIC_TOP_INDICATOR_MECHANISM_QUALIFIED`;
- `DYNAMIC_TOP_INDICATOR_CORRELATED_NEEDS_CALIBRATION`;
- `CLOSED_DYNAMIC_TOP_INDICATOR_NOT_PREDICTIVE`;
- `BLOCKED_<reason>`.
