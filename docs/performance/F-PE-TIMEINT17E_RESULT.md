# F-PE-TIMEINT17E result — static-route Newton/backtracking geometry attribution

Date: 2026-09-29

Status:

`TIMEINT17E_MIXED_CONTRACTION_BLOCKER`

Secondary attribution:

`TIMEINT17E_TG_SPECIFIC_NEWTON_SIGNAL`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36533045690`;
- job: `109290866340`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17E asked why the shared static-route endpoint solve exhausts the nonlinear iteration envelope after TIMEINT17D showed that the local residual/Jacobian pair is finite-difference consistent.

The audit observed the existing HeadCalc Newton/backtracking policy without changing:

- Newton corrections;
- factor schedule;
- MAXIT;
- MaxBackTr;
- tolerances;
- dt;
- forcing;
- conductivity staging;
- dynamic-top provider;
- acceptance or convergence decisions.

## Aggregate TG classification

Terminal TG endpoint failures:

`48`

Frozen TG class counts:

- `BACKTRACK_NONDECREASE`: 22;
- `POSTSTEP_GATE`: 16;
- `STAGNATION`: 9;
- `NEWTON_OVERSHOOT_WITH_RECOVERY`: 1;
- `MIXED`: 0.

No single preregistered mechanism reaches the 75% dominance threshold.

Primary classification:

`TIMEINT17E_MIXED_CONTRACTION_BLOCKER`.

## TG versus KLAG

Matched TG/KLAG endpoint-failure pairs:

`48`

Pairs with the same E class:

`25 / 48`

Shared-class fraction:

`0.5208333333`

This is below the frozen 75% shared-blocker threshold.

Secondary classification:

`TIMEINT17E_TG_SPECIFIC_NEWTON_SIGNAL`.

This does not mean the blocker is purely TG-specific. TIMEINT17B/C already established substantial shared endpoint and route-path failure. It means the detailed Newton/backtracking failure geometry is not sufficiently identical between TG and KLAG to classify E as a shared Newton blocker.

## Route decomposition

The aggregate mixed class hides a strong route structure.

### FLUX

TG, 16 failures:

- BACKTRACK_NONDECREASE: 10;
- STAGNATION: 5;
- NEWTON_OVERSHOOT_WITH_RECOVERY: 1;
- POSTSTEP_GATE: 0.

Mean iteration-level diagnostics across FLUX TG failures:

- stagnant fraction: about 0.477;
- residual-contraction fraction: about 0.711;
- full-factor acceptance fraction: about 0.453;
- reduced-step recovery fraction: about 0.344;
- exhausted backtracking iterations: 26 total.

FLUX is therefore primarily a line-search/stagnation problem.

KLAG/FLUX is similar in broad shape:

- BACKTRACK_NONDECREASE: 9;
- POSTSTEP_GATE: 3;
- STAGNATION: 4.

### HEAD

TG, 16 failures:

- POSTSTEP_GATE: 8;
- BACKTRACK_NONDECREASE: 6;
- STAGNATION: 2.

Mean residual-contraction fraction:

about `0.891`.

Post-step gate counts are split between:

- COMPARTMENT_BALANCE;
- MIXED gate combinations.

HEAD therefore frequently obtains residual-reducing Newton/backtracking candidates but still does not satisfy the complete convergence contract.

KLAG/HEAD is similar but not identical:

- POSTSTEP_GATE: 9;
- BACKTRACK_NONDECREASE: 5;
- STAGNATION: 2.

### RUNOFF

TG, 16 failures:

- POSTSTEP_GATE: 8;
- BACKTRACK_NONDECREASE: 6;
- STAGNATION: 2.

Mean residual-contraction fraction:

about `0.891`.

KLAG/RUNOFF:

- POSTSTEP_GATE: 12;
- BACKTRACK_NONDECREASE: 3;
- STAGNATION: 1.

RUNOFF therefore shows the strongest post-step-gate tendency in KLAG and a mixed post-step/backtracking failure in TG.

## Dominant convergence-gate census

Across TG endpoint failures, dominant post-step gate labels are:

- COMPARTMENT_BALANCE: 21;
- MIXED: 23;
- TOTAL_BALANCE: 4.

No single convergence gate explains the full bank.

The result does not support simply loosening one tolerance.

## Interpretation

TIMEINT17E rules out a simple single-mechanism explanation.

The next attribution must be route-specific.

For FLUX, the key question is why the residual norm often fails to decrease sufficiently even with a locally correct Jacobian.

For HEAD/RUNOFF, the key question is why residual-reducing candidates still fail the complete convergence contract and which compartments/gates remain active.

Therefore a global MAXIT increase, a global tolerance relaxation or a global backtracking change is not scientifically justified from E.

## Required successor

Open:

`F-PE-TIMEINT17F — route-specific nonlinear failure decomposition`.

TIMEINT17F should keep the frozen A2 fixtures and numerical settings and split into:

1. FLUX line-search/stagnation localization by node and residual component;
2. HEAD/RUNOFF post-step convergence-gate localization by node, surface balance and total balance;
3. matched TG/KLAG comparison at the same material/route/dt fixtures.

No repair belongs inside F.

## Mass and transaction consequence

No failed endpoint trial is accepted.

No failed-trial mass is published.

TIMEINT17E is logging-only and does not change accepted physical state.

## Production boundary

No production `src/**` change.

No tolerance change.

No MAXIT or backtracking change.

No event localization.

No adaptive timestep work.

`LEGACY_NUMERICS` remains production default.
