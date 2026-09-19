# F-ROMV2 D24 native rainfall + groundwater adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D24  
**Decision:** **FMC_NATIVE_RAINFALL_GROUNDWATER_COMPOSITION_RETAINS_RESEARCH_CANDIDACY_RELATIVE_TO_R2**

## Question

D24 asks whether two FMC/SMVE branches that had already been qualified separately remain scientifically useful when they are active at the same time:

- native rainfall, ponding and runoff at the surface;
- a G25 fixed-water-table groundwater front at the lower boundary.

The experiment deliberately remains in the separated branch. Surface and groundwater fronts may not contact or merge.

This is development evidence on homogeneous B01 hydraulics. It is not application acceptance.

## Staged authority

D24 was staged so that no R16/R2 trajectory could be generated before the FMC-only composite route passed its own accounting and domain checks.

Stage 1:

- workflow run **35467798461**;
- job **105963213678**;
- artifact **10591189096**;
- digest `sha256:4f25f71cf75bf90d78cad3d11422d6a59a6c3b51da0e1f549f36b2be6728023f`;
- decision **D24_FMC_NATIVE_RAIN_GW_PREFLIGHT_PASS**.

No R16/R2 trajectory evidence had been consumed at that point.

The three histories RG05, RG20 and RG40 remained physical and mass-conservative over 16 ten-second rainfall intervals. Minimum surface-groundwater separation was about **14.01869 cm**.

## Primary execution

Primary Stage-2 workflow run **35471764440**, job **105973868867**, executed head

`0d7abc3acc374dbe6192baaca471f545caa103c3`.

Artifact:

- ID **10591979922**;
- digest `sha256:2c53b47c03ab3adf26419c169447f708daa5d5197fdedb29dd715c827a9d98cd`;
- result SHA-256 `649dd06a588972c382634e8d7247e196a78409f4d590d675469b3ba01fca9ede`.

R16 and R2 are each bitwise identical between O0 and O2:

- R16 SHA-256 `c0571d38427e4122a6376afb9f24aa6a1c625b2ba2524f81542c5dca3bb0c826`;
- R2 SHA-256 `a1fec425c91e5131bccb53874ed4f8d82c65a62d8e8e3a6b901806b710e20748`.

## Frozen experiment

The three rainfall histories use 0.5, 2 and 4 times B01 Ksat.

All histories:

- start from the same finite-volume composite state containing the admitted D16 surface fronts and D13/D17 G25 groundwater fronts;
- use the current-canonical native dynamic-top provider for R16/R2;
- use zero pressure head at the 160-cm lower boundary;
- contain no ET or root uptake;
- contain no dry-bin activation;
- contain no falling slugs;
- contain no contact/merge;
- contain no clipping or full-order fallback.

The FMC branch reserves the frozen gray-bin throughflow before allocating remaining surface water to connected fronts, advances groundwater fronts by the admitted Eq.21 route, and closes the combined soil + surface + runoff + bottom-exchange ledger.

## Pooled hydrological result

Relative to R16:

| metric | FMC | R2 |
|---|---:|---:|
| cumulative infiltration RMSE | **0.005882 cm** | 0.010799 cm |
| surface-store RMSE | **0.003113 cm** | 0.005727 cm |
| cumulative runoff RMSE | **0.002855 cm** | 0.005221 cm |
| total-storage RMSE | **0.014626 cm** | 0.033443 cm |
| cumulative bottom-exchange RMSE | **0.009426 cm** | 0.024039 cm |
| mapped 16-cell theta RMSE | **0.0004259** | 0.0456733 |
| terminal bottom-flux RMSE | **8.682 cm d-1** | 21.484 cm d-1 |
| bottom-flux sign errors | **0** | 0 |

Every preregistered D24 frontier gate passes.

The frozen decision is therefore:

`FMC_NATIVE_RAINFALL_GROUNDWATER_COMPOSITION_RETAINS_RESEARCH_CANDIDACY_RELATIVE_TO_R2`.

## Why D24 matters

Earlier positive FMC evidence could still have been an artifact of testing branches separately:

- D13: groundwater-front relaxation;
- D16/D23: surface infiltration, redistribution and native rainfall/runoff;
- D17: separated surface + groundwater composition under prescribed infiltration.

D24 removes that remaining separation for the native atmospheric route.

Native rainfall, ponding/runoff, profile redistribution and fixed-water-table groundwater exchange are active together, and FMC still improves on R2 on all eight frozen views.

This is the strongest evidence so far that the FMC/SMVE family is not merely a branch-specific approximation.

## Diagnostic caveat

One diagnostic does not favor FMC.

Pooled upper-zone storage RMSE is:

- FMC: **0.013918 cm**;
- R2: **0.012646 cm**.

R2 is slightly better on this diagnostic.

Upper-zone storage was not an independent preregistered D24 decision gate, so this does not alter the frozen D24 decision. It must, however, remain visible when later application-specific fidelity is defined.

By contrast, lower-zone storage strongly favors FMC:

- FMC: **0.000748 cm**;
- R2: **0.021856 cm**.

This split is important for groundwater-coupled use: D24's strongest structural advantage remains the lower-zone/profile and groundwater-exchange representation, not uniform superiority for every state diagnostic.

## Purpose-dependent interpretation

### Regional water balance

**Research candidacy strengthened, not qualified.**

The short D24 horizon is insufficient for seasonal or multi-year accumulation, ET partitioning or drought-memory claims.

### Groundwater-coupled many-column use

**Research candidacy strengthened, not live-coupling qualification.**

FMC improves lower-zone storage, cumulative bottom exchange and terminal bottom-flux magnitude relative to R2 in the fixed-water-table envelope. Dynamic groundwater feedback and MODFLOW exchange remain separate tests.

### Fast rainfall / runoff response

**Bounded candidacy retained.**

Surface-store, runoff and infiltration errors all improve over R2, while D21's native threshold non-equivalence remains valid. Exact event timing equivalence to R16 is not required by D24.

### Operational soil moisture / drought

**Not qualified.**

No ET, root extraction, seasonal forcing or drought recovery is present.

### Scientific process/extreme inference

**Not qualified.**

D24 is a deliberately reduced hydraulic development experiment.

## Computational meaning

D24 does not contain a formal timing comparison.

The positive result does change the order of work: unlike C2, L2_IMC, QS1, QS2 and HE2, FMC now has enough bounded hydrological evidence that a same-runtime cost screen can become scientifically meaningful.

That screen must preserve the frozen FMC equations, 200-bin discretization and 10-s process step. It may not obtain speed by changing the scientific model after D24.

A shared-host or scripting-language measurement would be screening evidence only unless the existing performance architecture admits it.

## Boundary

D24 does not authorize:

- application acceptance thresholds;
- ET/root uptake claims;
- seasonal water balance;
- arbitrary water-table depth;
- live MODFLOW coupling;
- formal performance;
- production ROM.

No post-exposure rainfall-factor, lambda, initial-state, surface-law, bin, process-step, Eq.18/Eq.21, gray-demand, relaxation or decision-gate retuning is authorized.

Production ROM remains unauthorized.
