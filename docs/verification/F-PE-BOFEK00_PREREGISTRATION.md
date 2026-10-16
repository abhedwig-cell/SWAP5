# F-PE-BOFEK00 — wet-regime numerical authority preregistration

Date: 2026-09-28

Status: **PREREGISTERED / NO PRODUCTION MUTATION YET**

Canonical preimage: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

## Question

Does the current Reference/canonical wet top-boundary route still contain either historical defect recovered in F-AR01:

1. an incomplete first-row Jacobian when ponding/runoff makes the surface head depend on the top-node pressure head;
2. timestep-dependent branch selection before the already analytical linear-runoff solution.

Correctness is evaluated before any timestep-policy change.

## Frozen source surfaces

Current production surfaces under test:

- `src/legacy/b1_10_port/headcalc.f90`
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90`
- `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90`

Historical authority:

- PR #161;
- `docs/verification/F-AR01_LEGACY_ZIP_RECONCILIATION.md`;
- package identity `SWAP_4.3.1_ponding_jacobian_patch_for_Marius.zip`, SHA-256 `e0403c4387742cc9a6819729d80b09ba3175579cedf3ae8ed47030cedc930d07`;
- historical core-patch SHA-256 `101cd0edd9e22f494582b5536cd82ccd849d2f881c20cda3cf224f2a63e4e1ee`.

The ZIP payload itself is not materialized in current repository authority. Therefore no byte-for-byte historical patch replay is claimed in this work unit unless that payload is recovered later.

## BOFEK00C — Jacobian correctness hypothesis

On a fixed smooth head-boundary branch, the top residual contribution is

```
R_top,boundary = -Kf * ((Hs(h1)-h1)/d + 1)
```

with fixed face conductivity `Kf` for the explicit-conductivity route.

Therefore

```
dR/dh1 = Kf/d * (1 - dHs/dh1).
```

For ponding without active linear runoff, current provider algebra gives

```
p1 = Kf/d * dt
Hs = (P_prev + q0*dt - Kf*dt + p1*h1)/(1+p1)
dHs/dh1 = p1/(1+p1)
dR/dh1 = (Kf/d)/(1+p1).
```

For active linear runoff with resistance `Rr` and exponent 1,

```
a = dt/Rr
Hs = (P_prev + q0*dt - Kf*dt + p1*h1 + a*Pmax)/(1+p1+a)
dHs/dh1 = p1/(1+p1+a)
dR/dh1 = Kf/d * (1+a)/(1+p1+a).
```

The current `headcalc` first-row head-boundary term adds `Kf/d`, equivalent to assuming `dHs/dh1=0`.

### Independent check

A central finite difference of the residual, with route frozen away from switches, is the primary oracle. The analytic expressions above are secondary checks.

Acceptance:

- central-FD and derived corrected derivative: relative error <= `1e-7`;
- current Jacobian term and FD: if relative error > `1e-4` on a smooth branch, classify `BUG/CORRECTNESS`;
- no timestep controller participates in this gate.

## BOFEK00D — branch-selection hypothesis

Current dynamic-top code computes `h0max`, then when `h0max > ponding_max` evaluates a runoff depth from the *incoming Newton candidate ponding* and uses the absolute runoff-depth threshold `1e-6 cm` to decide whether to enter the analytical linear-runoff solution.

For exponent 1 and finite resistance,

```
runoff_depth(candidate) = dt/Rr * (candidate_ponding - Pmax).
```

Thus two mathematically equivalent candidate states can cross the branch gate solely because `dt` changes. This is a numerical route-selection dependence, not a timestep-controller policy.

Acceptance:

- demonstrate identical physical parameters and candidate ponding excess selecting different branches for two `dt` values solely through the absolute runoff-depth gate;
- separately show the analytical active-runoff solution is defined for both cases;
- classify this as `BUG/CORRECTNESS` if confirmed;
- do not modify DTMIN, DTMAX, NUMBIT_CRIT, FACT_DT_INCREASE, FACT_DT_DECREASE or tolerance policy.

## Frozen-timestep and adaptive-timestep gates

A production correction is not admission-ready from this micro-gate alone.

Before admission:

1. run old and corrected solver with an identical imposed timestep sequence and retain pressure-head, ponding, runoff, drainage, mass balance, Newton iterations, backtracks and residuals;
2. only then rerun with the existing automatic timestep controller unchanged;
3. any new timestep policy is a separate `NUMERICAL_POLICY` decision surface.

## Classification rule

- `HISTORICAL_DEFECT_NO_LONGER_PRESENT` only if both mechanisms are absent from current authority.
- `DEFECT_CONFIRMED_CURRENT_REFERENCE` if either mechanism is reproduced on current authority.
- `HISTORICAL_FINDING_NOT_REPRODUCIBLE` only after a current-authority gate contradicts the historical finding.
- `BLOCKED` only for a real missing authority/runtime asset that prevents the requested qualification stage.
