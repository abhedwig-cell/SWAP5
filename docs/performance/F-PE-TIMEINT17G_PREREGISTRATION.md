# F-PE-TIMEINT17G preregistration — full-column residual/Jacobian finite-difference attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17D: `TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE` for provider and top row;
- TIMEINT17E: `TIMEINT17E_MIXED_CONTRACTION_BLOCKER`;
- TIMEINT17F: `TIMEINT17F_ROUTE_STRUCTURED_INTERIOR_DOMINANCE`.

Canonical authority at preregistration:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Question

Is the full 16-node tridiagonal Jacobian used by HeadCalc the finite-difference derivative of the actual residual operator on the nonlinear iterates that fail in TIMEINT17?

TIMEINT17D certified only the top row. TIMEINT17F shows that the dominant residual location is usually interior.

## Frozen bank and solver settings

Use the exact TIMEINT17A2 bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- TG and matched KLAG;
- 16 nodes;
- MAXIT=8;
- MaxBackTr=8;
- unchanged tolerances;
- unchanged fixed-K staging;
- unchanged dynamic-top provider.

No trial or solver decision is changed.

## In-solver audit point

At each nonlinear iteration, immediately after the normal call to `jacobian_F()` and before the normal linear solve:

1. preserve the complete trial state and residual;
2. preserve provider-derived surface state;
3. preserve the analytic tridiagonal arrays:
   - upper;
   - main;
   - lower;
4. perturb one pressure-head unknown at a time by symmetric epsilon;
5. recompute water content and the residual through the same constitutive/provider/vector_F code path;
6. restore the exact base trial state before the next perturbation and before the real solver continues.

The audit is observational only.

## Epsilon ladder

Use:

- 1e-4 cm;
- 3e-5 cm;
- 1e-5 cm;
- 3e-6 cm.

For each matrix entry select the best stable finite-difference comparison across the ladder.

A perturbation is eligible only when:

- dynamic-top provider remains available;
- route remains the same as the unperturbed iterate;
- all quantities remain finite.

## Matrix entries

Only the tridiagonal stencil entries are compared.

For residual row i:

- derivative with respect to h_(i-1), where present;
- derivative with respect to h_i;
- derivative with respect to h_(i+1), where present.

No zero off-stencil entries are used to inflate pass fractions.

## Frozen tolerance

An analytic entry passes when either:

`abs(J_analytic-J_FD) <= 1e-7`

or

`abs(J_analytic-J_FD) <= 1e-5 * abs(J_FD)`.

These are the same numerical scales used in TIMEINT17D.

## Frozen outputs

Per audited nonlinear iterate report:

- route;
- nonlinear iteration index;
- number of eligible stencil entries;
- number of failing stencil entries;
- maximum absolute mismatch;
- maximum relative mismatch;
- row of worst mismatch;
- column of worst mismatch;
- whether the worst row is TOP, INTERIOR or BOTTOM.

Aggregate separately for TG/KLAG and FLUX/HEAD/RUNOFF.

## Frozen classifications

### FULL_JACOBIAN_MISMATCH

`TIMEINT17G_FULL_JACOBIAN_MISMATCH`

if >=25% of eligible audited nonlinear iterates have at least one failing tridiagonal entry.

Report localization:

- TOP;
- INTERIOR;
- BOTTOM;
- DISTRIBUTED.

### FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER

`TIMEINT17G_FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER`

if <=10% of eligible audited nonlinear iterates contain any failing entry and the frozen endpoint failures remain reproduced.

### MIXED_JACOBIAN_SIGNAL

Otherwise:

`TIMEINT17G_MIXED_JACOBIAN_SIGNAL`.

## Coverage gate

A conclusive G result requires:

- all three routes;
- at least three materials;
- at least three dt levels;
- at least 100 eligible audited nonlinear iterates in total.

Otherwise:

`BLOCKED_TIMEINT17G_FD_COVERAGE`.

## Consequence

If full Jacobian mismatch is found:

- next work localizes the responsible interior term before any repair.

If full Jacobian is consistent:

- stop residual/Jacobian algebra attribution;
- next research may address globalization, scaling, trust-region/line-search formulation or variable transformation;
- do not increase MAXIT or relax tolerances as the first repair.

## Stop rules

TIMEINT17G does not:

- modify production `src/**`;
- change Newton corrections;
- change backtracking factors;
- change MAXIT;
- change tolerances;
- change dt;
- change physical equations;
- change K staging;
- change route/event semantics.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
