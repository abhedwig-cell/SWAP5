# PUB-GC E4 preregistration — finite-window response identity

## Status

**DESIGN FROZEN BEFORE E4 IMPLEMENTATION OR EXECUTION**

Date: 2026-09-18.

Publication line: PUB-GC / COUPLE.

Design baseline:

`integration/f-ci-canonical@0e68a716f655f9bba3a0962cf35ccb724b5184c3`

E4 is designed after the successful PUB-GC E1/E2 identity/transaction block and after the first PUB-GC E3/E3-D results, but before any E4 response-identity matrix is executed.

The purpose of E4 is not to make a response coefficient look successful. It is to determine what the currently exposed SWAP coupling response actually represents.

## Scientific question

For one immutable accepted SWAP origin and one finite coupling window, how are the following quantities related?

1. the predictor native flux-to-terminal-head response;
2. the F-GC30/F-GC44 coupling coefficient `u`;
3. the actual prescribed-head whole-window bottom exchange response;
4. the whole-window storage response;
5. the response of all remaining net water-balance terms.

E4 deliberately uses raw derivatives with explicit sign and unit conventions before assigning an interpretation such as "storage coefficient" or "interface Jacobian".

## Why raw derivatives are required

The predictor and corrector use different controlled variables and opposite native/public flux directions.

The predictor contract uses native SWAP bottom flux:

```text
q_bot > 0  means flux into SWAP
```

The public coupling interface uses:

```text
q_swap > 0 means water leaves SWAP through the bottom interface
```

Therefore an inverse relation between the same physical finite-window boundary map would naturally introduce a sign change. E4 must not assume in advance that:

```text
u = dV_out/dH
```

or that:

```text
u = dDeltaS/dH.
```

Those are hypotheses to be tested.

## Frozen first-stage states

E4-A uses only predictor points already shown READY by E3-D, without changing SWAP tolerances:

| window (day) | low-flux control (cm/day) | larger demonstrated predictor point (cm/day) |
| ---: | ---: | ---: |
| 1e-4 | 1e-6 | 3e-5 |
| 1e-3 | 1e-6 | 1e-4 |
| 1e-2 | 1e-6 | 1e-4 |

Total: six baseline window/forcing combinations.

The current fixture keeps top and predictor bottom flux equal at the baseline point. This gives a controlled near-steady forcing family and intentionally does not yet create a large net-storage forcing.

E3-R may later identify one or more of these cases as particularly useful for the manuscript, but E4-A identity measurements do not depend on E3-R being positive.

## Accepted-origin rule

For every baseline case:

- initialize one committed SWAP state;
- capture one immutable accepted checkpoint at the window start;
- every predictor perturbation and every prescribed-head corrector perturbation starts from that exact checkpoint;
- no E4 trial is committed;
- committed revision, time and interface ledger remain unchanged throughout the experiment.

Repeatability is tested from this same origin before numerical derivatives are interpreted.

## Part A — predictor bottom-flux derivative

Define the finite-window predictor map with all non-bottom forcing held fixed:

```text
H_end = P_W(q_bot ; S_n, F_top, other forcing)
```

The qualification harness must vary **only** the predictor bottom flux.

It is not admissible to estimate this derivative by calling a configured initializer in which both top and bottom flux change together, because the accepted-trajectory tangent currently uses bottom flux as the control coordinate while top forcing remains fixed.

For symmetric perturbation `delta_q`:

```text
D_Hq(delta_q) =
  [H_end(q0 + delta_q) - H_end(q0 - delta_q)]
  / (2 delta_q)
```

using native compatible units:

```text
H_end in cm
q_bot in cm/day
D_Hq in day.
```

The centered finite-difference F-GC30 response is then:

```text
u_FD(delta_q) = DeltaT_day / D_Hq(delta_q)
```

which is dimensionless.

The existing accepted-trajectory response is retained separately as:

```text
u_AT
```

and is not assumed to equal the finite-difference oracle before comparison.

### Predictor perturbation sequence

Use relative perturbations around each baseline q0:

```text
delta_q / |q0| =
  1e-4
  3e-4
  1e-3
  3e-3
  1e-2
  3e-2
  1e-1
```

provided both centered trials complete the exact window.

A failed perturbation point is recorded as outside the qualified centered pair for that baseline. No retry count, temporal budget, mass tolerance or solver tolerance is relaxed to obtain a derivative.

The derivative plateau is determined from convergence across perturbation scales, not by selecting the point that best agrees with `u_AT`.

## Part B — prescribed-head corrector response

For the same accepted origin, define the actual corrector map under a constant prescribed coupling-plane head over the full window:

```text
V_out(H) =
  signed whole-window bottom-outward water depth
```

with positive sign outward from SWAP.

For symmetric head perturbation `delta_H`:

```text
J_V(delta_H) =
  [V_out(H0 + delta_H) - V_out(H0 - delta_H)]
  / (2 delta_H)
```

using metres for both amount depth and head, so `J_V` is dimensionless.

Because the accepted corrector rate is a whole-window mean rate in this route:

```text
J_V =
  DeltaT_s * d q_swap / dH.
```

This is measured from the actual head-driven SWAP corrector and is not inferred from the predictor coefficient.

### Head perturbation sequence

Use:

```text
delta_H =
  1e-8
  3e-8
  1e-7
  3e-7
  1e-6
  3e-6
  1e-5
  3e-5
  1e-4 m
```

where both centered trials complete.

The small end is intended to expose the numerical noise floor; the large end is intended to expose nonlinearity or the current transaction envelope.

