# F-PE-NLGLOB02 closeout — late-iteration balance-floor stagnation

Date: 2026-09-29

Final status:

`NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@235017bbe0fbac6c4167537c645fb45ceb9172d2`

Qualification authority:

- run `36537652854`;
- job `109305308625`;
- SUCCESS.

## Closure

NLGLOB02 closes the simple attribution question positively:

the poor-model subset of the TIMEINT17 nonlinear endpoint failures is overwhelmingly a late-iteration near-floor phenomenon.

Observed authority:

- 333/335 poor-model iterations are within one diagnostic decade of the already qualified BALTOL02 balance floor;
- poor near-floor fraction ≈ 0.994;
- adequate near-floor fraction ≈ 0.330;
- poor/adequate ratio ≈ 3.01;
- median poor-model r_bal ≈ 2.91;
- all 6 route-mode families end with median r_bal <= 10.

This result combines with NLGLOB01:

- no large-step/state-scaling signal;
- poor-rho iterations have already collapsed to very small Newton corrections;
- residual/step localization remains spatially coherent;
- the remaining blocker is consistent with attainable-residual/cancellation/convergence-contract behavior.

## What is not concluded

NLGLOB02 does not authorize:

- a larger BALTOL02 floor;
- looser mass acceptance;
- accepting every near-floor state;
- more MAXIT;
- more backtracking;
- a smaller trust-region radius;
- state scaling;
- a dynamic-top event semantics claim.

BALTOL02 remains unchanged production authority.

## Direct successor

Open a separately preregistered workunit:

`F-PE-NLGLOB03 — floor-aware convergence-contract discrimination`

Its first phase must determine whether a numerically exhausted near-floor endpoint can be identified using already available physical/numerical evidence without weakening mass conservation or reclassifying unresolved states as converged.

The candidate decision rule must be preregistered before outcome exposure.

At minimum it must distinguish:

1. physical accepted-state interval mass closure;
2. effective compartment/total BALTOL02 authority;
3. head-update convergence state;
4. residual trend / stagnation evidence;
5. finite-state and route consistency;
6. unresolved cases that remain above physical or numerical authority.

No production acceptance rule changes before qualification.

## Research sequence

1. NLGLOB03 floor-aware convergence-contract discrimination;
2. if positive, return to the TIMEINT17 dynamic-top same-route bank using only the qualified contract;
3. only after endpoint robustness is restored, resume event localization;
4. TIMEINT18 variable-step/LTE remains downstream.

## Production boundary

Research-only closure.

No production `src/**` change.

No numerical defaults changed.

No mass authority changed.

`LEGACY_NUMERICS` remains production default.
