# F-PE-NLGLOB13C2 result — same-origin h/4 admissibility probe

Date: 2026-09-29

Status:

`NLGLOB13C2_SAME_ORIGIN_H4_CONTRACTION_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@c3207db3a95ac120c133f130ecfa328963ebfe29`

Qualification authority:

- workflow run: `36557808916`;
- job: `109371154461`;
- conclusion: SUCCESS.

## Frozen question

Does the first h/4 child from the exactly restored failing h/2 parent origin either become retention-admissible or contract the parent accepted-state overshoot under the frozen gates?

## Coverage

PASS.

All 7/7 target trajectories have complete same-origin parent and first-child diagnostics.

No process failures occur.

The pre-state identity authority is inherited from NLGLOB13C1 and the current C2 probe uses the same restored h/2 parent origin.

## Result

Of the seven first h/4 children:

- 2/7 become fully retention-admissible;
- 5/7 remain retention-inadmissible but all five have smaller normalized overshoot than their h/2 parent;
- 0/7 are noncontracting.

All 7/7 satisfy the strong preregistered contraction criterion, meaning each target either resolves at h/4 or contracts with ratio <=0.60.

Frozen classification:

`NLGLOB13C2_SAME_ORIGIN_H4_CONTRACTION_CONFIRMED`.

## Interpretation

The accepted-state domain defect is temporally local and contracts with temporal refinement from the same physical origin.

For two targets, halving the failing h/2 interval once more is already sufficient.

For the remaining five targets, the h/4 child still overshoots but the overshoot contracts substantially.

This resolves the lineage ambiguity that blocked NLGLOB13C.

## Consequence

One separately preregistered bounded h/8 falsification is authorized, restricted to the five same-origin h/4 children that remain inadmissible.

No recursion beyond h/8 is authorized.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
