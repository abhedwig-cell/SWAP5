# F-PE-TIMEINT15 closeout — conservative trapezoidal successor

Date: 2026-09-29

Final status:

`CLOSED_CONSERVATIVE_TRAPEZOIDAL_SECOND_ORDER_NOT_QUALIFIED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

## What is established

TIMEINT15 tested a one-step mixed-storage / trapezoidal non-storage formulation specifically to preserve SWAP5's existing physical accepted-interval mass identity.

That objective succeeds.

Across the smooth fixed-flux bank, physical per-step and cumulative ledgers remain at roundoff scale, approximately O(1e-14 cm).

The tested formulation therefore does not reproduce the BDF2 history-contract conflict.

## Why it does not advance

The frozen second-order accuracy gate fails strongly.

### Plain trapezoidal

Fully implicit conductivity:

- 3/4 complete ladders;
- median refined top-head order about 0.968;
- work per step about equal to fully implicit BE.

Predicted conductivity:

- 4/4 complete ladders;
- zero conductivity clamps;
- median refined top-head order about 0.630;
- work per step about equal to KLAG BE.

The predicted-K P0 arm is additionally not a faithful trapezoidal origin/end operator split because its origin conductivity was already endpoint-predicted. It is therefore not used as a general negative result against semi-implicit second-order integration.

### Rannacher startup attribution

Two BE half steps over the first nominal interval remove the P0 fine-grid completion failure but do not restore second order.

Results:

- 4/4 ladders complete;
- refined top-head orders approximately 1.020, 1.042, 1.024 and 1.047;
- median about 1.033;
- 0/4 >= 1.5;
- median work ratio versus fully implicit BE about 1.0625;
- mass ledgers remain at roundoff.

Therefore the dominant order loss is not explained by the abrupt t=0 forcing transition.

## Interpretation

The negative result is narrow.

It does not show that all Crank-Nicolson discretizations of Richards are first order.

It shows that the tested SWAP HeadCalc residual decomposition, in which the physical water-content increment is combined with a trapezoidal average of the extracted non-storage residual/operator, does not reproduce the desired second-order temporal operator on the established SWAP test bank.

Further empirical patching of this materialization is not justified inside TIMEINT15.

## Literature consequence

The Richards-specific literature gives a better-defined next route.

Kavetski, Binning and Sloan formulate mass conservation using moisture content as the principal temporal variable and obtain a second-order scheme closely related to the implicit Thomas-Gladwell method. They also derive local-extrapolation / adaptive variants designed for incorporation into backward-Euler Richards solvers.

That is materially different from continuing to tune the failed trapezoidal residual split.

The literature also supports semi-implicit second-order evaluation of nonlinear terms through extrapolation, so predicted conductivity remains a valid later cost-reduction hypothesis once the underlying second-order conservative mechanism is qualified.

## Decision

TIMEINT15 closes without production admission.

Direct successor:

`F-PE-TIMEINT16 — moisture-based Thomas-Gladwell / local-extrapolation conservative Richards integration`

TIMEINT16 should first reproduce the literature-level second-order mechanism on the existing smooth fixed-flux bank with exact physical interval mass accounting.

Only after that:

1. quantify work versus BE and qualified BDF2;
2. investigate second-order semi-implicit/predicted hydraulic terms;
3. derive event restart semantics;
4. test variable step and LTE control;
5. revisit corrected dynamic-top.

No dynamic-top Thomas-Gladwell work before smooth mechanism qualification.

## BDF architecture note

Bootsma et al. (2026) independently demonstrate that a DAE/BDF formulation can be discretely mass-conservative in a history-dependent multistep sense.

That remains a legitimate separate architecture route.

It does not remove the TIMEINT14 distinction: for BDF2/BDF3 the physical boundary-flux integral requires additional temporal quadrature and is not automatically the consecutive-state SWAP transaction ledger.

Therefore DAE/BDF remains separate from the unchanged physical interval-contract route.

## Production boundary

No production `src/**` changes.

No mass tolerance changes.

`LEGACY_NUMERICS` remains production default.
