# F-ROMV2 D19 — GARTO/LGAR literature-gap reconciliation

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D19  
**Decision:** **GARTO_FAITHFUL_COMPARATOR_JUSTIFIED_AS_DISTINCT_DYNAMIC_WT_CANDIDATE**

## 1. Why D19 exists

D11 performed a post-D10 state-of-the-art filter and selected FMC/SMVE as the next physical reduction class.

That historical decision remains valid for the set of candidate families that D11 actually reviewed.

D19 found a material omission from that reviewed set:

- GARTO — Green-Ampt with Redistribution combined with Talbot-Ogden concepts and explicit shallow/dynamic groundwater;
- LGAR — the later layered Green-Ampt with Redistribution extension.

This workunit therefore expands the literature authority rather than reclassifying D11.

No new reduced model is implemented in D19.

## 2. Primary GARTO authority

Primary source:

Lai, W., Ogden, F. L., Steinke, R. C., & Talbot, C. A. (2015).  
*An efficient and guaranteed stable numerical method for continuous modeling of infiltration and redistribution with a shallow dynamic water table.*  
Water Resources Research, 51, 1514–1528.  
DOI: 10.1002/2014WR016487.

The paper presents GARTO as a one-dimensional continuous infiltration/redistribution method for homogeneous soil with shallow dynamic groundwater.

Its governing state is a set of discrete wetting fronts rather than a full spatial Richards grid.

It combines:

- Green-Ampt infiltration;
- GAR redistribution;
- Talbot-Ogden style multiple-front infiltration;
- conservative surface-front merging;
- capillary groundwater fronts;
- a dynamic-water-table groundwater-front equation.

The method is expressed as ODE/front dynamics rather than a global nonlinear Richards solve.

## 3. Why GARTO is distinct from the D12-D17 FMC route

GARTO and FMC/SMVE share scientific ancestry, but they are not the same architecture.

The T-O/FMC route discretizes moisture-content space with many finite-water-content states. The D12-D17 research route froze 200 bins.

GARTO deliberately reduces the surface representation.

The primary GARTO paper states that:

- maximum surface wetting-front capacity is a model parameter;
- the reported simulations used (N=10);
- no more than three surface wetting fronts were actually active in the reported tests;
- wetting fronts merge conservatively before later rainfall pulses;
- the scheme was designed to be computationally cheaper than the more highly discretized T-O method.

This makes GARTO a genuinely different cost-fidelity point.

It is not simply “FMC with fewer bins”.

## 4. Important groundwater nuance

The low-state argument must not be overstated.

The GARTO surface representation avoids a complete 200-bin surface moisture discretization, but its groundwater treatment still uses capillary groundwater fronts/bins inherited from the Talbot-Ogden family.

The primary paper explicitly notes that the sudden infiltration-rate changes that occur when surface fronts encounter groundwater fronts can be smoothed by increasing the number of bins used in the groundwater calculations.

Therefore groundwater discretization remains scientifically consequential.

The accessible primary article does not provide enough unambiguous operational detail to freeze that discretization for a SWAP comparator from prose alone.

D20 must resolve it from primary equations and, where provenance is acceptable, source/oracle material before any SWAP development trajectory is used.

This is a source-authority requirement, not a free tuning parameter.

## 5. Surface and redistribution physics

GARTO uses a GAR-like redistribution ODE when rainfall is below saturated hydraulic conductivity.

The published simulations use:

- rectangular wetting-front profiles;
- (p=1.0) when rainfall is positive;
- (p=1.7) during zero-rainfall redistribution.

When rainfall exceeds saturated hydraulic conductivity, multiple active surface fronts may infiltrate simultaneously using a Talbot-Ogden-like front equation.

Surface-water demand is limited by available water, and front interactions are handled by conservative merging.

This architecture therefore carries explicit rainfall-history memory in a small number of front states rather than in a vertically discretized pressure-head vector.

## 6. Dynamic groundwater authority

GARTO includes capillary groundwater fronts and a water-table-depth dependent groundwater-front ODE.

The primary paper states:

- groundwater-front motion reacts to changing water-table depth;
- fronts move toward their hydrostatic positions;
- a surface wetting front that touches a groundwater front becomes groundwater;
- the method can represent infiltration-excess and saturation-excess behavior.

The validation includes:

- shallow fixed water tables;
- multiple rainfall pulses;
- surface runoff;
- a test with a water table rising at 5 cm h-1.

This is a stronger direct published moving-water-table precedent than the current SWAP5 D17 envelope, which is positive only for a fixed water table with separated surface and groundwater fronts.

## 7. Purpose-dependent external fidelity

The external GARTO results are valuable as **precedent**, not as SWAP thresholds.

The primary study reports increasing cumulative-infiltration discrepancy as the water table becomes shallower.

Reported overall mean absolute cumulative-infiltration differences versus FUCG Richards are approximately:

| Water-table depth | Published mean absolute difference |
|---|---:|
| (16|\psi_b|) | 1.79% |
| (8|\psi_b|) | 2.55% |
| (4|\psi_b|) | 4.04% |
| (2|\psi_b|) | 5.40% |

Individual very shallow cases can differ more strongly.

These values demonstrate an application-relevant fidelity trade-off.

They are **not** adopted as SWAP5 acceptance thresholds.

## 8. External computational precedent

The same paper reports per-step GARTO runtimes from 0.27 to 1.74 microseconds and FUCG Richards runtimes from 13.78 to 86.55 microseconds on its reported platform.

The reported study gives:

- more than 139x per-step advantage in tests without a near-surface water table;
- approximately 8–71x in the shallow-water-table tests;
- a 10 s GARTO time step;
- a recommendation of time steps below one minute for accuracy.

