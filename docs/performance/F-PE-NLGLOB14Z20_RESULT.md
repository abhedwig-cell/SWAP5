# F-PE-NLGLOB14Z20 result — bidirectional chatter lifetime characterization

Date: 2026-09-30

Status:

`QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`

Qualification authority:

- workflow run: `36703535514`;
- HEAD fine segment-B job: `109852835706`;
- RUNOFF fine segment-B job: `109852835519`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

The intervening canonical delta is ELASTIC61-only and does not alter the TIMEINT/NLGLOB dependency surface.

## Frozen question

Is the no-hysteresis bidirectional ownership chatter observed in Z19 a finite transient, or does it recur/persist over a materially longer accepted-state window?

## Coverage

PASS.

Both frozen fine O05 fixtures:

- reproduce the accepted `12:16 -> 13:16` endpoint;
- reproduce and accept the exact reverse `13:16 -> 12:16`;
- preserve exact state-derived bidirectional ownership semantics;
- complete exactly 4096 nominal accepted observation intervals;
- remain finite, contiguous, mass-clean and provider-valid.

Both classify:

`FINITE_TRANSIENT_CHATTER`.

Aggregate classification:

`QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`.

## HEAD fine

The ownership sequence after the committed reverse event contains exactly five changes:

1. retreat at offset 1;
2. reverse at offset 2;
3. retreat at offset 3;
4. reverse at offset 4;
5. retreat at offset 5.

Then ownership remains stable through offset 4096.

Diagnostics:

- last ownership-change offset: 5;
- longest alternating burst: 5;
- ownership change after offset 64: false;
- after offset 512: false;
- after offset 2048: false;
- final accepted tail: `13:16`;
- accepted observation intervals: 4096.

## RUNOFF fine

The same lifetime pattern is reproduced:

- exactly five ownership changes;
- alternating directions over offsets 1..5;
- last ownership change at offset 5;
- no ownership change after offset 64;
- no ownership change after offset 512;
- no ownership change after offset 2048;
- final accepted tail: `13:16`;
- accepted observation intervals: 4096.

## State, mass and transaction quality

Across both fixtures:

- no hard coupling failure;
- no nonfinite state;
- no noncontiguous accepted geometry;
- no skipped ownership face;
- provider route remains `surface-flux`;
- rollback difference: 0.

Inherited long-trajectory maxima remain inside the frozen gates:

- max interval physical mass ledger about `1.62e-9 cm`;
- max nonlinear residual about `1.00e-10`;
- max rollback 0.

The committed reverse-event solves themselves remain extremely clean, with residuals and mass ledgers near machine precision.

## Scientific interpretation

The Z19 chatter is real but not persistent.

Under unchanged exact accepted-state bidirectional ownership semantics, both fine fixtures exhibit the same five-step alternating transient and then self-settle at accepted tail:

`13:16`.

No later ownership recurrence is observed over 4096 nominal accepted intervals.

This changes the anti-chatter question materially.

There is no evidence here that a hysteresis threshold or dwell-time rule is required for local physical correctness.

Any future anti-chatter mechanism should therefore be justified by:

- numerical cost;
- interface-event cleanliness;
- coupling robustness;
- or production architecture,

not by an assumption that the no-hysteresis semantics remain indefinitely unstable.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`.

Established locally:

- bidirectional exact-state ownership is transactionally valid;
- its immediate chatter burst is deterministic and finite in both fine fixtures;
- it self-settles without threshold tuning or hysteresis.

Not qualified:

- long-horizon bidirectional persistence to the next physical retreat;
- four-fixture split authority through `13:16 -> 14:16`;
- production acceptance of transient chatter;
- event coalescing;
- hysteresis/dwell semantics;
- disappearance;
- whole-column TG re-entry.

## Consequence

The next safe research step is long-horizon bidirectional persistence under the unchanged exact-state policy.

It should determine whether the self-settled split trajectory can continue from accepted `13:16` to independently qualified physical retreat:

`13:16 -> 14:16`

without late recurrent chatter, geometry inconsistency, mass loss or ownership ambiguity.

Do not introduce an anti-chatter state machine before that characterization.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
