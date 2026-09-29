# F-PE-NLGLOB13D result — same-origin h/8 falsification

Date: 2026-09-29

Status:

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Qualification authority:

- workflow run: `36558791581`;
- job: `109374338130`;
- conclusion: SUCCESS.

## Frozen question

Does one additional bounded same-origin subdivision level, from a failing h/4 child to two h/8 children, make the five remaining O05/TG near-saturation targets retention-admissible?

No h/16 or recursive subdivision was permitted.

## Coverage

PASS.

All five frozen targets executed without process failure.

Smooth TIMEINT16C authority remains preserved:

- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- smooth qualification gate PASS.

Physical mass remains within authority.

## Result

First same-origin h/8 child:

- 1/5 becomes retention-admissible;
- 4/5 remain retention-inadmissible.

Full bounded h/8 pair completion:

- 0/5 complete the target interval;
- no target completes the requested horizon.

The one first-child success occurs for:

- O05 / TG / HEAD / nominal dt = 6.25e-5 d.

All five targets ultimately terminate as:

`NEARSAT_EIGHTH_FAILED`.

Observed physical ledgers remain near roundoff:

- max accepted-interval ledger about `2.24e-14 cm`;
- max cumulative ledger about `1.25e-14 cm`.

No process failure or nonfinite-state failure is observed.

## Frozen classification

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`.

The positive gate fails decisively.

## Interpretation

The near-saturation TG accepted-state defect continues to contract with temporal refinement, but a bounded h/8 rescue is still insufficient.

The first h/8 child becoming admissible in one trajectory is useful mechanistic evidence, but it does not rescue the bounded subdivision strategy because no complete h/8 pair succeeds.

The failure is not due to mass imbalance, smooth-order regression, process failure or nonfinite state.

The unresolved issue remains the accepted TG temporal construction at the saturation boundary.

## Consequence

Do not open h/16 or adaptive recursive subdivision as a continuation of this workunit.

A successor must use a different temporal construction tied explicitly to the saturation boundary.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
