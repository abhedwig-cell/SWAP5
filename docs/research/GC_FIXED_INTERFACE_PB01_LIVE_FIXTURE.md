# PB01 live one-cell MODFLOW fixture specification

Date: 2026-09-21
Status: PREREGISTERED LIVE FIXTURE, NOT YET EXECUTED
Production changes: none

## Objective

Drive a real MODFLOW 6 one-cell transient storage model with analytically generated NH01 API terms and determine which response orientation reproduces the independently derived coupled root H=8.04 m.

## Groundwater model

Use one confined/equivalent linear-storage cell with:

- area = 1 m2;
- initial head H0 = 8.0 m;
- storage coefficient S_M = 0.10;
- one stress period of 1 day;
- no recharge, wells, drains, CHD or lateral flow;
- one API package boundary.

The standalone groundwater equation is therefore exactly:

    S_M*(H-H0)/dt = Q_API(H)

up to the MODFLOW API package's documented positive-infiltration convention.

## NH01 source

Use:

    S_S=0.10
    C=0.20/day
    W_S=0.010 m
    dt=1 day
    u=1/15
    physical coupled root H=8.04 m

For predictor q_bot values:

    -0.002, 0.0, 0.003, 0.008 m/day

construct the exact predictor head and historical q_u without any SWAP numerical solve.

## Three cases

### PB01-LIVE-CURRENT

Publish the current documented construction unchanged:

    Q_ref = q_u
    slope = +u/dt
    H_ref = H_pred

Expected falsification: the converged MODFLOW head is predictor dependent and at least one case differs from 8.04 m by more than 1e-3 m.

### PB01-LIVE-OUTWARD

Publish the exact physical groundwater-directed response:

    Q_ref = -q_bot
    slope = -u/dt
    H_ref = H_pred

Expected: every predictor produces H=8.04 m within numerical tolerance.

### PB01-LIVE-DIRECT

As a control, publish the already eliminated physical law around H0:

    Q_ref = beta*W_S/dt
    slope = -u/dt
    H_ref = H0

Expected: H=8.04 m.

## Gates

- Same MODFLOW executable/library and API publication route for all cases.
- No sign changes inside MODFLOW wrapper between cases.
- API HCOF/RHS must be constructed by the repository backend formula.
- Record head, API flux and groundwater storage change.
- At 8.04 m, accepted physical outward exchange is 0.004 m over the day.
- OUTWARD and DIRECT must agree with the independent physical root and ledger.
- CURRENT must be reported exactly as observed; no tolerance/sign adjustment after execution.

## Interpretation

If the preregistered outcome occurs, the discrepancy is localized to the response orientation supplied to the API package, not to MODFLOW storage or HCOF/RHS algebra.

If CURRENT unexpectedly reproduces 8.04 m for all predictor origins, inspect the live package residual and storage formulation for an unmodelled companion term before changing any production code.
