# F-PE-NLGLOB14R4 closeout — post-release saturation-root invalid-bracket attribution

Date: 2026-09-29

Final status:

`NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`

Qualification authority:

- run `36594861072`;
- job `109497099092`;
- conclusion: SUCCESS.

## Closure

NLGLOB14R4 closes the deep-retry invalid-bracket mechanism positively.

The frozen R3 distribution is reproduced:

- 9 bracket-invalid fixtures;
- 3 retry-budget-exhausted controls.

All 9 invalid-bracket fixtures show exactly the same mechanism:

- one predictor overshoot;
- overshoot node = 16;
- node 16 already saturated at retry origin;
- zero new unsaturated-to-saturated crossings;
- zero valid positive phi candidates;
- event_node = 0;
- lower saturated block contains 13 nodes.

Therefore the invalid bracket is not a failed localization of a new saturation event.

## Scientific conclusion

The current whole-column TG post-release path conflates predictor overshoot inside an already saturated lower block with a new saturation-entry event.

This explains the invalid bracket, but removing that classification alone would not establish viable TG ownership. Three control fixtures never encounter invalid-bracket and instead exhaust all eight retry-advised attempts.

Combined NLGLOB14Q-R4 evidence therefore explicitly falsifies:

`first-retreat -> stable whole-column ordinary TG ownership`

under the current research formulation.

What remains physically defensible is a split/moving-interface ownership direction:

- TG in the unsaturated upper domain;
- saturated temporal treatment in the persistent lower block;
- transactionally coupled flux across the moving interface;
- ownership retreat tied to actual movement/disappearance of the saturated block.

## Direct successor boundary

Do not open another whole-column release threshold or root exception.

A next workunit should be a separately preregistered split-domain / moving-interface temporal-ownership feasibility study.

That study must begin observationally and preserve:

- existing first-retreat event authority;
- NLGLOB14N3 saturation-entry retry semantics;
- physical mass;
- accepted-state transactions;
- current provider consistency.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R4

BRANCH: `research/f-pe-nlglob14r4-invalid-bracket-attribution`

STATUS: closed positive mechanism attribution and whole-column release-route falsification

TEST STATUS: 12-case R3 replay with 9 invalid-bracket probes PASS

QUALIFICATION STATUS: `NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`

NEXT SAFE STEP: preregister split-domain / moving-interface temporal ownership feasibility, not another full-column TG release repair.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
