# F-PE-TIMEINT13 preregistration — extrapolated-conductivity semi-implicit BDF2

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2b6a82c4c89ba759a0c89df53971c725827d2b88`

Parent authority:

- TIMEINT05: variable-step fully implicit BDF2 is second-order on smooth fixed-flux trajectories for accepted step ratios 0.5..2.0;
- TIMEINT12: dynamic-top fully implicit surface derivative is mathematically qualified;
- TIMEINT12A: endpoint fully implicit dynamic-top BE completes only 6/12 wet/ponding cases at MAXIT=8 and is materially more expensive;
- KIMPL-DYNTOP01/02: all six failures are recoverable with deeper Newton iteration, but O14/MOIST requires MAXIT=24 and the route is too costly for a default.

## Purpose

Test whether second-order temporal accuracy can be retained without endpoint-fully-implicit conductivity.

The candidate keeps:

- BDF2 storage/history;
- candidate-dependent water content and capacity;
- corrected dynamic-top physics;
- transactional history ownership.

But removes the strongest nonlinear coupling by predicting conductivity from accepted history and holding it fixed during Newton.

Research-only. No production source change.

## Predicted conductivity

Let:

- current accepted step duration = `h_n`;
- previous accepted step duration = `h_{n-1}`;
- `r = h_n / h_{n-1}`;
- `K_n` = conductivity evaluated at accepted state `n`;
- `K_{n-1}` = conductivity evaluated at accepted state `n-1`.

For BDF2 steps predict:

`K_pred = K_n + r * (K_n - K_{n-1})`.

For constant step this is:

`K_pred = 2*K_n - K_{n-1}`.

Use the same formula node-wise.

A positivity floor is allowed only as a fail-safe:

`K_pred = max(1e-12 cm/day, K_pred)`.

Record clamp count.

A smooth mechanism case qualifies only if clamp count = 0.

## Newton semantics

During a candidate step:

- `SWKIMPL=0`;
- the constitutive provider returns exact candidate `theta(h)` and `C(h)`;
- conductivity returned to HeadCalc is the fixed `K_pred` vector;
- `dK/dh = 0`;
- interior face conductivity is formed from predicted nodal K using the existing mean method;
- dynamic-top uses the same predicted top-node conductivity through the existing fixed-K BOFEK00 route.

Thus K is time-predicted but Newton-lagged.

## First-step / restart semantics

A trajectory without two accepted history states uses first-order Backward Euler with `K_n`.

BDF2 begins only from the second accepted step.

Any future adaptive implementation must restart to first order when:

- history is missing;
- the step-ratio envelope is violated;
- a discontinuous regime/event invalidates smooth history.

TIMEINT13 does not yet qualify adaptive restart rules.

## P0 — smooth fixed-flux order mechanism

Use the TIMEINT05 smooth bank:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Constant-step ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Horizon: 0.04 d.

Candidate:

- BE bootstrap step;
- extrapolated-K BDF2 thereafter.

Comparator:

- TIMEINT05 fully implicit BDF2 mechanism.

P0 gates:

1. 4/4 ladders complete;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined top-head orders >=1.5;
4. storage spread <=1e-10 cm in every ladder;
5. clamp count = 0 for all smooth runs;
6. median candidate work per step <= fully implicit BDF2 work per step;
7. no nonfinite state or solver retry pathology.

If P0 fails, stop TIMEINT13.

## P1 — dynamic-top robustness/cost screen

Only if P0 passes.

Use 12 fixed-step dynamic-top cases:

- materials B01, B12, O05, O14;
- MOIST: h0=-50 cm, rain=8 cm/day;
- WET: h0=-20 cm, rain=12 cm/day;
- POND: h0=-5 cm, rain=25 cm/day.

Fixed:

- dt=0.005 d;
- horizon=0.12 d;
- MAXIT=8;
- BALTOL02;
- SWKIMPL=0;
- same corrected fixed-K dynamic-top provider, but with history-predicted top K.

Comparators:

1. KLAG Backward Euler from TIMEINT12A;
2. fully implicit KIMPL Backward Euler where available.

P1 gates:

1. 12/12 candidate trajectories complete;
2. all POND cases complete;
3. max ledger <=5e-8 cm;
4. no alternative-solver pathology;
5. median deterministic work ratio candidate/KLAG <=1.15;
6. max individual work ratio candidate/KLAG <=1.30;
7. candidate does not require MAXIT>8;
8. no conductivity prediction clamp on more than 5% of accepted steps.

## Interpretation boundary

P1 is robustness/cost evidence, not a temporal-order proof on dynamic-top regime-switching trajectories.

A successful P1 would justify a later dynamic-top accuracy/variable-step qualification.

## Outcomes

- `EXTRAPOLATED_K_BDF2_MECHANISM_QUALIFIED`;
- `SMOOTH_ORDER_PASS_DYNAMIC_TOP_ROBUSTNESS_FAIL`;
- `CLOSED_EXTRAPOLATED_K_BDF2_NOT_SECOND_ORDER`.

## Production boundary

No production source change.

No adaptive controller.

No removal of user DTMIN/DTMAX yet.
