# F-PE-TEMPORAL02 P2R — paired/interleaved runtime replication

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Trigger

P2 found the expected ~2.3x cost for O14-wet at 5e-4 because that arm still retries, but also one unexplained B12 direct/direct batch outlier (~1.83x).

## Purpose

Separate policy-driven runtime cost from batch/machine noise.

## Protocol

For each of the 12 signed difficult points:

- compare 5e-4 and 1e-3 cm;
- initialize once per batch;
- 5 warm-up trials per arm;
- 30 measured trials per arm;
- alternate arm order between batches;
- run 7 independent batches;
- time only the participant trial call;
- discard every candidate;
- require every trial to succeed.

Report the median of paired batch ratios for each point and classify points using the already measured P0 path:

- DIRECT/DIRECT: both arms accept first attempt;
- RETRY/DIRECT: 5e-4 retries while 1e-3 accepts first attempt.

## Decision

Treat a runtime difference as policy-driven only when it is reproducible across paired batches and consistent with the transaction-path difference.

No production source change is allowed.