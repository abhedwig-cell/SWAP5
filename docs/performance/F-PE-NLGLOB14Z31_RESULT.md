# F-PE-NLGLOB14Z31 result — adaptive cumulative-drift attribution

Date: 2026-09-30

Status:

`BLOCKED_Z31_PROTOCOL_EXECUTION_MISMATCH`

Qualification authority:

- workflow run: `36751697504`;
- HEAD segment-B job: `110018093760`;
- RUNOFF segment-B job: `110018093607`;
- workflow jobs concluded SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

Research postimage before result persistence:

`research/f-pe-nlglob14z31-drift-attribution@4c101f5ae970664cd133ef04714ecd4bfb768b8a`

## Why Z31 does not qualify

The frozen Z31 preregistration required the independent full/adaptive trajectories to continue from 140 d to 540 d unless one of the explicitly listed physical blockers occurred:

- non-finite state;
- reduced reconstruction failure;
- nonlinear solve failure;
- noncontiguous saturated tail;
- ownership jump > 1 face;
- adaptive per-interval physical ledger > 5e-8 cm.

The materialized runner accidentally retained two Z30 stop conditions that were **not** Z31 stop conditions:

1. HEAD stopped when the old Z30 instantaneous h/theta comparison envelope was crossed;
2. RUNOFF stopped when the old Z30 same-nominal-step event-direction comparison triggered.

Because results were exposed before this mismatch was recognized, the runner must not be repaired in place and rerun under the same exposed protocol.

Therefore none of the frozen Z31 descriptive drift classifications is claimed.

## HEAD execution

Observed before the erroneous stop:

- accepted intervals: 2,144,194;
- stop time: about 274.012125 d;
- failure emitted by runner: `Z31_PHYSICAL_GATE_FAILURE`;
- actual trigger: retained Z30 A/B comparison gate, not a frozen Z31 physical blocker;
- max adaptive per-interval ledger: about 1.24e-9 cm, far inside the Z31 hard physical ledger gate;
- ownership sequence remained matched through stop;
- deterministic adaptive/full work ratio: about 0.7599.

Partial signed-drift evidence:

### Tail 12:16 / n=12

- interval count: 1,934,939;
- signed cumulative contribution: about +3.48e-13 cm;
- mean signed interval difference: about +1.80e-19 cm;
- RMS: about 1.03e-15 cm;
- positive and negative differences both abundant.

This regime is effectively machine-precision neutral.

### Tail 13:16 / n=13

- interval count before stop: 209,255;
- signed cumulative contribution: about -1.09586e-6 cm;
- mean signed interval difference: about -5.24e-12 cm;
- RMS: about 7.82e-11 cm.

Thus essentially all observed HEAD drift begins only after entry into the 13:16 regime.

### Chatter/event intervals

Seven first-family ownership-change intervals contribute only about -2.64e-15 cm total.

The observed drift is therefore not attributable to the chatter event itself.

## RUNOFF execution

RUNOFF ran much farther before the second retained Z30 stop condition fired:

- accepted intervals: 5,993,730;
- stop time: 514.608125 d;
- runner failure: `DRIVING_ADAPTIVE_EVENT_SEQUENCE_DIVERGENCE`;
- full tail immediately before stop: 13:16;
- adaptive candidate retreated to 14:16 one nominal interval before the full reference;
- deterministic adaptive/full work ratio: about 0.7920.

This same-step mismatch was not a frozen Z31 stop condition; Z31 was supposed to continue and attribute drift.

Partial signed-drift evidence again localizes to the 13:16 regime.

### Tail 12:16 / n=12

- 1,934,888 intervals;
- total signed drift: about -3.38e-13 cm;
- mean: about -1.75e-19 cm;
- RMS: about 9.87e-16 cm.

Again effectively neutral.

### Tail 13:16 / n=13

- 4,058,842 intervals;
- total signed drift: about -1.13703e-6 cm;
- mean: about -2.80e-13 cm;
- RMS: about 4.60e-10 cm.

Nearly all observed long-horizon drift is associated with the 13:16 / n=13 regime.

### First chatter family

The first seven ownership-change intervals contribute only roundoff-scale signed mass difference.

### Later 13:16 -> 14:16 transition

At 514.608125 d the adaptive trajectory retreats one nominal interval before the full reference.

The adaptive event-step signed mass difference is about -7.40e-10 cm.

This is informative but not sufficient to classify the full Z31 drift mechanism because the protocol incorrectly terminated at that point.

## Strong partial inference

Although Z31 itself is not qualified, both independent fixtures show the same robust pattern before protocol termination:

1. tail 12:16 / n=12 is essentially drift-neutral at machine precision;
2. the first chatter family contributes negligible signed mass difference;
3. practically all measurable cumulative drift starts after stable entry into tail 13:16 / n=13;
4. both positive and negative per-step differences remain present;
5. the drift is not a simple monotone per-step sign bias;
6. RUNOFF suggests the accumulated state difference can shift the later 13:16 -> 14:16 event by approximately one nominal interval.

This is a strong hypothesis for the protocol-correct re-execution, not a frozen Z31 classification.

## Consequence

Open a separately preregistered repair/re-execution workunit.

It must preserve the Z31 physics and diagnostics but enforce the actual Z31 stop contract:

continue through 540 d unless one of the explicitly preregistered physical blockers occurs.

In particular it must **not** stop on:

- h/theta A/B comparison envelopes;
- cumulative adaptive/full mass difference;
- same-nominal-step event timing differences.

Event timing differences must be recorded and matched as ordered event families rather than used as immediate stop conditions.

## Production boundary

Research only.

No production source/default change.

`LEGACY_NUMERICS` remains production default.
