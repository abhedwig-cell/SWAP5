# F-PE-NLGLOB14Y result — split ownership across third and fourth retreats

Date: 2026-09-29

Status:

`QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`

Qualification authority:

- workflow run: `36606241010`;
- job: `109535867357`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

## Frozen question

Can the accepted split-domain trajectory independently follow the two additional physical lower-edge retreats exposed by NLGLOB14X and move ownership sequentially:

- face 4/5 -> 5/6;
- face 5/6 -> 6/7;

using only its own accepted saturated state?

## Coverage

PASS.

All 8 HEAD/RUNOFF x four-dt fixtures classify:

`SPLIT_MULTI_RETREAT_SEQUENCE_VALID`.

Aggregate classification:

`QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`.

Across the bank:

- accepted split intervals: 93,117;
- process failures: 0;
- rejected intervals: 0;
- ownership changes: 24 total, exactly 3 per fixture including the previously qualified second retreat;
- chatter cases: 0;
- reverse cases after second retreat: 0;
- skipped ownership nodes: 0;
- noncontiguous accepted lower saturated states: 0.

## Accepted ownership sequence

Every fixture independently produces the physical accepted sequence:

`4:16 -> 5:16 -> 6:16 -> 7:16`.

The corresponding temporal-ownership faces move:

`3/4 -> 4/5 -> 5/6 -> 6/7`.

No control time is supplied to the split solver.

Each move follows only after the split trajectory's own accepted physical state changes the contiguous saturated tail.

## Third retreat comparison

Control exposes `5:16 -> 6:16` near 0.247-0.251 d.

Split event differences relative to control:

HEAD:

- dt 2.5e-4 d: +1 dt;
- dt 1.25e-4 d: +1 dt;
- dt 6.25e-5 d: +1 dt;
- dt 3.125e-5 d: +1 dt.

RUNOFF:

- dt 2.5e-4 d: +1 dt;
- dt 1.25e-4 d: +1 dt;
- dt 6.25e-5 d: exact;
- dt 3.125e-5 d: exact.

Event-time agreement is diagnostic, not an identity gate.

## Fourth retreat comparison

Control exposes `6:16 -> 7:16` near 0.728-0.731 d.

Split event differences:

HEAD:

- dt 2.5e-4 d: +1 dt;
- dt 1.25e-4 d: +1 dt;
- dt 6.25e-5 d: +1 dt;
- dt 3.125e-5 d: +2 dt.

RUNOFF:

- dt 2.5e-4 d: +2 dt;
- dt 1.25e-4 d: +2 dt;
- dt 6.25e-5 d: +1 dt;
- dt 3.125e-5 d: +1 dt.

The split transition remains close to the independent control while retaining its own state-derived event timing.

## Conservation and transaction behavior

All 93,117 accepted split intervals remain within the preregistered conservation and transaction gates.

Observed maxima:

- absolute interval physical mass ledger: about `9.95e-10 cm`;
- node-equation residual: about `9.95e-11`;
- rollback difference: 0.

No residual redistribution, independent interface exchange or fitted interface head is used.

## Dynamic-top behavior

All accepted intervals remain on the reconstructed dry unponded B110 `surface-flux` route.

The split sequence does not replay the persistent-KLAG top-flux sequence.

## Trajectory comparison

Matched split/control head and theta differences remain finite.

Over the long 0.80 d horizon, coarse-dt head differences reach several tenths of a centimetre, but decrease strongly with refinement.

This is expected accumulated temporal-discretization difference and is supporting evidence only. NLGLOB14Y does not claim a separate global temporal-order result.

## Scientific interpretation

NLGLOB14Y materially strengthens the moving-interface result.

The split ownership rule now survives repeated accepted retreat events over a long sequence rather than a single boundary change.

The physical state alone drives:

`3/4 -> 4/5 -> 5/6 -> 6/7`

without:

- whole-column TG release while a saturated block remains;
- empirical h/theta thresholds;
- fitted event times;
- hysteresis;
- interface-flux duplication;
- lower-block freezing;
- residual redistribution;
- tolerance tuning.

This establishes a reproducible research mechanism for multi-retreat moving-interface temporal ownership.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`.

Not yet qualified:

- complete saturated-block disappearance;
- final transition to an empty saturated set;
- whole-column TG re-entry after disappearance;
- production temporal-ownership implementation.

The independent control still has nodes 7:16 saturated at 0.80 d, so disappearance cannot be inferred.

## Production boundary

Research only.

No production `src/**` change.

No production temporal-ownership policy or numerical default changed.

`LEGACY_NUMERICS` remains production default.
