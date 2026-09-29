# F-PE-NLGLOB14R3 closeout — bounded recursive post-handoff retry-depth attribution

Date: 2026-09-29

Final status:

`NLGLOB14R3_MIXED_RETRY_DEPTH`

Qualification authority:

- run `36593940226`;
- job `109493925577`;
- conclusion: SUCCESS.

## Closure

NLGLOB14R3 closes the bounded recursive retry-depth attribution without accepted post-handoff progress.

Across the 12 frozen fixtures:

- no retry depth 1..8 yields accepted TG progress;
- no retry depth yields accepted saturated-mode re-entry;
- three fixtures remain retry-advised through the full retry budget;
- nine fixtures transition at deep retry to `SATURATION_ROOT_BRACKET_INVALID`.

Every rejected attempt starts from the same accepted checkpoint and contributes zero accepted ledger delta.

Accepted state and physical mass remain valid.

## Scientific conclusion

The first-retreat TG handoff is locally valid for one interval, but persistent TG ownership is not supported by the current bounded retry authority.

The retry-depth experiment exposes a new event-semantics blocker: at sufficiently small retry dt, the saturation-root globalization can report an invalid bracket while the retry origin already contains a 13-node saturated lower block.

This must be attributed before any change to retry policy, root semantics or release timing.

## Direct successor

Open:

`F-PE-NLGLOB14R4 — post-release saturation-root invalid-bracket attribution`.

The successor must remain observational.

At representative bracket-invalid retry attempts, record:

1. the TG domain-failure trigger;
2. current saturated set at retry origin;
3. candidate event-node search values;
4. theta_tg minus theta_s on all nodes;
5. whether any node that was unsaturated at the retry origin genuinely crosses theta_s;
6. computed phi_i values for such nodes;
7. the exact reason the root search produces event_node=0 or an invalid phi.

Do not repair the root in R4.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R3

BRANCH: `research/f-pe-nlglob14r3-bounded-retry-depth`

STATUS: closed mixed negative retry-depth qualification

TEST STATUS: 12-case bounded retry bank PASS

QUALIFICATION STATUS: `NLGLOB14R3_MIXED_RETRY_DEPTH`

NEXT SAFE STEP: preregister post-release saturation-root invalid-bracket attribution.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
