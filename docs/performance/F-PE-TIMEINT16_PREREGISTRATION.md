# F-PE-TIMEINT16 preregistration — moisture-based Thomas-Gladwell / local-extrapolation Richards integration

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@71169681f1ba18d7aa999a5ff8a7666964072929`

Parent authority:

- TIMEINT14: unchanged BDF2 is algorithmically conservative but incompatible with the existing exact consecutive-state physical interval mass contract.
- TIMEINT15: the tested one-step trapezoidal residual split preserves physical interval mass to roundoff but fails the second-order gate, including after Rannacher startup.
- TIMEINT13: second-order extrapolated/predicted conductivity remains a viable later cost-reduction concept once the underlying temporal mechanism is qualified.

## Literature authority

The direct target is the moisture/mixed-form Thomas-Gladwell family described by Kavetski, Binning and Sloan, not the noniterative pressure-form approximation by itself.

For the semi-discrete system, the relevant second-order construction carries the accepted derivative from the previous step and obtains two endpoint estimates from one BE-like nonlinear endpoint solve:

`X_(1)^(n+1) = X^n + h Xdot^(n+1)`

and

`X_(2)^(n+1) = X^n + 0.5 h (Xdot^n + Xdot^(n+1))`.

The higher-order state `X_(2)^(n+1)` is the local-extrapolation state.

For Richards, physical mass conservation requires the principal temporal state to be moisture/water content. A pressure-head-only Thomas-Gladwell extrapolation is therefore not sufficient authority for SWAP5.

## Primary question

Can a moisture-based Thomas-Gladwell/local-extrapolation step be composed with the SWAP Richards operator such that all of the following hold simultaneously?

1. accepted endpoint water content is formally second order;
2. accepted endpoint pressure head is constitutively consistent with that water content;
3. physical accepted-interval storage change equals physical current-interval integrated flux/source mass within existing authority;
4. no multistep history mass is published as physical water;
5. work remains competitive enough to justify further research;
6. transaction commit/rollback can carry the required accepted derivative without ambiguity.

## P0 mathematical reconstruction

Let the accepted physical water-content vector be `theta_n`.

Define the semi-discrete physical balance in moisture form:

`M theta_dot = Q(theta,h,t)`

where `M` represents control-volume depth/fraction weights and `Q` is the physical net flux/source operator.

The Thomas-Gladwell mechanism carries an accepted derivative `theta_dot_n`.

A BE-like nonlinear endpoint solve produces a first-order endpoint `theta_BE`, `h_BE` and endpoint derivative `theta_dot_(n+1)` satisfying:

`theta_BE = theta_n + h theta_dot_(n+1)`.

The second-order local-extrapolation moisture state is:

`theta_TG = theta_n + 0.5 h (theta_dot_n + theta_dot_(n+1))`.

The accepted state must not consist of `theta_TG` paired with the unrelated `h_BE`.

A constitutively consistent pressure endpoint `h_TG` must satisfy:

`theta(h_TG) = theta_TG`

nodewise within representation tolerance, or arise from an equivalent mixed correction that enforces the same relation.

The accepted physical storage increment is:

`DeltaS_TG = sum_i dz_i * f_i * (theta_TG_i - theta_n_i)`.

## P0 physical interval flux identity

The physical accepted-interval ledger is not allowed to be reconstructed from `DeltaS_TG` after the fact.

For the initial smooth fixed-flux qualification bank, top inflow is prescribed constant over each interval and bottom flux is zero. Therefore the independent physical external interval mass is known exactly:

`Qext_n = rain * h`.

A candidate passes physical conservation only if:

`DeltaS_TG - Qext_n = 0`

within existing authority without adding a numerical history term.

This bank deliberately avoids ambiguity about temporal quadrature of dynamic boundary fluxes.

## P0 derivative initialization

At the initial accepted state or after a hard restart event, `theta_dot_n` must be initialized from the governing physical balance, not guessed from a previous unrelated interval.

For the fixed-flux bank this means evaluating the semi-discrete physical flux divergence/source operator at the accepted state and solving the local storage-rate relation.

A first-step finite-difference derivative reconstructed from a future accepted endpoint is not allowed because it would expose future results to the bootstrap rule.

## P0 constitutive inversion

Repository reconnaissance found no existing general `theta -> pressure_head` utility.

For the P0 test bank only, a test-only inverse of the exact constitutive relation used by the benchmark material may be introduced.

Requirements:

- inversion uses the same material parameters and retention relation as the forward provider;
- no fitted approximation;
- no clipping except the already defined physical residual/saturation bounds of the constitutive law;
- round-trip `theta -> h -> theta` must be qualified before use in TIMEINT16;
- the inverse remains test-only and is not production authority.

If exact inversion is ambiguous at saturation, the saturated endpoint representation must be explicitly preregistered before such cases are exercised. P0 stays in the unsaturated smooth bank.

## Candidate set

### A. TG_MIXED_EXACT

Primary mechanism candidate.

- fully implicit hydraulic coefficients in the BE-like nonlinear endpoint solve;
- accepted moisture endpoint is `theta_TG`;
- accepted head is obtained by exact constitutive inversion/projection consistent with `theta_TG`;
- accepted derivative history is updated only after commit;
- physical interval mass is checked independently from prescribed external flux.

This candidate is mechanism-first. No predicted conductivity.

### B. TG_KPRED

Not opened until Candidate A qualifies.

If opened later:

- endpoint hydraulic coefficients may use a preregistered second-order prediction/extrapolation;
- origin and endpoint operators must remain mathematically distinct;
- no TIMEINT15-style accidental reuse of endpoint-predicted coefficients in the origin operator.

## Smooth qualification bank

Use the existing fixed-flux temporal bank:

- materials: B01 and O05;
- rain: 2 and 4 cm d-1;
- initial head: -100 cm;
- horizon: 0.04 d;
- nominal h:
  - 0.010;
  - 0.005;
  - 0.0025;
  - 0.00125 d;
- 16 nodes, 10 cm compartments;
- bottom no-flux;
- no macropores;
- no dynamic top.

Comparator:

- fully implicit Backward Euler on the identical physical bank;
- qualified BDF2 order evidence remains a separate accuracy comparator but does not define the mass ledger.

## Frozen P0 gates

Candidate A advances only if:

1. 4/4 dt ladders complete;
2. median refined top-head order >= 1.6;
3. at least 3/4 individual refined top-head orders >= 1.5;
4. terminal storage convergence is consistent with prescribed total input;
5. max absolute physical interval ledger <= 5e-8 cm;
6. max absolute cumulative physical ledger <= 5e-8 cm;
7. max constitutive round-trip water-content error <= 1e-12;
8. no nonfinite state, unexplained clipping or retry pathology;
9. median deterministic work per nominal interval <= 1.50 times fully implicit BE.

The relaxed mechanism work gate relative to TIMEINT15 is intentional and preregistered before results because an exact mixed/projection correction may add work. Cost optimization is not allowed to precede mechanism qualification.

## Interpretation rules

### Positive

If all gates pass:

`QUALIFIED_MOISTURE_THOMAS_GLADWELL_SMOOTH_MECHANISM`

Then open, in order:

1. work attribution and possible reuse of the BE nonlinear solve;
2. second-order predicted/extrapolated hydraulic coefficients;
3. event restart and derivative initialization;
4. variable-step Thomas-Gladwell/LTE control;
5. corrected dynamic-top composition.

### Negative: constitutive mismatch

If `theta_TG` cannot be paired with a physically consistent `h_TG` without a second nonlinear correction that materially changes the claimed method, close:

`CLOSED_TG_CONSTITUTIVE_STATE_INCOMPATIBLE_WITH_SWAP_ENDPOINT_CONTRACT`.

### Negative: mass

If the accepted second-order moisture state does not satisfy the independently known fixed-flux physical interval mass within authority:

`CLOSED_TG_PHYSICAL_INTERVAL_CONSERVATION_FAILED`.

No storage-derived flux reconstruction may rescue it.

### Negative: order

If mass passes but second-order convergence does not:

`CLOSED_TG_SECOND_ORDER_NOT_REPRODUCED`.

No post-hoc threshold or startup rescue inside P0.

### Negative: cost

If mechanism gates pass except the frozen 1.50x work gate:

`TG_MECHANISM_QUALIFIED_COST_BLOCKED`.

Preserve the numerical result as research authority but do not advance to dynamic top.

## Transaction semantics

P0 must already respect the intended ownership model:

- trial evaluation may construct `theta_TG`, `h_TG`, and candidate `theta_dot_(n+1)`;
- rejected trial does not mutate accepted derivative history;
- accepted derivative history updates exactly once at commit;
- checkpoint/restore must eventually include accepted derivative state;
- derivative history is numerical state, not physical water;
- the physical mass ledger remains consecutive accepted physical storage versus current-interval physical in/out.

## Production boundary

No production `src/**` change before reproducible mechanism qualification.

No mass-balance tolerance change.

No adaptive-controller tuning.

No dynamic-top Thomas-Gladwell work before P0 closes positive.

`LEGACY_NUMERICS` remains production default.
