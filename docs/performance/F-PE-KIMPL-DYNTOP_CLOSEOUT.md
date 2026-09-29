# F-PE-KIMPL-DYNTOP01-02 closeout — fully implicit dynamic-top robustness

Date: 2026-09-29

Final status:

`CLOSED_KIMPL_DYNTOP_RECOVERABLE_BUT_COSTLY`

## Evidence

### KIMPL-DYNTOP01

Newton traces show:

- no balance-floor stall;
- no gross Jacobian divergence;
- B01 wet transition requires temporary damping, then converges;
- O14 wet shows monotone but slow Newton contraction;
- MAXIT=8 is reached before convergence criteria are met.

### KIMPL-DYNTOP02

Increasing iteration capacity recovers all six failing TIMEINT12A cases by MAXIT24.

But one O14/MOIST trajectory requires the full 24-iteration arm and accumulates work index 1012.

## Consequence for timestep modernization

Fully implicit conductivity remains mathematically valid and robust enough when given sufficient Newton work.

It is not currently attractive as the default dynamic-top operator for a performance-oriented modern integrator.

Therefore the next integrator study should not simply combine:

- variable-step BDF2;
- SWKIMPL=1;
- higher MAXIT.

That route risks exchanging fewer timesteps for substantially more nonlinear work per step.

## Recommended successor

Study a second-order-consistent predicted conductivity/operator:

`F-PE-TIMEINT13 — BDF2 with explicit second-order conductivity prediction`.

Candidate idea:

- retain fully implicit BDF2 storage/head-gradient structure;
- predict face/top conductivity to the new time level from accepted history;
- keep predicted conductivity fixed during Newton, avoiding the strongest KIMPL nonlinear coupling;
- require observed second-order convergence before any performance claim;
- fail closed / first-order restart when history or regime smoothness is invalid.

This directly tests the remaining option already identified in TIMEINT01 but not yet qualified.

## Production boundary

No production source change.

LEGACY_NUMERICS remains default.
