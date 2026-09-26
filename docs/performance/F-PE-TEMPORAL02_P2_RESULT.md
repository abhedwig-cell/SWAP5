# F-PE-TEMPORAL02 P2 result — completing-policy runtime screen

Date: 2026-09-26

Status: `RUNTIME_SIGNAL_WITH_ONE_UNEXPLAINED_BATCH_OUTLIER`

## Protocol

The two common completing P0 candidates were timed:

- 5e-4 cm;
- 1e-3 cm.

For each of 12 difficult signed points:

- one initialized process per arm;
- 5 warm-up same-origin trials;
- 50 measured trials;
- trial call only timed;
- candidate discarded after each trial;
- every measured trial required to complete.

## Result

All measured trials completed.

Median 5e-4 / 1e-3 runtime ratio across the 12 points:

`1.01357`

Range:

- minimum 0.99463;
- maximum 2.34425.

### Expected policy-driven signal

O14-wet remains the controlling difference.

P0 showed that 5e-4 still requires one temporal retry for O14-wet +/-0.001 cm, while 1e-3 accepts the first full-window attempt.

Measured ratios:

- O14-wet -0.001 cm: 2.30118;
- O14-wet +0.001 cm: 2.34425.

This is consistent with the known extra transaction work.

### Unexplained timing outlier

B12-wet +0.001 cm produced ratio 1.83135 despite:

- identical q;
- P0 showing direct first-attempt acceptance at both 5e-4 and 1e-3;
- no known policy-path difference.

This single-batch contrast is therefore not accepted as a policy runtime effect without paired replication.

Most other direct/direct points lie close to unity.

## Interpretation

The mechanistic performance conclusion is already clear for O14-wet:

- 1e-3 avoids a remaining temporal retry;
- 5e-4 pays roughly a factor-two trial cost there.

The global timing ratio cannot yet be used quantitatively because the B12 batch demonstrates that one non-interleaved 50-sample batch can carry substantial machine/runtime noise.

## Decision

Advance to P2R paired/interleaved timing.

P2R must alternate 5e-4 and 1e-3 measurements across repeated fresh batches and separately report:

- direct/direct points;
- the O14-wet retry/direct points.

No production policy choice is made from P2 alone.
