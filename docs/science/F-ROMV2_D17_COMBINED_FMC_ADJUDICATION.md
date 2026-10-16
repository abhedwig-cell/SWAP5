# F-ROMV2 D17 combined FMC adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D17  
**Decision:** **FMC_COMBINED_SURFACE_GROUNDWATER_RETAINS_RESEARCH_CANDIDACY**

## Question

D17 asks whether the independently retained FMC surface branch from D16 and groundwater-front branch from D13 remain physically coherent and hydrologically competitive when they operate simultaneously in one B01 column.

The experiment is deliberately bounded. Surface-connected fronts and groundwater-connected fronts remain separated throughout the test. Contact, merge, falling slugs, dry-bin activation, ponding/runoff and ET/root uptake are excluded.

## Authority

The composition uses the already frozen FMC/SMVE finite-water-content controls:

- B01 hydraulic functions;
- 200 moisture-content bins;
- one 10 s process step per observation;
- D16 `I_DEEP` connected infiltration fronts;
- D13 `G25` fixed-water-table groundwater fronts;
- published gray-bin throughflow priority;
- Eq. 18 surface-front motion;
- Eq. 21 groundwater-front motion;
- conservative capillary relaxation.

The primary literature explicitly treats finite-water-content flow as a mass-conservative ODE/front system for infiltration, redistribution, falling slugs and groundwater-table effects. D17 only tests a subset of that published process envelope.

## Staged preflight

Before any SWAP trajectory was generated, all four frozen composition histories passed the FMC-only preflight.

The minimum surface-groundwater separation decreases from about **14.267 cm** initially to **14.019 cm**, but remains strictly positive.

Maximum absolute preflight step mass residual is approximately **1.17e-14 cm**, below the frozen **1e-12 cm** gate.

No contact or merge transition occurs.

## Primary execution

Primary successful workflow:

- run **35458378169**;
- job **105937630806**;
- executed head `6e6e35f5c8205d63603ead900158155589a84b06`;
- artifact **10589330827**;
- artifact digest
  `sha256:18c7fa490be04fd1f3d2fe67b42ebaffe84ba5d8edeecc6859cf5393137b889a`.

Frozen payload digests:

- preflight result:
  `996f05ea8f077ca0306bdc791204e840ed3ba749e52e2bae69efdb3bad8d597f`;
- hydrological result:
  `6e835c4d0528fe8334daea4e652ab2668c46e44d8757725e3abb221a9f9ea3c8`;
- R16 O0/O2:
  `9f5b60ba7a29b908b989f58fff5760d1b5894315a353a0567c66a1cdc1961da5`;
- R2 O0/O2:
  `6114a27ba539395dcddca5498426a104fe15aecad4d9ab11322ed97094e765f8`.

Two earlier runs failed only in analyzer data handling after preflight and trajectory generation. The first left raw node-map handling vulnerable; the second exposed incorrect nested node indexing. The final repair changed no hydrological equation, forcing, state, bin count, process step, initial profile or decision gate.

## Pooled hydrological result

Relative to R16:

| metric | FMC | R2 |
|---|---:|---:|
| total-storage RMSE | 0.009426 cm | 0.024039 cm |
| cumulative bottom-exchange RMSE | 0.009426 cm | 0.024039 cm |
| mapped 16-cell theta RMSE | 0.000595 | 0.045552 |
| upper 0-80 cm storage RMSE | 0.007121 cm | 0.002176 cm |
| lower 80-160 cm storage RMSE | 0.004072 cm | 0.021863 cm |
| terminal bottom-flux RMSE | 8.682 cm d-1 | 21.484 cm d-1 |
| bottom-flux sign errors | 0/64 | 0/64 |

All five preregistered decision gates pass:

1. total-storage RMSE;
2. cumulative-bottom-exchange RMSE;
3. mapped-profile theta RMSE;
4. bottom-flux magnitude RMSE;
5. bottom-flux sign errors.

The frozen decision is therefore:

`FMC_COMBINED_SURFACE_GROUNDWATER_RETAINS_RESEARCH_CANDIDACY`.

## Interpretation

This is stronger evidence than D13 or D16 separately.

FMC now retains research candidacy when top infiltration and a shallow fixed groundwater influence are active simultaneously, while the two front systems remain spatially separated.

The profile result is especially strong relative to R2. The mapped 10-cm theta RMSE is about 1.3% of the R2 value.

The upper-storage metric is an important counterpoint: R2 has smaller upper-zone storage RMSE in this short pulse experiment. D17 was not preregistered to require FMC dominance on every diagnostic scalar; the profile view is the resolved 16-cell theta metric. This prevents post-hoc redefinition of the decision.

Bottom-flux magnitude also remains imperfect in absolute terms. An RMSE of about **8.68 cm d-1** is materially nonzero even though it is much smaller than the R2 value and sign is always correct.

## Purpose-dependent boundary

### Regional / long-term balance

**Not yet qualified.**

D17 spans only 160 s and does not test seasonal accumulation, ET or recharge under realistic forcing.

### Groundwater-coupled many-column simulation

**Broader research candidacy retained, not qualified.**

The surface and groundwater branches now compose positively under a fixed-water-table, separated-front envelope.

### Fast event / threshold processes

**Not qualified.**

There is no ponding/runoff and no surface-groundwater contact or merge event.

### Operational soil moisture / drought

**Not tested.**

### Scientific process/extreme inference

**Not qualified.**

## Next boundary

D17 should not be extended by changing bins, process step, lambda, initial profile or forcing factors.

The next distinct experiment is the transition D17 intentionally avoids:

> **surface-front / groundwater-front contact or falling-slug-to-groundwater merge under primary-source-bound semantics.**

That transition must be preregistered separately before exposure.

Only after FMC survives a contact/merge transition or a substantially longer realistic hydrological horizon does a formal same-runtime cost frontier become worth measuring.

Production ROM remains unauthorized.
