# F-PE-NLGLOB14Z20 closeout — finite transient bidirectional chatter

Date: 2026-09-30

Final status:

`QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`

Qualification authority:

- run `36703535514`;
- HEAD fine segment-B job `109852835706`;
- RUNOFF fine segment-B job `109852835519`.

## Closure

Z20 closes positively as a characterization result.

Both fine fixtures reproduce the Z19 five-change alternating ownership burst and then remain stable for the rest of a 4096-interval accepted-state observation.

For both:

- ownership changes only at offsets 1..5;
- no change occurs after offset 64;
- no change occurs after offset 512;
- no change occurs after offset 2048;
- final accepted tail is `13:16`;
- state, mass, residual, rollback and provider gates remain valid.

## Mechanistic conclusion

No-hysteresis bidirectional ownership does chatter immediately after the event, but the chatter is a finite local transient rather than persistent or late-recurrent behavior in the tested fixtures.

## Direct successor

Do not introduce fitted hysteresis yet.

First test long-horizon bidirectional persistence from the self-settled `13:16` state to the independently established control retreat:

`13:16 -> 14:16`.

The successor should preserve exact state-derived bidirectional ownership and characterize any later recurrence.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z20

BRANCH: `research/f-pe-nlglob14z20-chatter-lifetime`

QUALIFICATION RUN: `36703535514`

QUALIFICATION STATUS: `QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`

NEXT SAFE STEP: long-horizon bidirectional persistence to `13:16 -> 14:16`.

## Production boundary

No production source/default change.
