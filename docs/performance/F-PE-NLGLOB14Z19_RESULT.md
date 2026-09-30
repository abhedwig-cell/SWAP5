# F-PE-NLGLOB14Z19 result — bidirectional accepted-state ownership reclassification

Date: 2026-09-30

Status:

`NLGLOB14Z19_BIDIRECTIONAL_CHATTER`

Qualification authority:

- workflow run: `36700631559`;
- HEAD fine segment-B job: `109843509562`;
- RUNOFF fine segment-B job: `109843509514`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Frozen question

Can the exact clean reverse candidate after accepted:

`12:16 -> 13:16`

be committed by explicit accepted-state ownership reclassification:

`13:16 -> 12:16`

with ownership:

`face 12/13 -> face 11/12`

and remain stable over 64 nominal intervals without hysteresis?

## Coverage

PASS.

Both fine O05 fixtures:

- reproduce the accepted event endpoint;
- reproduce the exact reverse candidate;
- satisfy solve, mass, residual, rollback and provider gates;
- commit the reverse candidate by explicit state-derived ownership reclassification;
- complete all 64 post-reclassification accepted observation intervals.

## Reverse candidate quality

HEAD fine:

- reverse solve nonlinear iterations: 2;
- reverse residual: about `1.63e-15`;
- reverse interval ledger: about `5.99e-16 cm`;
- rollback difference: 0;
- reverse accepted tail: `12:16`;
- top route: `surface-flux`.

RUNOFF fine:

- reverse solve nonlinear iterations: 2;
- reverse residual: about `5.48e-16`;
- reverse interval ledger: about `1.03e-15 cm`;
- rollback difference: 0;
- reverse accepted tail: `12:16`;
- top route: `surface-flux`.

Thus the reverse event itself is numerically and transactionally admissible.

## Frozen 64-interval response

Both fixtures classify:

`IMMEDIATE_BIDIRECTIONAL_CHATTER`.

Aggregate classification:

`NLGLOB14Z19_BIDIRECTIONAL_CHATTER`.

### HEAD fine

Accepted ownership changes immediately after the reverse event:

1. retreat `12:16 -> 13:16`;
2. reverse `13:16 -> 12:16`;
3. retreat `12:16 -> 13:16`;
4. reverse `13:16 -> 12:16`;
5. retreat `12:16 -> 13:16`.

Five ownership changes occur in the first few nominal intervals.

Final tail after the 64-interval observation window:

`13:16`.

### RUNOFF fine

The same qualitative sequence is observed:

1. retreat;
2. reverse;
3. retreat;
4. reverse;
5. retreat.

Again, five ownership changes occur almost immediately.

Final tail after 64 intervals:

`13:16`.

## State, mass and transaction quality

Across both fixtures:

- 64 accepted observation intervals completed;
- no hard coupling failure;
- no nonfinite state;
- no noncontiguous accepted geometry;
- no skipped ownership face;
- rollback difference 0;
- provider-faithful `surface-flux`;
- physical mass and nonlinear residual remain inside the frozen gates.

Observed global maxima remain bounded by the inherited long-trajectory maxima:

- max interval ledger about `1.62e-9 cm`;
- max residual about `1.00e-10`;
- max rollback 0.

## Scientific interpretation

The retreat-only ownership semantics are insufficient after accepted tail `13:16`, but unrestricted exact bidirectional state reclassification is also insufficient.

The clean reverse candidate is physically and numerically admissible, yet immediate no-hysteresis accepted-state switching produces deterministic ownership chatter across:

`face 11/12 <-> face 12/13`.

Therefore the next research question is not whether bidirectional ownership is needed; it is.

The next question is what stateful anti-chatter semantics can preserve physical bidirectionality without creating rapid ownership oscillation.

## Qualified claim boundary

Established:

- exact reverse `13:16 -> 12:16` can be solved and committed transaction-safely;
- no-hysteresis bidirectional ownership produces immediate chatter in both fine fixtures.

Frozen aggregate result:

`NLGLOB14Z19_BIDIRECTIONAL_CHATTER`.

Not qualified:

- any hysteresis threshold;
- dwell-time policy;
- delayed ownership switching;
- filtered interface motion;
- persistence of split evolution beyond the chatter phase;
- later retreat `13:16 -> 14:16` under bidirectional ownership;
- disappearance;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

Open a separately preregistered anti-chatter semantics study.

The first successor should compare conceptually minimal, state-based mechanisms without fitting to control event times, such as:

- accepted-state dwell requirement;
- direction-change confirmation across more than one accepted interval;
- event-state memory tied to the previously committed ownership state.

Do not tune a pressure or theta threshold around zero.

Any anti-chatter mechanism must preserve:

- exact accepted physical state;
- bidirectional capability;
- transaction semantics;
- mass;
- provider authority;
- one interface authority.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