No requirement is imposed that all perturbation sizes succeed.

## Part C — storage response

For the same head-driven corrector trials record the complete canonical mass account:

```text
S_start
S_end
DeltaS
total_in
total_out
mass_residual
V_out
```

Define:

```text
J_S(delta_H) =
  [DeltaS(H0 + delta_H) - DeltaS(H0 - delta_H)]
  / (2 delta_H).
```

Use consistent water-depth/head units so `J_S` is dimensionless.

Define the signed net contribution of all non-bottom terms:

```text
B_other(H) = DeltaS(H) + V_out(H)
```

because the signed whole-window balance is written as:

```text
DeltaS = B_other - V_out.
```

Then:

```text
J_B(delta_H) = dB_other/dH
```

and the differentiated balance requires:

```text
J_S = J_B - J_V.
```

This relation is checked independently at every usable perturbation scale.

In the current fixed-top-flux, no-root, no-drainage fixture, `J_B` may be very small. That is a test outcome, not an assumption used to force the derivative identity.

## Repeatability / noise floor

Before centered derivatives are interpreted, repeat the exact central predictor and central prescribed-head corrector at least three times from the same accepted origin.

For each directly measured quantity report the maximum repeat spread.

A perturbation-derived change must be resolved above this repeatability floor. Derivative points dominated by numerical repeatability noise are labeled unresolved and cannot define the plateau.

## Primary identity tests

E4 reports four comparisons.

### I1 — analytic trajectory response versus centered predictor oracle

```text
u_AT  versus  u_FD.
```

This tests the currently admitted analytic accepted-trajectory response against a centered finite-window bottom-flux perturbation oracle.

### I2 — inverse predictor map versus actual head-driven outward exchange

Because native predictor `q_bot` is positive into SWAP while `V_out` is positive outward, the local-inverse hypothesis is:

```text
u_FD ~= -J_V
```

only if the predictor and corrector are local inverse representations of the same finite-window boundary map under compatible forcing/history conditions.

E4 does not assume these conditions hold.

### I3 — response versus storage

Compare:

```text
u_FD
u_AT
J_S
-J_V.
```

Possible interpretations include:

- `u ~= J_S ~= -J_V`: storage-dominated inverse interface response in this restricted fixture;
- `u ~= J_S` but not `-J_V`: storage linearization is not the actual interface inverse;
- `u ~= -J_V` but not `J_S`: interface response contains material non-storage contribution;
- none agree: the operational meaning of `u` requires revision before ACCELERATE claims proceed.

No one of these outcomes is privileged in advance.

### I4 — differentiated balance closure

Check:

```text
J_S - J_B + J_V = 0
```

against a tolerance derived from the repeatability/noise floor and centered-difference arithmetic.

Failure to close is treated first as an accounting/system-boundary problem, not as evidence of exotic response physics.

## Tangent defect and local linearity

After a stable central `J_V` is identified, evaluate the first-order prediction:

```text
V_lin(H0 + delta_H) =
  V_out(H0) + J_V * delta_H.
```

Define the normalized tangent defect:

```text
N(delta_H) =
  |V_out(H0 + delta_H) - V_lin(H0 + delta_H)|
  /
  max(
    |V_out(H0 + delta_H) - V_out(H0)|,
    V_noise
  ).
```

`V_noise` is derived from repeatability, not chosen to improve the curve.

The experiment reports the defect curve. A scalar `r_lin` may be reported only after a manuscript-level defect threshold is justified; E4-A does not invent such a threshold post hoc.

## Output record

For each baseline case persist:

- exact accepted-origin identity;
- window;
- baseline forcing;
- `u_AT`;
- predictor repeatability;
- every `delta_q`, plus/minus terminal head, status and `u_FD`;
- corrector repeatability;
- every `delta_H`, plus/minus:
  - signed `V_out`;
  - mean `q_swap`;
  - storage start/end/change;
  - total in/out;
  - mass residual;
- `J_V`, `J_S`, `J_B`;
- differentiated balance residual;
- tangent-defect values;
- trial failure stage where applicable.

All raw observations are persisted, not only selected plateau values.

## Evidence statuses

E4-A may conclude:

```text
IDENTITY_RESOLVED
PARTIAL_IDENTITY
NO_DERIVATIVE_PLATEAU
NOISE_LIMITED
CORRECTOR_ENVELOPE_LIMITED
PREDICTOR_PERTURBATION_LIMITED
BALANCE_IDENTITY_FAILED
```

A baseline case can have different statuses for predictor and corrector derivatives.

## Stop rules

E4 must stop ACCELERATE-style interpretation for a case if:

- repeatability is insufficient to resolve the derivative;
- no centered derivative plateau exists;
- differentiated balance cannot be closed;
- the corrector map is not locally single-valued/reproducible in the tested neighborhood.

A failed E4 identity does not invalidate PUB-GC as a coupling-method paper. It changes the interpretation and admissibility of response-informed acceleration.

## Explicit exclusions from E4-A

E4-A does not yet establish:

- inter-window response drift;
- reuse lifetime of a tangent;
- waveform/path dependence under time-varying head trajectories;
- spatial/N:1 aggregation validity;
- IQN/Anderson performance;
- a universal hydrological response law.

Those belong to later E4-B/E5/SCALE work if the E4-A identity is sufficiently well defined.

## Relation to E3 and E5

E3 determines where feedback is numerically and physically relevant.

E4 determines what information the SWAP component is actually supplying about that feedback.

Only after both are known does E5 ask whether exposing that information is computationally more valuable than learning it from black-box interface history.
