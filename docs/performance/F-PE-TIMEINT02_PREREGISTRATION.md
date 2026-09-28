# F-PE-TIMEINT02 preregistration — raw derivative-based backward-Euler LTE mechanism

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Parent:

F-PE-TIMEINT01 temporal-discretization reconstruction.

## Candidate estimator

For a converged backward-Euler full-step candidate over dt, define:

`h_dot_current = (h_candidate - h_origin) / dt`.

Using the accepted predecessor derivative `h_dot_previous`, define the classical first-order backward-Euler local truncation-error estimate:

`e_raw = 0.5 * dt * (h_dot_current - h_dot_previous)`.

Primary scalar:

`LTE_INF = max_i |e_raw_i|`.

This is evaluated directly in pressure-head units.

No defect-operator solve is used.

No extra nonlinear solve is required to evaluate the estimator.

## Rationale

This estimator is the direct pressure-head LTE form used in adaptive backward-Euler/Thomas-Gladwell literature.

It is distinct from DYNERR01, which applied an additional defect/operator transformation to the same derivative history.

DYNERR01's failure therefore does not decide the raw LTE mechanism.

## Mechanism bank

Use the already exposed DYNERR01 mechanism design:

- 16 BOFEK01 screening material/regime cases;
- one strict 0.005 d history step to create predecessor derivative;
- requested steps:
  - 0.005 d;
  - 0.010 d;
  - 0.020 d;
  - 0.040 d;
- full step and independent two-half route from the same accepted origin.

Maximum planned points: 64.

This is mechanism characterization, not validation.

## Physical truth label

For every complete full/two-half point calculate:

- actual max head difference;
- runoff difference;
- ponding difference;
- storage difference;
- regime path.

A point is locally P-C1-safe when:

- max head difference <= 0.50 cm;
- runoff difference <= 0.01 cm;
- ponding difference <= 0.01 cm;
- storage difference <= 0.01 cm;
- ledgers <= 5e-8 cm.

## Frozen estimator rules

Evaluate three raw LTE thresholds:

- L025: LTE_INF <= 0.25 cm;
- L050: LTE_INF <= 0.50 cm;
- L100: LTE_INF <= 1.00 cm.

No threshold fitting after exposure.

## Advancement gates

A threshold advances only if:

1. at least 48/64 points have complete full and two-half physical solutions;
2. LTE_INF is finite on every complete point;
3. Spearman rank correlation between LTE_INF and actual max head difference >= 0.75;
4. false-safe count relative to the local P-C1-safe label = 0;
5. at least 20% of complete points are classified safe by the LTE threshold;
6. all mass ledgers pass.

If no threshold advances but correlation >=0.75, a separately preregistered boundary-transition guard study may be considered.

If correlation <0.75, close the raw LTE mechanism.

## Production boundary

No production source modification and no timestep authority in TIMEINT02.
