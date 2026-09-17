# PUB-SG scientific contract

Working title: **When does vadose-zone heterogeneity need to be retained below the groundwater-grid scale?**

Status: **conditional research-design contract**

Publication owner: `PUB-SG`

Doctoral mapping: `RQ5 / SCALE`, conditional

Dependencies: qualified `PUB-GC` coupling semantics; `PUB-RC` acceleration may be used as infrastructure but is not required.

## 1. Central research question

> Under what hydrologic conditions does explicit representation of heterogeneous dynamic vadose-zone columns within a coarser groundwater cell produce materially different coupled behaviour from an effective or homogenized vadose-zone representation?

This paper exists only if the answer is scientifically nontrivial. N:1 mapping by itself is not a publication contribution.

## 2. Scientific problem

For multiple SWAP columns `i` with areas `A_i` mapped to one groundwater cell and exposed to groundwater head `h`, the explicit aggregated exchange is

```text
V_explicit(h) = sum_i A_i Q_i(h)
```

where `Q_i` is the whole-window dynamic response of each heterogeneous column.

A reduced representation replaces those columns by one effective column:

```text
V_effective(h) = A_total Q_eff(h)
```

The key issue is that nonlinear soil-water, evapotranspiration, root-zone, lower-boundary and management responses imply that in general

```text
sum_i A_i Q_i(h) != A_total Q_eff(h)
```

for a naively averaged parameterization.

The paper must determine when this inequality is practically important for groundwater heads, vadose-zone states and water balances, not merely demonstrate that mathematical nonlinearity exists.

## 3. Novelty boundary

Regional groundwater models already use multiple land-surface or SVAT units within groundwater cells. MetaSWAP/iMOD and SIMGRO are direct predecessors and must be central comparators. `PUB-SG` therefore cannot claim N:1 mapping, area-weighted aggregation or subgrid SVAT representation as new.

The candidate contribution is narrower:

> evaluating the hydrologic value of retaining multiple **full dynamic SWAP columns** below the groundwater-grid scale, using a coupling framework that preserves each column's own state and whole-window nonlinear response.

The paper should compare this against scientifically credible reduced/effective representations rather than an intentionally poor arithmetic average.

## 4. Protected primary contribution

If supported by results, the paper may contribute:

1. a quantitative regime map for when subgrid vadose-zone heterogeneity materially influences coupled groundwater-vadose behaviour;
2. identification of the mechanisms responsible for that sensitivity;
3. evaluation of effective/homogenized alternatives against explicit dynamic subcolumns;
4. guidance on when groundwater-grid refinement is unnecessary because heterogeneity can be retained through N:1 vadose-zone composition, and when simpler aggregation is adequate.

No universal recommendation is authorized in advance.

## 5. Hypotheses

### H1. Dynamic aggregation error grows with nonlinear contrast

Differences between explicit and effective representations increase when subcolumns differ strongly in hydraulic properties, rooting/vegetation, surface forcing or management and when groundwater feedback crosses nonlinear response regimes.

### H2. Shallow groundwater amplifies subgrid relevance

Subgrid differences matter more when capillary rise, root-zone access to groundwater or lower-boundary switching creates strong two-way feedback than when groundwater is deep and recharge is effectively one-way.

### H3. Effective representations may work in identifiable regimes

A carefully constructed effective column may reproduce aggregated fluxes and groundwater response adequately in weak-feedback or low-contrast regimes.

The paper must seek these successful simplifications, not only failure cases.

### H4. Temporal averaging and spatial averaging interact

Errors from coarse spatial representation may depend on coupling-window duration and event timing, especially during wetting fronts, drought recovery, irrigation or rapidly changing groundwater heads.

This interaction must not be confused with base coupling error owned by `PUB-GC`.

## 6. Minimum experiment set

### E0. Conservation-only N:1 baseline

Inherited from `PUB-GC`: verify that area-weighted multiple-column exchange is conservatively transferred to one groundwater cell. No hydrologic heterogeneity claim is made here.

### E1. Two-column mechanism experiments

Start with interpretable 50/50 or other controlled mixtures, for example:

- coarse versus fine soil;
- shallow-rooted versus deep-rooted vegetation;
- irrigated versus non-irrigated management;
- wet versus dry antecedent state.

Compare explicit aggregation against at least one credible effective representation.

Purpose: identify mechanisms before large ensembles.

### E2. Groundwater-depth and forcing matrix

Vary:

- mean groundwater depth;
- groundwater storage response;
- rainfall/irrigation pulse intensity;
- evaporative demand;
- season/antecedent storage;
- heterogeneity contrast.

Primary outputs:

- cumulative exchange difference;
- groundwater-head difference;
- root-zone storage difference;
- evapotranspiration/transpiration difference where scientifically justified;
- timing and sign of capillary rise/recharge transitions.

### E3. Effective-representation alternatives

Compare explicit subcolumns against multiple reduction strategies where feasible:

