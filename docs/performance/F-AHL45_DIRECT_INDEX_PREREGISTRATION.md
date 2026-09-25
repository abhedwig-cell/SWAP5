# F-AHL45 — derivative-consistent direct-index representation screen

Date: 2026-09-25

Status: `PREREGISTERED_SCREEN`

Parent: F-AHL44 current-postimage performance requalification.

## Motivation

F-AHL44 retained policy-4 fidelity but falsified its current speed proposition:

- current analytical theta-only demand is faster than adaptive theta-only demand;
- shared-registry and provider-local irregular lookup both remain slower;
- current prescribed-head B01 Richards timing is negative for policy 4.

Source inspection identifies interval location as one avoidable architectural cost: the irregular adaptive representation requires a binary search for each sample.

## Hypothesis

A uniform grid in `x = log10(-h)` can retain the same derivative-consistent representation family while replacing interval search by direct index calculation.

The screen keeps the core scientific design:

- interpolate `z = logit(Se)`;
- cubic Hermite interpolation;
- derive theta from the interpolated z;
- derive C from the derivative of the same interpolant;
- no independent C table.

Only interval location and grid layout change.

## Screen

Material: B01.

Domain: `-1 >= h >= -1e6 cm`.

Candidate node counts:

- 257;
- 513;
- 1025;
- 2049.

For each candidate measure:

- max absolute theta error over a dense log-h sweep;
- max relative C error where analytical C >= 1e-13;
- theta-only runtime for a 60-node vector at h=-75 cm;
- ratio versus current analytical theta-only demand.

Build cost is outside the timed loop.

## Decision rule

A direct-index candidate is worth further F-AHL work only if one tested grid simultaneously:

1. preserves derivative consistency by construction;
2. max abs theta error <= 1e-6;
3. max relative C error <= 1e-3 over the relevant C domain;
4. median/current-run theta-only runtime ratio < 0.9 versus analytical demand.

If no candidate clears both fidelity and speed, close this architecture without production implementation.

No production routing or solver change is authorized by this screen.
