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

## Stage-A frozen outcome

Exact-only run 37032036237 identifies O05 with forcing variant 3 as the executable dynamic threshold fixture in both geometry variants. Each completes 24 days with mass residual below 1e-10 cm and repeatedly occupies both the < -30 cm and [-30,-3) cm bands. With cycle-boundary sampling the transition counter is 19 across 20 cycles because the first sampled state has no preceding sample; this satisfies the intended repeated-crossing requirement without changing forcing.

No executable Stage-A candidate visits the >= -3 cm band. Do not intensify forcing merely to manufacture that occupancy. The >= -3 cm 16-panel branch remains covered by the 36-material constitutive Q2 frontier; Q4B dynamic qualification is frozen to the observed -30 cm 64/32 transition.

Stage B is now allowed only for O05, forcing variant 3, geometry 1 and 2, with the exact forcing and initial state unchanged.
