# F-PE-NLGLOB14Z16 preregistration — event-terminated split confirmation 12:16 -> 13:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z14C restores four-fixture control authority for exact accepted `12:16 -> 13:16`;
- NLGLOB14Z15 preserves four-fixture split event evidence for exact accepted `12:16 -> 13:16`;
- in Z15 both coarse split fixtures complete 280 d;
- both fine split fixtures accept the target event and ownership move, then fail only on the immediately following upper-domain validity gate;
- accepted target-event state, mass, residual and rollback remain valid.

## Purpose

Qualify the target split ownership transition itself without conflating it with unrelated post-event continuation.

The scientific endpoint of Z16 is the first exact accepted split transition:

`12:16 -> 13:16`

with ownership:

`face 11/12 -> face 12/13`.

Z16 terminates each fixture immediately after that accepted event.

## Frozen fixtures

Use O05:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged split-domain formulation;
- provider-faithful dry top;
- control event time only as diagnostic comparator.

## Execution partition

Use the same exact accepted-state checkpoint transport as Z15:

1. segment A: origin -> 140.0 d;
2. bit-exact accepted-state checkpoint;
3. segment B: resume from 140.0 d;
4. stop immediately after the first accepted `12:16 -> 13:16` transition;
5. maximum allowed segment-B search horizon = 262.0 d.

No interval after the accepted target event is attempted.

The 262 d cap is an execution bound only and does not define event timing.

## Checkpoint gates

Require per fixture:

- h roundtrip bit-exact;
- theta roundtrip bit-exact;
- checkpoint saturated tail exactly `12:16`;
- restored temporal ownership identical;
- no synthetic event at 140 d;
- segment B starts from exact segment-A accepted endpoint.

## Event authority

The event exists only when the split trajectory's own accepted physical state changes exactly:

`12:16 -> 13:16`.

Saturation is defined only by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

Ownership moves only from accepted split state.

No control time, fitted threshold, epsilon, predictor state, interpolation or hysteresis may trigger the event.

## Hard scientific gates

At the accepted event endpoint require:

- exact one-face ownership move `11/12 -> 12/13`;
- finite accepted state;
- contiguous accepted saturated tail;
- residual <= 1e-10;
- interval physical mass ledger <= 5e-8 cm;
- rollback difference = 0;
- zero chatter;
- zero reverse transitions;
- zero skipped faces;
- provider-faithful dry top.

## Frozen classifications

If all four fixtures reach and accept the exact target event before 262 d and all gates pass:

`QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`.

If a valid fixture does not reach the event by 262 d:

`NLGLOB14Z16_EVENT_NOT_REACHED`.

Any checkpoint continuity failure:

`NLGLOB14Z16_CHECKPOINT_CONTINUITY_INVALID`.

Any pre-event coupling/upper-domain failure:

`NLGLOB14Z16_PRE_EVENT_NOT_CLOSED`.

Any chatter/reverse/skipped/noncontiguous state:

`NLGLOB14Z16_EVENT_STATE_INCONSISTENT`.

Any mass/transaction inconsistency:

`NLGLOB14Z16_TRANSACTION_INCONSISTENT`.

## Explicit boundary

Z16 does not test or claim:

- persistence of split evolution after accepted `13:16`;
- repair of the Z15 post-event `UPPER` boundary;
- later retreats beyond `13:16`;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

Positive Z16 qualifies split ownership through accepted tail `13:16`.

Only after that qualification may the line return to independent control exposure beyond `13:16`.

## Production boundary

Research only. No production source/default change.
