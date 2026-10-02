# PPA-WU05-A28-Q4B preregistration — executable policy-threshold crossing

Date: 2026-10-02
Status: PREREGISTERED

## Motivation

Q4 H3 was intended to exercise repeated crossing of the A28_V1 pressure-head policy thresholds but is not an executable exact-RFM fixture for B01. It failed identically in exact and approximate arms at the first interval in both geometries. Further tuning inside Q4 is prohibited.

## Two-stage design

Stage A is exact-only fixture qualification. Construct a deterministic B01 and O05 trajectory that:
- completes under exact fixed-64 RFM;
- contains at least 20 cycles;
- records the actual pressure heads consumed by surface and wall sorptivity evaluation;
- demonstrates repeated occupancy on both sides of -30 cm and -3 cm where physically reachable;
- preserves mass residual <= 1e-6 cm.

The exact fixture is frozen once Stage A passes. Approximate mode is not run during Stage-A tuning.

Stage B then runs the frozen fixture with A28_V1 and compares against exact.

## Stage-B gates

- no approximate-only completion/admission failure;
- max mass residual <= 1e-6 cm;
- final and cycle-boundary storage difference <= 0.02 cm;
- max sampled theta difference <= 0.01;
- endpoint-water difference <= 0.02 cm;
- trusted reconstruction/replay and candidate-discard immutability pass;
- no forcing or initial-state retuning after approximate results are observed.

## Claim boundary

Q4B answers only the missing threshold-crossing long-history question. It does not add field validation, canonical admission, MultiSWAP scaling or MODFLOW coupling qualification.
