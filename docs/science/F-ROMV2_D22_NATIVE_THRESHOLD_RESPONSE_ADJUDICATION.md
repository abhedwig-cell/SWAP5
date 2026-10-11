# F-ROMV2 D22 native surface-threshold response adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D22  
**Decision:** **FMC_NATIVE_SURFACE_THRESHOLD_RESPONSE_COMPETITIVE_WITH_R2**

## Why D22 follows D21

D21 deliberately tried to construct a matched three-regime rainfall workload before any Richards trajectory was run.

That failed at 2 Ksat:

- R16 dynamic-top: ponded without runoff;
- FMC: already ponded with positive runoff.

D21 therefore correctly closed the **matched-label** route.

D22 asks a different and more appropriate reduced-model question:

> If FMC is allowed to retain its native threshold behavior, is its complete surface response at least as close to R16 as the already admitted R2 physical reduction?

No rainfall factor, surface parameter or FMC equation is changed from D21.

## Frozen response experiment

The seven rainfall factors remain:

0.25, 0.5, 1, 2, 4, 8 and 16 Ksat.

The 10-s step, ponding maximum and linear runoff parameters also remain unchanged.

Three native one-step response functions are compared from the same D16 I_DEEP physical column:

- **R16:** current-canonical dynamic-top provider using the mapped 0-10 cm top state;
- **R2:** the same provider using the mapped 0-80 cm top state of the two-cell coarse column;
- **FMC:** D16/D15 connected-front infiltration plus the frozen D21 surface-reservoir law.

This is not a Richards trajectory experiment.

## Immutable execution

Execution-only PR #467 was closed unmerged.

Primary run:

- workflow run **35463113484**;
- job **105950404333**;
- executed head `ad40957754363397ad431af69d95885b11df99c1`;
- artifact **10590790990**;
- artifact digest `sha256:030b31c440e6d50caca0302dff2dc85cdfd98fcf2e81d4c08780d56550b658a2`;
- raw result SHA-256 `dedbb131e159f1f1ac7af87ef2e51d7ac3e03b618533c9fbea59a877b5356f3d`.

The R16/R2 provider output is bitwise identical at O0 and O2.

## Native threshold locations

| candidate | ponding onset | runoff onset |
|---|---:|---:|
| R16 | 2 Ksat | 4 Ksat |
| R2 | 1 Ksat | 2 Ksat |
| FMC | 1 Ksat | 2 Ksat |

FMC therefore does **not** reproduce R16's discrete threshold locations.

That is not a new finding; it preserves D21.

But R2 shows exactly the same one-factor displacement.

Measured as absolute log2 distance from the R16 onset:

- ponding: FMC = 1, R2 = 1;
- runoff: FMC = 1, R2 = 1.

Both models also disagree with the R16 native regime at two of the seven frozen rainfall factors.

## Full response curves

Relative to R16:

| metric | FMC | R2 |
|---|---:|---:|
| infiltration-depth RMSE | **0.0006240 cm** | 0.00112635 cm |
| surface-store RMSE | **0.0005723 cm** | 0.00103034 cm |
| runoff-depth RMSE | **5.63395e-05 cm** | 1.02589e-04 cm |
| regime mismatches | 2/7 | 2/7 |

FMC is therefore closer to R16 than R2 on all three continuous response curves, while tying R2 on discrete threshold displacement and regime mismatches.

All six preregistered all-required frontier gates pass.

## Scientific interpretation

D21 and D22 must both remain true.

### D21

FMC cannot be described as threshold-equivalent to R16.

At the frozen 2 Ksat supply, its native surface accounting already routes a small amount to runoff while R16 remains in a no-runoff ponded regime.

### D22

That non-equivalence is not sufficient to reject the reduction.

The accepted R2 comparator shifts the same threshold locations, and FMC reproduces the entire infiltration/ponding/runoff response curve **better** than R2.

Therefore FMC retains **fast surface-threshold research candidacy relative to R2**.

This is a purpose-dependent reduced-model conclusion, not a claim of numerical equivalence.

## What is still missing

D22 does not include accepted Richards trajectories.

It does not show how surface-threshold differences propagate into:

- transient profile storage;
- runoff accumulation over a multi-step storm;
- post-rainfall redistribution;
- bottom flux;
- event timing under an evolving soil state.

Those quantities require a separately preregistered short accepted-trajectory experiment.

## Authority boundary

D22 does not establish:

- application acceptance;
- production ROM readiness;
- a formal speedup;
- ET/root-uptake fidelity;
- groundwater-coupling fidelity;
- long-term threshold reliability.

D13-D20 remain unchanged.

D21 remains unchanged.

No threshold is retuned after exposure.

Production ROM remains unauthorized.
