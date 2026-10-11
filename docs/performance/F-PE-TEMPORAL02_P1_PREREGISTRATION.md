# F-PE-TEMPORAL02 P1 — accepted-path state and response divergence

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Trigger

P0 found a sharp completion frontier:

- 2e-4 cm: 8/12 complete;
- 5e-4 cm: 12/12 complete, with two remaining temporal retries and zero solver rejections;
- 1e-3 cm: 12/12 complete directly, with zero temporal and solver rejections.

## Purpose

Measure how much the accepted transaction path itself changes state and exchange across the P0 frontier.

This phase does not claim temporal accuracy. The 1e-3 arm is a full-window physical-reference arm because P0 shows it accepts the first converged 1e-4 day physical solve for all 12 points. It is not a refined temporal oracle.

## Arms

- 2e-4 cm;
- 5e-4 cm;
- 1e-3 cm, labeled FULL_STEP_REFERENCE.

Use the same six difficult origins and +/-0.001 cm offsets.

For each successful trial, in a fresh process:

1. record q and bottom exchange;
2. commit the participant candidate;
3. snapshot terminal pressure head and water content;
4. compare 2e-4 and 5e-4 results with the 1e-3 FULL_STEP_REFERENCE for the same point.

## Metrics

- max absolute terminal head difference;
- max absolute terminal water-content difference;
- absolute and relative q difference;
- absolute bottom-exchange difference;
- transaction completion/pass set;
- ordered retry pattern.

Use three repetitions to establish deterministic state/output signatures.

## Interpretation

If 5e-4 and 1e-3 are effectively identical for all points, P0 completion can be obtained without materially changing the accepted physical trajectory at this window.

If they differ, preserve the difference and quantify it before any temporal-policy recommendation.

The comparison to 1e-3 is a path-sensitivity screen only. A separate refined temporal oracle remains required for physical accuracy qualification.

No production `src/**` change is allowed.
