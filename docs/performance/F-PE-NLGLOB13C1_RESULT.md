# F-PE-NLGLOB13C1 result — failing-half pre-state identity reconciliation

Date: 2026-09-29

Status:

`NLGLOB13C1_PRESTATE_IDENTITY_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@84aabef0f199fc8d1136f7ef66d90fba15033ffd`

Qualification authority:

- workflow run: `36556917004`;
- job: `109368171650`;
- conclusion: SUCCESS.

## Frozen question

Does rollback restore the exact accepted pre-state before the first h/4 child trial after a failing h/2 accepted-state-domain probe?

## Result

Coverage passes for all 7 target trajectories.

All 7/7 parent-prestate versus first-quarter retry pairs are nodewise identical.

Maximum observed differences:

- max absolute theta difference: `0.0`;
- max theta ULP difference: `0.0`;
- max absolute pressure-head difference: `0.0 cm`;
- max head ULP difference: `0.0`;
- max ponding difference: `0.0 cm`;
- max volume-weighted storage difference: `0.0 cm`.

No process failures occur.

## Frozen classification

`NLGLOB13C1_PRESTATE_IDENTITY_CONFIRMED`.

## Interpretation

The NLGLOB13C coverage blocker is not a transaction or rollback defect.

The h/2 failing trial is restored exactly before quarter 1 is attempted.

The two NLGLOB13C pairs that appeared to violate same-pre-state identity correspond to quarter-2 failures after quarter 1 had already been physically accepted. Their different origin is therefore legitimate temporal lineage, not state leakage.

This distinction matters:

- for five trajectories, the failing h/4 child is quarter 1 and can be compared directly with its h/2 parent from the same origin;
- for two trajectories, quarter 1 succeeds and quarter 2 later fails, so the terminal h/4 failure is not a same-origin scaling pair.

## Consequence

NLGLOB13C remains formally blocked for the two quarter-2 cases under its original same-origin failure-pair definition.

Open a separately preregistered C2 same-origin admissibility probe for the restored h/2 parent state.

C2 should ask whether the first h/4 child from that exact parent origin:

- still overshoots the retention domain; or
- is already admissible.

No h/8 execution is authorized.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
