# F-PE-NLGLOB02 result — balance-floor stagnation attribution

Date: 2026-09-29

Status:

`NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`

Canonical base:

`integration/f-ci-canonical@235017bbe0fbac6c4167537c645fb45ceb9172d2`

Qualification authority:

- workflow run: `36537652854`;
- job: `109305308625`;
- conclusion: SUCCESS.

## Frozen question

Do the poor-model Newton iterations in the TIMEINT17 endpoint-failure bank occur primarily after the solve has reached the already qualified BALTOL02 numerical balance-resolution floor?

No solver behavior was changed.

## Coverage

PASS.

- audited failing Newton iterations: 768;
- poor-model iterations, selected rho < 0.25: 335;
- finite balance-ratio diagnostics: 100%;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and KLAG;
- materials: B01, B12, O05, O14;
- all four frozen dt levels;
- process failures: 0.

## Aggregate result

Poor-model balance-floor bands:

- AT_FLOOR: 0;
- NEAR_FLOOR, 1 < r_bal <= 10: 333;
- ABOVE_FLOOR: 2.

Adequate-model bands:

- AT_FLOOR: 0;
- NEAR_FLOOR: 143;
- ABOVE_FLOOR: 290.

Key frozen metrics:

- poor-model near-floor fraction: `0.99403`;
- adequate-model near-floor fraction: `0.33025`;
- poor/adequate near-floor ratio: `3.0099`;
- median poor-model r_bal: `2.9105`;
- median adequate-model r_bal: about `1.19e7`;
- route-mode families with final median r_bal <= 10: `6/6`.

All frozen conditions for `NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL` pass.

## Route/mode structure

Final-iteration median r_bal:

- FLUX / KLAG: about 1.90;
- FLUX / TG: about 1.98;
- HEAD / KLAG: about 3.00;
- HEAD / TG: about 2.87;
- RUNOFF / KLAG: about 3.63;
- RUNOFF / TG: about 3.02.

Poor-model near-floor fractions are approximately 0.98 to 1.00 in every route-mode family.

The signal is therefore not FLUX-specific and is shared by TG and KLAG.

## Interpretation

NLGLOB01 already showed that poor model quality is not associated with large Newton corrections. NLGLOB02 now shows that almost every poor-rho iteration occurs only after the nonlinear solve has reduced the balance residual to within one decade of the existing qualified BALTOL02 floor.

This supports a late-iteration numerical-resolution/stagnation interpretation.

It does not authorize a looser mass balance.

It does not show that the BALTOL02 floor itself should be changed.

It does not establish that every near-floor endpoint should be accepted.

The remaining question is whether the convergence contract can distinguish:

1. a numerically exhausted state whose remaining residual is within qualified attainable resolution and whose physical accepted-state mass contract is already satisfied; from
2. a physically or numerically unresolved state that merely happens to have small Newton corrections.

That distinction requires a separately preregistered convergence-contract experiment.

## Consequence

Per preregistration:

- do not tighten balance tolerances;
- do not add more damping;
- do not open state scaling;
- do not select a trust-region radius;
- do not change BALTOL02;
- open a separate floor-aware convergence-contract workunit.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance or mass-gate change.

No MAXIT, backtracking, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