These figures are scientifically important motivation because they show that GARTO was built specifically around the cost-fidelity question that motivates F-ROMV2.

They are not a SWAP5 speedup claim.

Any SWAP5 performance statement still requires a same-runtime implementation and admitted performance host.

## 9. B01 constitutive mapping

The published GARTO tests use Brooks-Corey soil functions.

However, the primary paper explicitly states that other retention models, including Van Genuchten, can be used.

For Van Genuchten, the effective capillary drive must be obtained by numerical integration or by parameter conversion.

For SWAP5 B01, D19 forbids a Brooks-Corey fit.

The appropriate clean comparison is:

- retain the existing B01 Van Genuchten/Mualem constitutive functions;
- evaluate GARTO's effective capillary-drive integral numerically;
- freeze the quadrature/convergence rule before SWAP trajectory evidence.

This preserves the B01 material identity and avoids introducing a new calibration layer merely to make GARTO convenient.

## 10. LGAR

Primary source:

La Follette, P., Ogden, F. L., & Jan, A. (2023).  
*Layered Green and Ampt Infiltration With Redistribution.*  
Water Resources Research, 59.  
DOI: 10.1029/2022WR033742.

LGAR is highly relevant to the longer-term SWAP5 problem because it extends continuous GAR-style infiltration to an arbitrary number of soil layers.

Its published strengths include:

- multiple rainfall events;
- layered soil hydraulic properties;
- explicit mass conservation;
- multi-month comparisons with HYDRUS-1D;
- published open source/data provenance.

However, the primary LGAR derivation explicitly assumes **no influence of the groundwater table on soil moisture**.

Its intended envelope is especially associated with arid or semi-arid conditions where cumulative potential evapotranspiration exceeds cumulative precipitation.

LGAR therefore does not replace GARTO for the current shallow/dynamic-groundwater question.

It is retained as a distinct future layered/deep-groundwater atmospheric-boundary precedent.

## 11. Secondary implementation evidence

HydPy documents a GARTO implementation that was checked against original C code provided by Fred Ogden and Cary Talbot.

That is useful secondary provenance.

HydPy also documents an important limitation: its implementation generally assumes a hydrostatic groundwater table, whereas complete GARTO includes dynamically moving groundwater fronts.

HydPy can therefore be used as a secondary surface-GARTO oracle after provenance review.

It cannot by itself establish faithful dynamic-groundwater GARTO authority.

## 12. Comparison after D19

### FMC/SMVE

Current SWAP5 status:

**bounded research candidacy retained through D17**.

Strengths already shown inside SWAP5:

- resolved profile fidelity;
- explicit finite-volume accounting;
- simultaneous surface and fixed-water-table groundwater behavior;
- better D17 balance/profile/bottom-flux fidelity than R2.

Open:

- moving-water-table SWAP comparison;
- contact/merge hydrology;
- longer realistic horizon;
- ET/root uptake;
- runtime.

### GARTO

D19 classification:

**distinct staged comparator justified**.

Potential advantage:

- markedly lower surface-state complexity;
- direct dynamic-water-table authority;
- strong external runtime precedent;
- continuous rainfall/redistribution and runoff semantics.

Open:

- exact source/equation transcription;
- groundwater-front/bin discretization;
- B01 Van Genuchten capillary-drive integration;
- SWAP5 hydrological fidelity.

### LGAR

D19 classification:

**layered/deep-water-table complement, not current dynamic-WT comparator**.

### R2/R4/R8

Remain the transparent coarse-Richards physical-reduction comparators.

## 13. D20 authority

D20 is authorized, but only as a staged literature-faithful workunit.

### Stage 1 — source and equation authority

Before any SWAP trajectory:

1. transcribe and test primary GARTO equations 6, 8, 9 and 10;
2. freeze front ordering, surface-water allocation and conservative merge ordering;
3. reconcile groundwater-front/bin state representation and the discretization used by a published groundwater benchmark;
4. reconcile any available original-code semantics under explicit provenance;
5. freeze (N=10) maximum surface fronts for the first faithful benchmark;
6. freeze 10 s process step for that benchmark.

Any ambiguity that materially affects groundwater behavior is a blocker.

It is not permission to tune against SWAP.

### Stage 2 — published benchmark

Before B01 mapping, reproduce at least one primary-source GARTO test using the published Brooks-Corey parameterization.

The benchmark must include a shallow or moving water table.

It must demonstrate:

- ordered, finite front states;
- explicit mass closure;
- correct front-merging direction;
- correct response to water-table motion;
- appropriate infiltration/runoff direction;
- agreement with the published result at the level justified by the source data.

### Stage 3 — bounded B01 development comparator

Only after Stage 2 passes:

- homogeneous B01;
- no hysteresis;
- no ET/root uptake;
- B01 Van Genuchten/Mualem constitutive functions;
- numerical effective-capillary-drive integration frozen before SWAP evidence;
- only reconciled GARTO surface/water-table boundary semantics;
- R16 and R2 comparators;
- D17 FMC retained as an architecture comparator where envelopes overlap.

No application acceptance follows from D20.

## 14. Firewalls

D19 does not authorize:

- retroactive reclassification of D11;
- using published GARTO percentage errors as SWAP tolerances;
- importing external GARTO/FUCG runtime ratios as SWAP speedups;
- fitting B01 Brooks-Corey parameters to make GARTO work;
- tuning groundwater bins on SWAP outcomes;
- ad-hoc combination of LGAR layered semantics with GARTO groundwater semantics;
- ET/root-uptake claims;
- production ROM.

Production ROM remains unauthorized.
