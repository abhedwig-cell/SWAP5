# F-PE-NLGLOB13C2 preregistration — same-origin h/4 admissibility probe

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@c3207db3a95ac120c133f130ecfa328963ebfe29`

Parent authority:

- NLGLOB13B: all seven frozen O05/TG near-saturation trajectories still fail somewhere at h/4 depth;
- NLGLOB13C: all seven observed terminal h/2 -> terminal h/4 overshoots contract, but two pairs were not same-origin;
- NLGLOB13C1: rollback is exact for 7/7; the two C identity mismatches occur because quarter 1 succeeds and quarter 2 later fails.

## Purpose

NLGLOB13C2 evaluates the first h/4 trial started from the exactly restored failing h/2 parent origin.

This resolves the lineage ambiguity in NLGLOB13C.

For each target the first same-origin h/4 trial may either:

1. remain retention-inadmissible, in which case its overshoot can be compared directly with the h/2 parent overshoot; or
2. become retention-admissible, in which case halving has fully removed the parent overshoot at that origin.

No h/8 solve is executed.

## Frozen target bank

Reuse exactly the seven NLGLOB13C/C1 O05-TG target trajectories.

The failing h/2 parent is the first accepted-state domain failure at step size h/2 in the existing bounded subdivision lineage.

After exact rollback, inspect the first h/4 child from that same origin.

## Frozen diagnostics

For the failing h/2 parent record:

- normalized overshoot `O_parent`;
- prospective accepted `theta_TG` min/max;
- failing node;
- pre-state identity.

For the first same-origin h/4 child record:

- whether the prospective accepted TG state is retention-admissible;
- if inadmissible, normalized overshoot `O_child`;
- prospective theta min/max;
- node of maximal overshoot;
- same-origin pre-state identity.

For inadmissible child cases define:

`Q = O_child / O_parent`.

For admissible child cases define the parent overshoot as `RESOLVED_AT_H4`; do not invent a negative or fitted overshoot.

## Frozen interpretation

Classify:

`NLGLOB13C2_SAME_ORIGIN_H4_CONTRACTION_CONFIRMED`

only if all hold:

1. 7/7 target trajectories have complete parent and first-child diagnostics;
2. pre-state identity is confirmed for all 7;
3. every target either:
   - becomes admissible at first h/4; or
   - remains inadmissible with `Q < 1`;
4. at least 5/7 targets either become admissible or have `Q <= 0.60`;
5. no route, ponding, nonfinite or mass anomaly precedes the probe.

If at least 4/7 same-origin h/4 children remain inadmissible with `Q >= 0.9`:

`NLGLOB13C2_SAME_ORIGIN_H4_NONCONTRACTING`.

Otherwise:

`NLGLOB13C2_MIXED_SAME_ORIGIN_H4`.

If paired diagnostics cannot be established faithfully:

`BLOCKED_NLGLOB13C2_COVERAGE`.

## Consequence

A positive result authorizes one separately preregistered bounded h/8 falsification workunit on only those same-origin h/4 children that remain inadmissible.

It does not authorize recursive/adaptive subdivision or production acceptance.

If all seven first h/4 children are admissible, no h/8 experiment is needed for the parent-origin question; the residual quarter-2 failures must instead be treated as a new later-origin temporal event.

## Stop rules

Do not:

- execute h/8 in NLGLOB13C2;
- change the 0.60 or 0.90 gates after result exposure;
- clip accepted theta;
- alter S0/R0;
- change BALTOL02, MAXIT, backtracking or route physics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.


## Diagnostic amendment before final rerun

The first C2 execution exposed a harness-only coverage mismatch: the redundant in-run C1 log parser re-observed pre-state identity in 5/7 cases, while the parent NLGLOB13C1 authority has already established exact rollback identity for these same seven target trajectories, including the two coarse HEAD/RUNOFF cases, with zero theta, head, ponding and storage difference.

The frozen C2 gate requires that pre-state identity be confirmed for all seven. That condition is already satisfied by the canonical parent authority and is not scientifically re-opened in C2.

For the final C2 rerun:

- NLGLOB13C1 canonical 7/7 exact identity is the identity authority;
- the local C2 C1-log parse is retained as a diagnostic re-observation only;
- C2 coverage requires parent and first same-origin h/4 child prospective-state diagnostics for all 7 and zero process failure;
- no contraction, admissibility, 0.60 or 0.90 gate changes;
- no solver behavior changes.

This amendment does not rescue a scientific failure. It removes a redundant parser-specific coverage condition that contradicted already qualified parent authority.
