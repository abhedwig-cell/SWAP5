# F-PE-NLGLOB13C1 closeout — pre-state identity reconciliation

Date: 2026-09-29

Final status:

`NLGLOB13C1_PRESTATE_IDENTITY_CONFIRMED`

Qualification authority:

- run `36556917004`;
- job `109368171650`;
- SUCCESS.

## Closure

Rollback/state restoration is exact on the seven near-saturation target trajectories.

All measured theta, head, ponding and storage differences between the failing h/2 parent origin and the first h/4 retry origin are exactly zero in the recorded floating-point state.

The NLGLOB13C identity blocker was therefore caused by comparing a later quarter-2 origin with the original h/2 parent in two trajectories where quarter 1 had already succeeded.

## Direct successor

Open:

`F-PE-NLGLOB13C2 — same-origin h/4 admissibility probe`.

C2 remains observational.

For each target trajectory it must evaluate the first h/4 trial from the exactly restored failing h/2 parent origin and record whether the prospective accepted TG state is:

- out of domain, with overshoot magnitude; or
- fully retention-admissible.

No h/8 step is allowed.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB13C1

BASELINE: `84aabef0f199fc8d1136f7ef66d90fba15033ffd`

BRANCH: `research/f-pe-nlglob13c1-prestate-identity`

STATUS: closed positive

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB13C1_PRESTATE_IDENTITY_CONFIRMED`

NEXT SAFE STEP: preregister NLGLOB13C2 same-origin h/4 admissibility probe

## Production boundary

No production source or numerical acceptance change.

`LEGACY_NUMERICS` remains production default.
