# F-ROMV2 D7 QS1 adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D7  
**Decision:** **QS1_NOT_WORTH_TABULATING_IN_EXPOSED_B01_DOMAIN**

## 1. Purpose

D7 tests the one-state quasi-steady profile-manifold hypothesis after D6 showed that the original fixed `[-Ksat,+Ksat]` endpoint contract was itself physically invalid.

D7 does not change the QS1 hydrological equations. It changes only the root-search construction so that open physical-domain boundaries are approached from finite interior points.

The candidate state is total column storage only. The vertical pressure-head and water-content profile are reconstructed as a quasi-steady B01 profile for each evaluation.

D7 is a development architecture discriminator on already exposed B01 histories. It is not blind application qualification.

## 2. Preflight

Before any D01-D08 or V01-V04 trajectory evaluation, D7 tested three synthetic storage states:

- (S_0-Delta t K_{sat});
- (S_0);
- (S_0+Delta t K_{sat}).

Both root families pass:

- prescribed-head boundary, solve for steady (q);
- prescribed-flux boundary, solve for bottom pressure head.

All reconstructed roots are finite and physically admissible.

The preflight decision is:

`D7_ADMISSIBLE_ROOT_SEARCH_PREFLIGHT_PASS`.

No root-search retuning is authorized after this point.

## 3. Primary execution authority

Primary workflow run **35446746283**, job **105906874545**, executed head

`7944bea0872526ba8f9419e8b5a0bc71abf78296`.

Artifact:

- ID: **10586330711**
- digest: `sha256:1937706f05d151f462e75b3c01d562d4401c597cdbc67c3d7ced365f2e0aafe4`
- result SHA-256: `e3cd1bc80cb522ee2ac396f9306bf5bb21cc47323af4c4cebda50b031a37815c`.

The R16 O0/O2 outputs are bitwise identical.

The primary scientific run uses the pure-Python frozen RK4 evaluator with exact root-evaluation caching and termination when double precision cannot represent a new bisection midpoint.

Later execution-branch work that compiled the same RK4 profile evaluator is performance-only and is not required for the scientific decision.

## 4. Integrity

QS1 completes all 12 histories.

There are:

- no nonfinite states;
- no clipping;
- no adaptive dynamic substeps;
- no trajectory training;
- no full-order fallback;
- no hidden mass correction.

Maximum absolute transaction mass residual is about

**3.51e-15 cm**,

well below the frozen **1e-12 cm** gate.

QS1 is therefore not rejected for instability or conservation failure.

## 5. Pooled hydrological fidelity

Relative to R16:

| metric | QS1 | R2 | D5 L2_IMC |
|---|---:|---:|---:|
| total-storage RMSE | 0.047338 cm | 0.040709 cm | 0.051645 cm |
| cumulative bottom-exchange RMSE | 0.047338 cm | 0.040709 cm | 0.051645 cm |
| terminal bottom-flux RMSE | 3.344 cm d-1 | 3.002 cm d-1 | 3.579 cm d-1 |
| bottom-flux sign errors | 136/768 | 136/768 | 136/768 |
| histories with reversal mismatch | 8/12 | 8/12 | 8/12 |

QS1 therefore improves on the simple instantaneous two-layer D5 architecture, but still does not beat the already admitted R2 comparator on either preregistered frontier.

The balance view fails.

The transient view fails.

The frozen decision is therefore:

`QS1_NOT_WORTH_TABULATING_IN_EXPOSED_B01_DOMAIN`.

## 6. Why this is useful negative evidence

D5 and D7 fail for different physical reasons.

D5 carried two dynamic layer-average water contents but estimated lower-boundary exchange from instantaneous Darcy gradients between those two averages. Its error was strongly concentrated in the lower layer.

D7 instead reconstructs a physically resolved quasi-steady vertical profile from only one dynamic scalar, total storage.

That removes the crude two-head Darcy approximation and improves both total balance and bottom-flux magnitude relative to D5.

But it also forces the entire vertical profile to lie instantaneously on a steady manifold.

The result is still worse than R2, and the profile partition is poor:

- upper-storage RMSE: about **0.1295 cm**;
- lower-storage RMSE: about **0.1099 cm**.

The missing quantity is therefore not simply a better static storage-to-flux function.

The evidence now points to **dynamic profile memory**.

## 7. History dependence

Pure prescribed-flux histories D01, D02 and D05 are reproduced almost exactly in total balance and bottom flux.

The failures emerge when prescribed groundwater head and switching histories require the column to remember how water is vertically distributed.

Examples:

- D03 final cumulative bottom-exchange error is about **+398%** of the R16 cumulative exchange;
- D06 bottom-flux RMSE is about **5.29 cm d-1**;
- V02 final cumulative exchange error is about **+26.7%**;
- V01, V02, V03 and V04 all miss the R16 reversal sequence.

These percentages describe exposed development behavior. They are not application acceptance thresholds.

This behavior is consistent with the known limitation of quasi-steady unsaturated-zone models: they can transmit changes toward groundwater too rapidly because the vertical profile has insufficient transient memory.

## 8. Purpose-dependent interpretation

### Long-term regional water balance

**Not retained against R2 in the current B01 development frontier.**

QS1 is closer conceptually to this application class than to event simulation, but the already available R2 comparator has better balance fidelity.

### Groundwater-coupled many-column simulation

**Not qualified.**

The lower-boundary flux magnitude, sign transitions and reversal sequence are not improved enough relative to R2.

### Fast-event / threshold-sensitive simulation

**Not qualified.**

### Operational soil moisture / drought

**Not tested.**

### Scientific process / extreme inference

**Not qualified.**

## 9. Architecture decision

D7 closes the **one-state quasi-steady manifold**.

It does not close quasi-steady or reduced physical modeling in general.

The evidence sequence is now:

1. C2: local two-state data-driven closure has useful information but insufficient domain coverage;
2. R8/R4/R2: coarse Richards is broadly executable under purpose-appropriate numerical authority, with declining event fidelity as vertical resolution is removed;
3. L2_IMC: two dynamic layer averages are robust but their instantaneous Darcy closure is too crude;
4. QS1: a high-resolution static profile manifold improves on L2_IMC but remains dominated by R2.

The next distinct hypothesis must therefore contain at least one **independent dynamic profile-memory coordinate**.

That may be expressed as, for example:

- independent upper- and lower-zone storages with a quasi-steady subprofile reconstruction;
- a storage plus vertical-partition/shape coordinate;
- a lagged groundwater-flux or profile-relaxation state.

The next workunit must select and preregister one such architecture before new confirmatory evidence.

Further QS1 table refinement, root-search tuning or interpolation optimization is not justified because D7 establishes a state-information limitation before performance engineering.

Production ROM remains unauthorized.
