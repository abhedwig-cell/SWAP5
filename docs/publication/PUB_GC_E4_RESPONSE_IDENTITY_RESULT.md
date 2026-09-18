# PUB-GC E4 result — finite-window response identity

## Status

**SUPPORTED_RESTRICTED — response identity resolved inside the qualified fixture**

Date: 2026-09-18.

Primary successful numerical evidence:

- source head: `c85b1f1ad2a35ad12d917c54e682e8705c508c7e`;
- workflow run: `35349233134` — **PASS**;
- job: `105613077818` — **PASS**.

The source head already contained the corrected pure-bottom-flux finite-difference route, the storage-carrier noise floor, the signed response preregistration, and raw non-bottom balance data. Later commits on the same E4 branch only improve baseline-local failure handling, result interpretation and CI scheduling; they do not change the numerical response definitions used below.

## Question

For one immutable accepted SWAP origin and finite coupling window, compare:

```text
u_A   accepted-trajectory predictor response
u_FD  centred pure-bottom-flux -> terminal-head finite-difference response
J_S   d(storage change) / dH
J_R   d(accepted-sign whole-window bottom transfer) / dH
J_B   d(non-bottom net balance) / dH
```

The key distinction is between two different finite-window maps:

```text
Neumann-like predictor:
    q_bot -> H_end

Dirichlet-like corrector:
    H -> V_u
```

E4 tests rather than assumes that these maps carry the same local derivative information.

## Primary response estimates

The preregistered smallest qualifying three-point plateau is used for the reported estimate.

| baseline | window d | q_bot cm/d | u_A | u_FD | J_S | J_R | |J_R| / u_A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| B1 | 1e-4 | 1e-6 | 3.4029360e-5 | 3.4029453e-5 | 3.4028336e-5 | -3.4028336e-5 | 0.999970 |
| B2 | 1e-3 | 1e-6 | 2.6861064e-4 | 2.6860702e-4 | 2.6860958e-4 | -2.6860958e-4 | 0.999996 |
| B3 | 1e-3 | 1e-4 | 2.6657437e-4 | 2.6657437e-4 | 2.8821767e-4 | -2.8821767e-4 | 1.081190 |
| B4 | 1e-2 | 1e-6 | 1.1902721e-3 | 1.1902765e-3 | 1.1902723e-3 | -1.1902723e-3 | 1.000000 |
| B5 | 1e-2 | 1e-4 | 1.1201581e-3 | 1.1201580e-3 | unavailable | unavailable | unavailable |

## Result 1 — u_A is a genuine flux-driven predictor response

The corrected E4-B experiment holds atmospheric/top flux fixed at the baseline value and perturbs **only** the prescribed lower-boundary flux.

Across all five baselines, `u_A` and the independent centred finite-difference `u_FD` agree closely.

Relative discrepancies:

| baseline | E_AFD |
| --- | ---: |
| B1 | 2.73e-6 |
| B2 | 1.35e-5 |
| B3 | 8.11e-9 |
| B4 | 3.72e-6 |
| B5 | 8.45e-8 |

Thus the accepted-trajectory response is strongly validated as the local response of the finite-window **flux-driven predictor map**:

```text
u_A ~= DeltaT / (dH_end/dq_bot).
```

This is a much stronger interpretation than merely calling `u` a generic empirical storage coefficient.

It is also narrower: E4 does not support describing `u_A` as a universal coupling Jacobian.

## Result 2 — low-flux head-driven response is balance-aliased

For B1, B2 and B4:

```text
J_S ~= +u_A
J_R ~= -u_A
J_B ~= 0.
```

The agreement is very close:

- B1: `J_R/u_A = -0.9999699`;
- B2: `J_R/u_A = -0.9999960`;
- B4: `J_R/u_A = -1.0000002`.

The raw differentiated balance confirms why:

```text
J_S - J_B + J_R = 0
```

to numerical differentiation precision.

Observed maximum absolute `J_B` over all valid centred perturbations:

- B1: `2.0e-21`;
- B2: `1.35e-20`;
- B3: `3.45e-20`;
- B4: `8.83e-20`.

Maximum absolute derivative-balance closure error:

- B1: `1.63e-19`;
- B2: `2.60e-18`;
- B3: `1.94e-16`;
- B4: `3.90e-17`.

In the current fixture the non-bottom forcing is approximately head-independent, so `J_B ~= 0` and mass closure structurally gives:

```text
J_S ~= -J_R.
```

Therefore B1/B2/B4 cannot by themselves uniquely distinguish a “storage response” interpretation from a signed “interface response” interpretation. They are aliased by the deliberately simple process configuration.

## Result 3 — stronger flux separates the Neumann and Dirichlet responses

B3 is the decisive non-trivial response-identity case.

Configuration:

```text
window = 1e-3 day
q_bot  = 1e-4 cm/day
```

The flux-driven responses still agree essentially exactly:

```text
u_A  = 2.665743709e-4
u_FD = 2.665743731e-4
E_AFD = 8.11e-9.
```

But the head-driven whole-window response is:

```text
J_R = -2.882176720e-4
J_S = +2.882176720e-4.
```

Hence:

```text
|J_R| / u_A = 1.08119048.
```

The actual head-driven response magnitude is about **8.1% larger** than the flux-driven predictor response.

This falsifies the broad identity:

