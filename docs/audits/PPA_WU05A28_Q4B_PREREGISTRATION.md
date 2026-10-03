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

## Stage-A amplitude-envelope finding

Three exact-only mode-3 ramps with the same 45 cm target but successively slower ramp rates fail B01 at:
- original ramp: step 485, t≈4.84 d, imposed amplitude≈22.875 cm;
- 2x ramp duration: step 726, t≈7.25 d, imposed amplitude≈22.734 cm;
- 4x ramp duration: step 1206, t≈12.05 d, imposed amplitude≈22.617 cm.

The near-invariant failure amplitude falsifies ramp rate as the primary cause. Further slowing is prohibited as uninformative tuning. Stage A must instead characterize the exact-RFM executable amplitude envelope and determine whether the required -30/-3 cm consumer-head crossings are reachable inside it.

## Stage-A envelope qualification refinement

A frozen 20 cm exact-only amplitude completes all four soil/geometry cases for the full 20-cycle measurement phase. Observed consumer-head occupancy is structurally separated:
- surface consumer: repeated -3 cm crossings, 40 per case; B01 range -24.75 to +3.05 cm, O05 -21.90 to +1.18 cm;
- endpoint consumers: remain >= -3 cm throughout the measurement phase;
- MB consumer: remains >= -3 cm throughout;
- no consumer crosses -30 cm in this wet mode-3 envelope.

Therefore one hydraulic fixture cannot be required to exercise both A28_V1 policy boundaries. Q4B is split without changing approximate results:
- Q4B-3: freeze this 20 cm exact fixture to qualify repeated 32-to-16 panel boundary crossing at -3 cm;
- Q4B-30: separately construct an exact-only drier initial/boundary fixture for repeated 64-to-32 crossing at -30 cm.

Approximate mode remains prohibited in Q4B-30 design. Q4B-3 may proceed to Stage B because its exact fixture is now frozen.
