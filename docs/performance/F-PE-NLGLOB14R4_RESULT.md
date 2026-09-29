# F-PE-NLGLOB14R4 result — post-release saturation-root invalid-bracket attribution

Date: 2026-09-29

Status:

`NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`

Qualification authority:

- workflow run: `36594861072`;
- job: `109497099092`;
- conclusion: SUCCESS.

## Frozen question

Why do 9 of the 12 bounded post-handoff retry trajectories terminate with `SATURATION_ROOT_BRACKET_INVALID`?

## Coverage

PASS.

The frozen R3 distribution is reproduced exactly:

- 9 bracket-invalid fixtures;
- 3 retry-budget-exhausted controls;
- zero process failures;
- accepted state and physical mass remain clean.

## Mechanism

All 9 bracket-invalid fixtures classify:

`EXISTING_SATURATED_OVERSHOOT_WITHOUT_NEW_CROSSING`.

For every affected fixture:

- exactly one node overshoots `theta_s`;
- that node is node 16;
- node 16 is already saturated at the retry origin;
- genuine new unsaturated-to-saturated crossings = 0;
- valid positive phi candidates = 0;
- selected event_node = 0;
- phi_hi remains effectively huge/unset;
- saturated-node count at the retry origin = 13.

Thus the frozen aggregate classification is:

`NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`.

## Direct code attribution

The current NLGLOB14A research event wrapper declares a TG domain failure when any node satisfies:

`theta_tg > theta_s`.

It then tries to localize a new saturation crossing using:

`phi_i = (theta_s-theta_origin)/(theta_tg-theta_origin)`

with `phi_i > 0`.

For node 16 in these post-release states:

`theta_origin = theta_s`.

Therefore:

`phi_i = 0`.

The same already-saturated node can trigger domain failure but cannot define a positive new-crossing root bracket.

This is exactly why `event_node=0` and the bracket is declared invalid.

## Scientific interpretation

The post-release failure is not evidence of a new saturation-entry event.

It is evidence that ordinary full-column TG evolution is attempting to advance a node that is already inside the persistent saturated lower block.

The event detector then misclassifies this already-saturated predictor overshoot as a candidate new saturation event.

This explains the bracket-invalid branch, but it does not make continued full-column TG ownership valid.

Three control fixtures never reach bracket-invalid and instead remain retry-advised through the full bounded retry budget. Therefore removing only the invalid-bracket classification would not establish stable full-column TG continuation.

## Consequence

The route:

`first-retreat event -> release entire column to ordinary TG`

is explicitly falsified as a stable temporal-ownership rule under the current research formulation.

The next physically defensible direction is not a threshold tweak or root exception.

It is a moving-interface / split-domain temporal ownership formulation in which:

- the unsaturated upper domain may use TG;
- the persistent lower saturated block retains saturated treatment;
- the moving interface and interfacial flux are transactionally coupled;
- ownership changes only as the saturated block actually retreats.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical default, root rule or production temporal-mode policy changed.

`LEGACY_NUMERICS` remains production default.