```text
u_A == -J_R
```

as a general finite-window coupling statement, even though it is an excellent approximation in the lower-flux controls.

The result also explains the adverse E3 observation that a frozen affine predictor response need not be the best one-pass representation of the corrector mapping.

## Result 4 — B5 separates response existence from corrector-domain existence

B5 uses:

```text
window = 1e-2 day
q_bot  = 1e-4 cm/day.
```

The flux-driven predictor response is highly reproducible:

```text
u_A  = 1.120158118e-3
u_FD = 1.120158023e-3
E_AFD = 8.45e-8.
```

However, no valid symmetric centred head-driven derivative exists over the preregistered perturbation sequence.

The first tested symmetric scale is already only:

```text
deltaH = 1e-10 m,
```

yet one side of the prescribed-head response is outside the qualified corrector transaction envelope. Other nearby scales show similarly bounded/asymmetric availability.

Therefore E4 demonstrates a scientifically important distinction:

> A stable flux-driven predictor tangent can exist even where the corresponding local prescribed-head interface tangent is not robustly identifiable within the admitted component transaction envelope.

This is direct evidence that “response information” must be typed by the map and boundary condition from which it is obtained.

## Response-domain observations

The head-driven response is highly reproducible where valid, but the admissible perturbation domain is not necessarily a simple monotonic radius.

Examples:

- B1 and B2 have stable derivative plateaus and valid centred perturbations through micrometre-scale head changes before larger bounded failures.
- B3 has isolated very-small-scale failures while larger perturbations still form stable plateaus; therefore a single “first failed perturbation” must not be interpreted as a monotonic linear-response radius.
- B4 remains centred-valid through the largest tested `1e-5 m` perturbation.
- B5 has no symmetric local head-response plateau.

This means later ACCELERATE work should characterize both derivative quality and **response-domain topology**, not merely report one scalar radius.

## Implications for F-GC30 / coupling semantics

E4 supports the following terminology.

### Defensible

`u_A` is a:

> **finite-window flux-driven predictor response**, locally equivalent to the inverse terminal-head sensitivity of the prescribed-bottom-flux map.

### Not generally defensible

`u_A` should not be called, without qualification:

- the actual head-to-exchange Jacobian;
- the universal SWAP-MODFLOW coupling Jacobian;
- a static soil storage coefficient.

Its numerical value depends on window and state, and the actual head-driven response can differ materially or be unavailable.

## Implications for ACCELERATE / E5

E5 must distinguish at least three response sources:

```text
1. u_A
   cheap component-supplied Neumann/predictor response

2. J_R,oracle
   direct head-driven finite-window exchange tangent where identifiable

3. IQN/Anderson
   black-box response learned from coupling history
```

A fair acceleration study may no longer treat `u_A` as the zero-cost oracle Jacobian.

The most informative comparison is now:

```text
fixed point
Aitken
IQN/Anderson
current u_A-informed coupling
zero-cost J_R oracle
```

with total equivalent SWAP work and convergence domain as primary outcomes.

If the oracle `J_R` gives no material advantage over IQN/Anderson, the independent ACCELERATE claim fails.

If `u_A` performs comparably to the oracle only in the low-flux aliased regime but degrades where B3-like response separation appears, E4 provides a mechanistic explanation.

## Need for one later disambiguation experiment

Because the current fixture has:

```text
J_B ~= 0,
```

storage and bottom-transfer response are algebraically tied.

A later physical-identity extension should activate an already admitted head-dependent non-bottom process or forcing pathway, if available, so that:

```text
J_B != 0.
```

Only then can the storage-response and interface-response interpretations be physically separated rather than balance-aliased.

This extension is useful for physical interpretation but is **not required before E5**. E5 can already treat `u_A` and oracle `J_R` as distinct numerically defined information objects.

## Decision

**E4: PASS, with a restrictive scientific conclusion.**

The current response is real, reproducible and well identified as a flux-driven finite-window predictor response.

The broader claim that this same quantity is automatically the head-driven coupling Jacobian is falsified by B3 and by the B5 response-domain failure.

This narrows but strengthens the manuscript: SWAP5 exposes a well-defined response quantity, and the experiments now show exactly when its use as a corrector linearization is justified and when it is not.

## Durable raw evidence

The complete preregistered perturbation evidence is versioned in the repository rather than relying on the expiring Actions artifact:

- `docs/publication/evidence/PUB_GC_E4_RAW_HEAD_SCANS.json` — all 5 head scans, including H0 parity, repeats, all prescribed-head perturbations and authority-state records;
- `docs/publication/evidence/PUB_GC_E4_RAW_FLUX_POINTS.json` — all 70 pure-bottom predictor points;
- `docs/publication/evidence/PUB_GC_E4_FULL_RESULT.json` — recomputed plateau candidates, selected estimates and full derivative sequences;
- `docs/publication/evidence/PUB_GC_E4_DERIVATIVES.csv` — all centred head derivatives and flux-driven inverse-response estimates.

These records were recovered from successful workflow run `35349233134`, job `105613077818`, source head `c85b1f1ad2a35ad12d917c54e682e8705c508c7e`. The original artifact digest is `sha256:f7d1304f321802492a299d50c4be3d02534c26242e7312b4c41996c9d398eef6`. Recomputed primary plateau estimates were required to match the already admitted summary before this persistence repair was committed.
