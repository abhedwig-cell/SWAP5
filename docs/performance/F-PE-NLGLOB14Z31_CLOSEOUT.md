# F-PE-NLGLOB14Z31 closeout — adaptive cumulative-drift attribution

Date: 2026-09-30

Final status:

`BLOCKED_Z31_PROTOCOL_EXECUTION_MISMATCH`

Qualification authority:

- workflow run `36751697504`;
- HEAD segment-B job `110018093760`;
- RUNOFF segment-B job `110018093607`.

Canonical authority:

`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

## Closure

Z31 does not receive one of its frozen descriptive drift classifications because the executable retained Z30 stop conditions that were not part of the Z31 preregistered stop contract.

HEAD terminated around 274.012 d on an old instantaneous A/B h/theta envelope.

RUNOFF terminated at 514.608125 d when the adaptive 13:16 -> 14:16 retreat occurred one nominal interval before the full reference.

Neither condition was an authorized Z31 termination condition.

The exposed run therefore cannot be repaired in place.

## Preserved partial evidence

The non-qualifying evidence is nevertheless highly consistent across both fixtures:

- tail 12:16 / n=12 contributes only machine-scale signed drift;
- first-family chatter contributes only machine-scale signed drift;
- essentially all measurable cumulative drift begins in tail 13:16 / n=13;
- the reduced trajectory still saves substantial deterministic solver work;
- RUNOFF shows that long-horizon accumulated state drift can eventually shift a later ownership event by roughly one fine nominal interval.

These observations are hypotheses/attribution leads only, not a qualified Z31 classification.

## Direct successor

Open:

`F-PE-NLGLOB14Z31R — protocol-correct cumulative-drift attribution re-execution`.

The successor must:

1. freeze the same Z31 fixtures, physics, attribution metrics and 140–540 d horizon;
2. explicitly remove the inherited Z30 h/theta/cumulative-difference stop conditions;
3. explicitly remove same-nominal-step event-direction mismatch as a stop condition;
4. stop only on the Z31 physical blockers:
   - non-finite state;
   - reconstruction failure;
   - nonlinear solve failure;
   - noncontiguous saturated tail;
   - ownership jump >1 face;
   - adaptive per-interval physical ledger >5e-8 cm;
5. record event timing differences rather than use them to terminate;
6. apply the frozen Z31 attribution classifications only after the protocol-correct run.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z31

BRANCH: `research/f-pe-nlglob14z31-drift-attribution`

RESULT POSTIMAGE BEFORE CLOSEOUT: `1871af9ac6c562e82c6cba8c16b3152f09040412`

STATUS: `BLOCKED_Z31_PROTOCOL_EXECUTION_MISMATCH`

NEXT SAFE STEP: Z31R protocol-correct re-execution.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
