# F-PE-TIMEINT03 result — mixed-state backward-Euler LTE mechanism

Date: 2026-09-28

Status: `MIXED_STATE_LTE_MECHANISM_QUALIFIED`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Primary evidence:

- preregistration: `docs/performance/F-PE-TIMEINT03_PREREGISTRATION.md`;
- Actions run: `36436464071`;
- conclusion: SUCCESS.

## Result

Complete full-versus-two-half physical points:

`60/64`.

All complete points retained finite mixed-state LTE metrics and passed the water-ledger requirement.

### Water-content LTE

Spearman correlation:

`LTE_THETA_INF` versus actual max theta endpoint difference:

`0.7808`.

Required:

`>=0.75`.

PASS.

### Water-depth LTE

Spearman correlation:

`LTE_WATER_L1` versus actual L1 water-depth endpoint difference:

`0.7921`.

Required:

`>=0.75`.

PASS.

### Improvement over head-only LTE

TIMEINT02 head-only correlation:

`0.5874`.

Best mixed-state correlation:

`0.7921`.

Improvement:

about `+0.205`.

Required improvement:

at least `+0.10`.

PASS.

## Combined diagnostic score

Frozen diagnostic score:

`S = max(LTE_H_INF / 0.50 cm, LTE_THETA_INF / 1e-4)`.

At `S <= 1`:

- predicted safe points: 26;
- safe coverage: about 53.1%;
- false-safe points: 0.

This score was diagnostic only in TIMEINT03, but the primary mechanism gates also passed. It is therefore eligible to be promoted as a separately preregistered controller candidate.

## Interpretation

The main failure of TIMEINT02 was not that derivative-history LTE is fundamentally uninformative.

The pressure-head-only representation was incomplete for a mixed-form mass-conservative Richards discretization.

Adding water-content evolution substantially improves ordering of actual temporal error.

This is consistent with the canonical residual, whose storage term is written in theta while pressure head is the nonlinear potential variable.

## Decision

Advance the mixed-state LTE mechanism to closed-loop adaptive backward-Euler qualification.

No production timestep authority is granted by TIMEINT03 itself.

