# F-PE-TEMPORAL02 P3B — signed frontier replication

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Trigger

P3A mapped the signed displacement × temporal-budget surface. After correcting a summary bug that had merged positive and negative offsets before thresholding, the common completing frontier is:

- |dh| = 0.001 cm: 5e-4 cm;
- |dh| = 0.01 cm: 5e-3 cm;
- |dh| = 0.05 cm: 5e-2 cm;
- |dh| = 0.10 cm: 5e-2 cm;
- |dh| = 0.25 cm: no common completing budget through 5e-2 cm.

## Purpose

Replicate the signed frontier and the immediately stricter tested budget to verify that the coarse P3A boundary is deterministic.

## Matrix

For each of the six difficult origins and both signs:

- |dh| 0.001 cm: budgets 2e-4 and 5e-4 cm;
- |dh| 0.01 cm: budgets 2e-3 and 5e-3 cm;
- |dh| 0.05 cm: budgets 2e-2 and 5e-2 cm;
- |dh| 0.10 cm: budgets 2e-2 and 5e-2 cm;
- |dh| 0.25 cm: budget 5e-2 cm as the tested upper-bound failure check.

Three fresh processes per point.

## Measurements

- completion status;
- ordered retry pattern;
- temporal and solver rejection counts;
- q for successful trials.

## Decision

Confirm a common frontier only when every signed point at that displacement is deterministic across all three repetitions.

For |dh| = 0.25 cm, confirm only that no common frontier exists within the tested budget ceiling; do not extrapolate beyond 5e-2 cm.

No production source change is allowed.