# F-PE-NLGLOB14Z21 closeout — long-horizon bidirectional persistence

Date: 2026-09-30

Final status:

`QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`

Qualification authority:

- run `36706551237`;
- HEAD fine segment-B job `109861094550`;
- RUNOFF fine segment-B job `109861094578`.

Canonical authority:

`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

## Closure

Z21 closes positively.

Both fine O05 fixtures:

- reproduce the Z20 five-change finite chatter transient exactly;
- self-settle at accepted tail `13:16`;
- show no later ownership recurrence before the next physical retreat;
- preserve exact accepted-state bidirectional ownership for more than four million nominal fine-dt intervals;
- make their first later ownership change as exact one-face retreat `13:16 -> 14:16`;
- remain finite, contiguous, mass-clean, rollback-clean and provider-valid.

Target retreat times:

- HEAD fine: `514.6110625 d`;
- RUNOFF fine: `514.6081875 d`.

## Mechanistic conclusion

The Z19 chatter is not evidence of persistent bidirectional instability in these fixtures.

Under unchanged no-hysteresis accepted-state semantics, the chatter is a short local transient followed by a long stable ownership interval and then the physically expected next retreat.

Therefore a fitted pressure/theta hysteresis band is not justified by the current evidence.

Any later anti-chatter mechanism must be motivated separately by production execution cost, coupling cleanliness or broader robustness evidence.

## Direct successor

The next safe successor should keep the same bidirectional accepted-state semantics and investigate the deeper moving-interface trajectory beyond `14:16`.

Priority questions:

1. whether later one-face retreats remain valid under bidirectional ownership;
2. whether another reverse transient appears at a deeper interface;
3. whether the saturated tail can disappear transaction-safely;
4. whether disappearance requires a separately explicit zero-tail ownership state rather than whole-column TG re-entry.

Do not extrapolate disappearance from Z21.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z21

BRANCH: `research/f-pe-nlglob14z21-long-horizon-bidirectional`

RESEARCH POSTIMAGE: `af569b99e45d9e1d9ab547c77d6454981d217d0d`

QUALIFICATION RUN: `36706551237`

QUALIFICATION STATUS: `QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`

NEXT SAFE STEP: preregister deeper bidirectional continuation beyond accepted `14:16`, preserving one-interface authority and physical mass gates.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
