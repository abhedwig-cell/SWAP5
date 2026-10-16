# F-ROMV2 D23 short accepted rainfall trajectory adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D23  
**Decision:** **FMC_SHORT_RAINFALL_TRAJECTORY_RETAINS_FAST_SURFACE_RESEARCH_CANDIDACY_RELATIVE_TO_R2**

## 1. Why D23 exists

D21 and D22 established two facts that must remain simultaneously true.

D21 showed that FMC and R16 do not place the rainfall-to-runoff threshold at the same native forcing. At the frozen 2 Ksat case FMC already produces runoff while R16 is still on the ponded/no-runoff branch.

D22 then showed that this non-equivalence is not by itself a reason to reject FMC: R2 has the same one-factor threshold displacement and FMC is closer to R16 than R2 on the complete one-step infiltration, surface-store and runoff response curves.

D23 asks the next purpose-dependent question:

> When those native threshold differences are allowed to persist, how do they propagate through an accepted short storm and post-storm redistribution trajectory?

The experiment does not force matched regime labels.

## 2. Frozen workload

Three already exposed native regimes are used:

- R05: 0.5 Ksat;
- R20: 2.0 Ksat;
- R40: 4.0 Ksat.

Every history consists of:

- 16 rainfall intervals of 10 s;
- 48 zero-rain hiatus intervals of 10 s;
- 640 s total duration.

The common initial condition is the D16/D14 `I_DEEP` finite-moisture-content profile.

R16 and R2 use the current-canonical dynamic-top boundary provider before each accepted Reference soil-water interval. FMC uses the already qualified D12-D16/D22 finite-volume surface accounting and redistribution rules.

No factor, duration, ponding limit, runoff law, bin count, process step or FMC kinematics is fitted to D23 results.

## 3. Staged authority

### Stage 1: FMC-only preflight

Workflow run **35467095819**, job **105961331644**.

Artifact:

- ID: **10591367823**
- digest: `sha256:5b577b876916a18c3e36d3c0abd5a12f2040f5bf9fbbfaa74eacc87fede4feb2`.

No R16 or R2 trajectory evidence had been generated when this preflight passed.

All three FMC histories close their complete rain + soil + surface-store + runoff ledger.

Final FMC cumulative runoff is:

- R05: 0 cm;
- R20: 0.0376507457 cm;
- R40: 0.133115414 cm.

First complete detachment to falling slugs occurs at steps 17, 23 and 29 respectively.

These are exposed D23 outcomes and are not subsequently retuned.

### Stage 2: accepted trajectories

Primary workflow run **35467238981**, job **105961724341**, executed head

`2682829ceb969cbe0e7d19b9eb14d9b8bb28b6ab`.

Artifact:

- ID: **10591841201**
- digest: `sha256:688b48f23d44ef950cbe27d8e942e714c76f3119a871f33fb78d83d70bf0a230`.

R16 and R2 are bitwise identical between O0 and O2.

The execution PR is closed unmerged. Canonical imports evidence only.

## 4. Preregistered frontier result

All seven all-required D23 gates pass.

| pooled RMSE versus R16 | FMC | R2 |
|---|---:|---:|
| cumulative infiltration | **0.009152 cm** | 0.017395 cm |
| surface store | **0.002244 cm** | 0.004200 cm |
| cumulative runoff | **0.008048 cm** | 0.015281 cm |
| upper 0-80 cm storage | **0.024974 cm** | 0.025646 cm |
| mapped 16-cell theta | **0.000936** | 0.032839 |
| hiatus upper storage | **0.027700 cm** | 0.028650 cm |
| hiatus mapped theta | **0.001059** | 0.032787 |

The strongest distinction is profile fidelity. FMC retains the explicit finite-water-content fronts/slugs that encode vertical redistribution memory, whereas R2 represents each 80-cm half by one cell-average state.

## 5. Native threshold non-equivalence remains

D23 does not reverse D21.

For R20:

- R16 first ponding step: 1;
- FMC first ponding step: 1;
- R2 first ponding step: 1;
- R16 first runoff step: **2**;
- FMC first runoff step: **1**;
- R2 first runoff step: **1**.

At the end of R20:

- R16 cumulative runoff: 0.028181 cm;
- FMC: 0.037651 cm;
- R2: 0.046394 cm.

Thus FMC begins runoff one interval too early, exactly as the native threshold evidence predicted, but its accumulated response is still materially closer to R16 than R2.

For R40 all three routes enter runoff on the first interval. Final cumulative runoff is:

- R16: 0.119791 cm;
- FMC: 0.133115 cm;
- R2: 0.145225 cm.

R05 remains runoff-free in all three routes.

## 6. Important lower-zone caveat

D23 is not a claim that FMC dominates R2 on every hydrological quantity.

Pooled lower 80-160 cm storage RMSE is:

- FMC: **0.016385 cm**;
- R2: **0.009983 cm**.

R2 is better on this diagnostic.

That quantity was deliberately not one of the D23 frontier gates. The workunit targets short atmospheric threshold response and surface-to-profile redistribution with zero bottom exchange, not lower-zone or groundwater-coupling fidelity.

The positive decision therefore cannot be generalized to concurrent rainfall-groundwater interaction.

## 7. Purpose-dependent interpretation

### Fast surface threshold and redistribution

**Research candidacy retained relative to R2.**

FMC is not threshold-equivalent to R16, but it reproduces the hydrological consequences of the short native rain/ponding/runoff sequence better than R2 on every preregistered D23 frontier view.

### Groundwater-coupled many-column simulation

**Concurrent rainfall + groundwater is not yet qualified.**

Groundwater-front behavior and surface behavior have both been positive in separate bounded experiments, and D17/D19/D20 provide composition/contact/persistence evidence, but D23 itself has zero bottom flux.

### Long-term regional water balance

**Not qualified by D23.**

The experiment is 640 seconds long.

### Operational soil moisture / drought

**Not tested.**

### Scientific process / extreme inference

**Not qualified.**

## 8. Scientific consequence

The evidence sequence is now stronger than at D22:

- groundwater-front FMC can beat R2 in a bounded capillary-fringe envelope;
- surface redistribution FMC can beat R2;
- exact surface-groundwater contact/merge can retain candidacy;
- one-hour fixed-water-table persistence can retain candidacy;
- native one-step rainfall threshold response can be competitive with R2;
- and now a short accepted storm + hiatus trajectory also beats R2 on all preregistered surface/redistribution views.

The next high-value hydrological discriminator is therefore not another isolated surface test.

It is a bounded **native rainfall + active fixed-water-table** composition experiment using only already qualified FMC branches and no arbitrary nonzero SWAP bottom-head extension beyond established authority.

Formal same-runtime performance should remain secondary until that concurrent hydrological composition is qualified.

D21 and D22 remain unchanged.

No application acceptance or production ROM authority is created.

Production ROM remains unauthorized.
