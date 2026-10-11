# F-PE-NLGLOB11 closeout — half-step TG coefficient predictor

Date: 2026-09-29

Final status:

`CLOSED_TG_HALFSTEP_PREDICTOR_DOMAIN_NOT_RESOLVED`

with independent order finding:

`TG_HALFSTEP_PREDICTOR_SECOND_ORDER_REGRESSION`.

Canonical base incorporated before closeout:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Qualification authority:

- run `36550910609`;
- job `109348570855`;
- SUCCESS.

## Closure

The fixed half-step moisture predictor is closed.

It is not a valid replacement for the TIMEINT16C endpoint coefficient stage because:

1. all seven target predictor-domain exits persist;
2. the smooth second-order authority collapses to approximately first order;
3. changing phi therefore changes the temporal mechanism materially.

Mass and deterministic work are not the failure.

## Preserved positive authority

TIMEINT16C remains valid for the original endpoint moisture predictor on its qualified smooth bank.

NLGLOB08 remains valid for S0 tail inertness.

NLGLOB10 remains valid that the seven dynamic failures are predictor overshoots from admissible accepted states.

## Direct successor

Open:

`F-PE-NLGLOB11A — head-space endpoint coefficient predictor`.

Frozen concept to preregister before results:

`h_dot_n = theta_dot_n / C(h_n)`

`h_tilde = h_n + h h_dot_n`.

Evaluate K through the same constitutive provider on h_tilde.

Requirements:

- retain endpoint temporal location;
- no moisture clipping;
- accepted TG state unchanged;
- current-step-only staging;
- smooth TIMEINT16C order must be requalified;
- dynamic-top replay must show zero predictor-domain failures and satisfy physical mass authority.

The head-space candidate must fail closed where capacity is nonfinite, nonpositive, or too small for a meaningful chain-rule derivative. No threshold for that case may be invented after results.

## Closed routes

Do not test other fixed phi values as rescue of this workunit.

Do not lower the dynamic recovery gate.

Do not reinterpret the 78/96 recovery as qualification because the mandatory smooth-order and predictor-domain gates failed.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB11

BASELINE: `6ce07b5578c0c1193d2d21a2449a1b7788714f40`

BRANCH: `research/f-pe-nlglob11-halfstep-predictor`

STATUS: closed negative

TEST STATUS: focused run PASS

QUALIFICATION STATUS: candidate falsified

NEXT SAFE STEP: preregister NLGLOB11A head-space endpoint coefficient predictor

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
