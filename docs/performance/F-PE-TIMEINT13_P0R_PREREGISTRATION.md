# F-PE-TIMEINT13 P0R preregistration — independent common-domain replication

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_P0R_RESULTS`

Parent:

F-PE-TIMEINT13 P0.

## Trigger

P0 produced second-order behavior on all three complete refinement cases, at near-neutral work cost.

The fourth case, B01 with rain 1 cm/day, could not form the frozen refined order because both BDF2_KPRED and BE_KLAG fail at the finest preregistered dt = 0.000625 d.

P0 remains formally non-advancing.

P0R does not reuse the exposed dt values for its order decision.

## Case

Material:

B01.

Forcing:

1.0 cm/day fixed top flux.

Initial head:

-100 cm.

Horizon:

0.04 d.

## New frozen dt ladder

Use only previously unexposed values:

- 0.008 d;
- 0.004 d;
- 0.002 d;
- 0.001 d.

All exactly divide the 0.04 d horizon.

The refinement order is calculated from the three finest P0R values:

- 0.004;
- 0.002;
- 0.001 d.

## Methods

- BE_KLAG comparator;
- unchanged BDF2_KPRED candidate from P0.

No solver control, tolerance, storage formula or K predictor changes.

## Frozen advancement rule

P0R passes only if:

1. all four BDF2_KPRED trajectories complete;
2. all four BE_KLAG comparator trajectories complete;
3. BDF2_KPRED refined top-head order >= 1.70;
4. BDF2_KPRED deterministic work per step median <=1.15 times BE_KLAG;
5. no alternative solver calls;
6. all states remain finite.

If P0R passes, combine it with the three P0 complete cases to classify the smooth fixed-flux mechanism as:

`SMOOTH_KPRED_BDF2_MECHANISM_QUALIFIED`.

Only then may a separately preregistered dynamic-top P1 begin.

If P0R fails, close TIMEINT13 without dynamic-top exposure.

No production source change.
