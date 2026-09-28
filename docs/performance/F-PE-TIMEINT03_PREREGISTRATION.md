# F-PE-TIMEINT03 preregistration — mixed-state backward-Euler LTE mechanism

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Parent:

F-PE-TIMEINT02.

## Question

Does the raw backward-Euler LTE become materially more predictive when expressed in the mixed Richards state rather than pressure head alone?

The canonical residual conserves storage through water content:

`(theta^{n+1}-theta^n) dz / dt`.

TIMEINT03 therefore evaluates accepted derivative history in both pressure head and water content.

## Candidate quantities

For the accepted history step:

`h_dot_previous = (h_n-h_{n-1})/dt_prev`

`theta_dot_previous = (theta_n-theta_{n-1})/dt_prev`.

For a candidate full step:

`h_dot_current = (h_{n+1}-h_n)/dt`

`theta_dot_current = (theta_{n+1}-theta_n)/dt`.

Raw first-order LTE estimates:

`e_h = 0.5*dt*(h_dot_current-h_dot_previous)`

`e_theta = 0.5*dt*(theta_dot_current-theta_dot_previous)`.

Record:

- `LTE_H_INF = max|e_h|`;
- `LTE_THETA_INF = max|e_theta|`;
- `LTE_WATER_L1 = sum(dz*|e_theta|)` [cm water];
- `LTE_WATER_NET = |sum(dz*e_theta)|` [cm water].

No correction solve and no defect-operator solve is used.

## Truth quantities

Use the same 60/64-style mechanism design as TIMEINT02:

- 16 exposed BOFEK01 screening cases;
- one 0.005 d history step;
- candidate dt 0.005, 0.010, 0.020, 0.040 d;
- full versus two-half routes from identical origin.

Record actual:

- max head difference;
- max theta difference;
- storage difference;
- runoff difference;
- ponding difference;
- regime path;
- work;
- ledger.

## Frozen mechanism gates

Primary mechanism question is signal quality, not threshold tuning.

TIMEINT03 advances a mixed-state estimator family only if all are true:

1. at least 48/64 points complete;
2. all candidate metrics are finite;
3. Spearman correlation:
   - LTE_THETA_INF vs actual max theta difference >=0.75;
   - LTE_WATER_L1 vs actual storage-state L1 water difference >=0.75;
4. at least one mixed-state metric has correlation at least 0.10 higher than TIMEINT02 head-LTE correlation 0.5874;
5. mass ledgers remain <=5e-8 cm.

Secondary diagnostic:

Evaluate whether a dimensionless combined score

`S = max(LTE_H_INF/0.50 cm, LTE_THETA_INF/1e-4)`

has zero false-safe points for local P-C1 truth at `S<=1`.

This combined score is diagnostic only in TIMEINT03. It does not advance on classification alone unless the primary correlation gates also pass.

## Stop rule

If the mixed-state quantities fail the correlation gates, do not continue fitting scalar LTE thresholds.

Advance instead to a higher-order temporal-discretization prototype such as variable-step BDF2 with backward-Euler restart.

## Production boundary

No production source modification and no timestep authority in TIMEINT03.
