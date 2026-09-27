# F-PE-TANGENT01 P0 result

Date: 2026-09-26

Status: `CLOSED_H2_PATH_CONSISTENT_DISCRETIZATION_DEPENDENT`

Preregistration:

`docs/performance/F-PE-TANGENT01_PREREGISTRATION.md`

Execution harness:

`tests/fpe/run_fpe_tangent01_p0.sh`

## Question

TEMPORAL06 showed that the fresh accepted-trajectory tangents for c=0.50 and c=0.65 differed from a fine N=64 Reference finite-difference q(h) derivative by about 6.85% and 12.31%, respectively.

TANGENT01 tested whether that meant:

- H1: a defect in accepted-step directional composition; or
- H2: a correct derivative of the actual accepted numerical trajectory whose dq/dh is itself temporal-discretization dependent.

## Matrix

Primary discriminator:

- O14;
- mid regime, h0 = -75 cm;
- accepted history imbalance -0.10 and +0.10;
- corrector offsets -0.01, -0.001, +0.001 and +0.01 cm;
- policies c=0.50 and c=0.65;
- tangent cache disabled.

For each policy/head pair, q(h) was independently evaluated at h-epsilon and h+epsilon from the same captured origin.

Epsilon ladder:

- 1.0e-4 cm;
- 2.5e-4 cm;
- 5.0e-4 cm;
- 1.0e-3 cm.

Primary epsilon:

- 2.5e-4 cm.

A separate fixed-substep Reference derivative ladder used:

- N=1, 2, 4, 8, 16, 32 and 64.

## Same-policy finite-difference result

All 16 policy/origin/head combinations passed the smooth-path gate.

No perturbation changed:

- completion;
- solver rejection count;
- retry count;
- accepted-substep count.

All primary local finite-difference derivatives were stable across the 1.0e-4, 2.5e-4 and 5.0e-4 cm epsilon support.

### c=0.50

At all eight points:

- retries = 1;
- accepted substeps = 2;
- published tangent matches the same-policy finite-difference q(h) derivative.

Maximum relative tangent error:

`3.33516171534724854e-09`

Classification:

`DIRECTIONAL_MATCH: 8/8`

### c=0.65

At all eight points:

- retries = 0;
- accepted substeps = 1;
- published tangent matches the same-policy finite-difference q(h) derivative.

Maximum relative tangent error:

`2.77586644025655597e-09`

Classification:

`DIRECTIONAL_MATCH: 8/8`

These errors are many orders of magnitude below the preregistered 1% correctness bound.

## Fixed-substep alignment

The fixed-substep Reference ladder independently localizes the temporal dependence.

For every tested point:

- c=0.65 published tangent matches the N=1 Reference derivative to about 1e-9 relative;
- c=0.50 published tangent matches the N=2 Reference derivative to about 1e-9 relative.

Maximum relative alignment errors:

- c=0.50 versus N=2: `3.33516171534724854e-09`;
- c=0.65 versus N=1: `2.77586644025655597e-09`.

Example, O14 mid, history -0.10, offset -0.01 cm:

- N=1:  -1.34490093958609097e-05 1/s;
- N=2:  -1.42866238900871908e-05 1/s;
- N=4:  -1.47910118823661351e-05 1/s;
- N=8:  -1.50718528706896601e-05 1/s;
- N=16: -1.52207432871472870e-05 1/s;
- N=32: -1.52975075508173124e-05 1/s;
- N=64: -1.53364979152549152e-05 1/s.

Thus dq/dh converges materially as the temporal trajectory is refined.

## Hypothesis decision

H1 is rejected.

There is no evidence of a defect in accepted-step directional composition on the tested O14-mid envelope.

H2 is supported:

`H2_PATH_CONSISTENT_DISCRETIZATION_DEPENDENT`

The published tangent is the derivative of the numerical response map that the participant actually evaluates.

The TEMPORAL06 discrepancy against N=64 is therefore temporal-discretization error in dq/dh, not a tangent implementation error.

## Coupling-contract reconciliation

The canonical fixed-interface coupling contract states:

- corrector value = accepted-origin real-SWAP outward interface flux evaluated at prescribed interface head;
- corrector tangent = accepted-trajectory d(q_swap)/d(H_interface);
- MODFLOW relinearization uses that tangent in HCOF/RHS.

This directly matches the TANGENT01 same-policy authority.

Earlier F-GC30 qualification also established the relevant oracle principle: an analytic accepted-trajectory derivative is qualified against centered finite differences of the same admitted production candidate map, from the same immutable origin and coupling window.

Therefore a fine N=64 Reference derivative is useful as a temporal-refinement authority, but it is not the contractually intended Jacobian of a participant that actually returns an N=1 or N=2 accepted response map.

## Consequence for TEMPORAL06

The TEMPORAL06 1% direct c=0.50-versus-c=0.65 tangent overlap failure remains a valid observation.

The later N=64 comparison also remains a valid temporal-refinement measurement.

However, neither is evidence that the published c=0.65 tangent is internally wrong.

The tangent changes because the response map changes when the accepted temporal subdivision changes.

## Decision

No production tangent-source repair is justified.

Any decision to require a finer tangent than the actual accepted response map would be a change of coupling semantics, effectively introducing a response surrogate or mixed-fidelity Jacobian. That requires a separate, explicit workunit and cannot be called a repair of the current accepted-trajectory tangent.

P0 is closed with H2 supported.