1. arithmetic/area-weighted parameter averaging;
2. dominant-soil or dominant-land-use representation;
3. calibrated effective column for selected target metrics;
4. reduced MetaSWAP-like or other established regional representation where scientifically comparable.

The purpose is not to make explicit SWAP win by construction.

### E4. Ensemble/regime map

Use a designed ensemble to identify dimensionless or interpretable predictors of aggregation error, for example contrast in storage capacity, conductivity, rooting depth, capillary response or groundwater coupling strength.

The preferred result is a regime map rather than a single case-study difference.

### E5. Realistic regional demonstration

Apply the identified mechanisms to a real or realistic regional groundwater domain with heterogeneous soil/land-use units mapped N:1 to MODFLOW cells.

The case should test whether the synthetic regime findings survive realistic spatial and temporal forcing.

## 7. Error decomposition

The study must separate at least:

```text
coupling error
solver error
spatial aggregation error
parameter/effective-model error
```

A strict or sufficiently converged `PUB-GC` configuration should be used when estimating subgrid aggregation effects so that coupling error is not mislabelled as heterogeneity impact.

If `PUB-RC` is used for efficiency, its result must be verified against the same accepted coupled solution.

## 8. Scale and performance

Large numbers of SWAP columns may create a computational challenge. Performance and parallelization can be reported as feasibility evidence, but they are not automatically the scientific contribution.

Relevant diagnostics:

- columns per groundwater cell;
- total column count;
- subsystem solve counts;
- load imbalance from heterogeneous solver difficulty;
- memory footprint;
- wall time and parallel efficiency where implemented.

A standalone high-performance-computing claim would require a separate publication decision.

## 9. Falsification criteria

`PUB-SG` should **not** become a standalone paper if:

1. a scientifically credible effective column reproduces the relevant coupled results across the intended regimes;
2. differences are small relative to observational/parameter uncertainty and lack a coherent mechanism;
3. the only interesting result is that N:1 mapping is technically possible;
4. observed differences are dominated by coupling-window or solver error;
5. the result depends on unrealistic parameter contrasts;
6. no useful generalization beyond one case study can be made.

If explicit heterogeneity usually proves unnecessary, that may still be an important result but the publication framing should be reconsidered rather than forced.

## 10. Hard publication firewall

Inherited from `PUB-GC`:

- correct whole-window exchange;
- same-origin replay;
- N:1 conservation/mapping semantics.

Inherited from `PUB-RC` if used:

- response-assisted acceleration.

Owned by `PUB-SG`:

- effect of explicit subgrid heterogeneity on hydrologic results;
- comparison with effective representations;
- regime boundaries for when heterogeneity matters.

Solver comparisons remain `PUB-SQ`.

## 11. Telemetry to preserve now

For every potential `PUB-SG` experiment preserve:

- groundwater-cell ID and area;
- all mapped SWAP column IDs and areas;
- soil, vegetation, management and forcing fingerprints;
- initial column states;
- effective-model construction method;
- whole-window exchange per column;
- aggregated exchange;
- groundwater head;
- key root-zone/storage/ET diagnostics;
- coupling-window and solver settings;
- strict-reference identifiers;
- computational cost.

## 12. Candidate manuscript structure

1. Subgrid vadose-zone representation in regional groundwater modelling
2. Existing SVAT/MetaSWAP/SIMGRO approaches
3. Dynamic explicit-column and effective-column formulations
4. Controlled two-column experiments
5. Regime/ensemble analysis
6. Regional demonstration
7. Computational feasibility
8. Discussion: when explicit heterogeneity is worth retaining
9. Conclusions

## 13. Publication-admission gates

- [ ] `PUB-GC` N:1 conservation is independently established;
- [ ] at least one credible effective comparator is defined;
- [ ] spatial aggregation error is separated from coupling/solver error;
- [ ] mechanism experiments precede regional demonstration;
- [ ] effect sizes are materially hydrologic, not only numerically detectable;
- [ ] both success and failure of homogenization are reported;
- [ ] regional case supports rather than substitutes for the mechanism analysis;
- [ ] results are distinct from MetaSWAP/SIMGRO's established N:1 concept;
- [ ] the study can be abandoned cleanly if no distinct effect is found.

## 14. Initial literature anchors

The eventual review should treat as core predecessors:

- Van Walsum and Groenendijk (2008), MetaSWAP quasi-steady unsaturated-zone representation, DOI 10.2136/vzj2007.0146;
- Van Walsum and Veldhuizen (2011), SIMGRO shared-state integration and regional hydrologic modelling, DOI 10.1016/j.jhydrol.2011.08.036;
- current iMOD/MetaSWAP technical documentation for SVAT-to-MODFLOW subgrid mapping;
- literature on effective/upscaled soil hydraulic properties and land-surface subgrid heterogeneity where relevant.

No novelty claim is authorized until the literature review and mechanism experiments justify a standalone paper.
