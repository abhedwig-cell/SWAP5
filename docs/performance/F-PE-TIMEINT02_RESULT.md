# F-PE-TIMEINT02 result — raw derivative-based backward-Euler LTE mechanism

Date: 2026-09-28

Status: `CLOSED_RAW_HEAD_LTE_NOT_PREDICTIVE_ENOUGH`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Primary evidence:

- preregistration: `docs/performance/F-PE-TIMEINT02_PREREGISTRATION.md`;
- Actions run: `36435835510`;
- job: `108973402491`;
- conclusion: SUCCESS.

## Mechanism

For each complete full-step candidate:

`h_dot_current = (h_candidate-h_origin)/dt`

and accepted predecessor derivative:

`h_dot_previous`.

Raw backward-Euler LTE estimate:

`e_raw = 0.5*dt*(h_dot_current-h_dot_previous)`

with:

`LTE_INF = max|e_raw|`.

No extra solve is required for this estimate.

## Evidence

Planned points: 64.

Complete full + two-half points:

`60/64`.

Every complete point retained finite LTE and passed the water-ledger requirement.

Spearman rank correlation between `LTE_INF` and actual full-versus-two-half max head difference:

`0.5874`.

Frozen required correlation:

`>=0.75`.

Therefore the mechanism does not advance.

## Threshold behavior

### L025

`LTE_INF <=0.25 cm`

- predicted safe: 27/60;
- safe coverage: about 55.1%;
- false-safe: 0.

### L050

`LTE_INF <=0.50 cm`

- predicted safe: 33/60;
- safe coverage: about 67.3%;
- false-safe: 0.

### L100

`LTE_INF <=1.00 cm`

- predicted safe: 42/60;
- safe coverage: about 83.7%;
- false-safe: 1.

The single L100 false-safe is O05/WET at dt=0.04 d:

- LTE_INF about 0.576 cm;
- actual head difference about 0.539 cm;
- no dynamic-top regime-path mismatch;
- runoff/ponding/storage differences remain zero.

## Interpretation

The raw derivative-based head LTE is materially better behaved as a conservative classifier than the dynamic-top defect-operator indicator:

- no severe boundary-transition false-safe occurs at the tighter thresholds;
- 0.25 and 0.50 cm thresholds are false-safe-free on the exposed mechanism bank.

However, the global rank correlation is too weak for qualification as a general local temporal-error estimator.

The failure is therefore not simply a boundary-regime discontinuity problem.

A likely remaining mismatch is variable choice: the canonical Richards discretization is mixed-form and conserves water through `theta`, while TIMEINT02 estimates truncation error only in pressure head.

## Decision

Do not grant raw pressure-head LTE timestep authority.

Do not fit a post-hoc head threshold.

Advance to a separately preregistered mixed-state LTE study that evaluates water-content/storage error in addition to pressure head.

