# F-PE-ELASTIC01 — soil-driven elastic storage preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_RESULTS

Authority at branch creation:

`integration/f-ci-canonical@044e686d1899adf3a631716d09743aa4fce0818f`

Work branch:

`work/f-pe-elastic01-soil-storage`

## Motivation

Pim Dik proposes using an elastic storage coefficient of order `1e-6` in future SWAP calculations.

The intended end state is not a single global numerical constant. If elastic storage is retained in SWAP5, its production value should ultimately be driven by soil properties or by a soil-dependent bounded rule.

This workunit tests that proposition without presupposing that the mechanism is genuinely physical. A soil-dependent relation is only acceptable if the evidence distinguishes physical storage from numerical regularization.

## Research questions

1. Does elastic storage around `1e-6` improve nonlinear robustness and/or computational work on the corrected current SWAP5 authority?
2. What is the lowest elastic-storage magnitude required for robust calculation for each tested soil/regime combination?
3. Is variation in that required magnitude systematically related to hydraulic soil parameters?
4. Can a soil-driven rule be defined that generalizes to holdout soils and regimes without materially changing relevant hydrological outputs?
5. Is the observed benefit consistent with physical elastic storage, or is it better classified as bounded numerical regularization?

## Frozen candidate sweep

Initial logarithmic sweep:

- `0` or the exact current-reference behaviour where a literal zero is not representable;
- `1e-8`;
- `1e-7`;
- `1e-6`;
- `1e-5`.

The sweep may be bracket-refined only after the initial results are recorded. No candidate may be silently removed because it performs poorly.

`1e-6` is the nominated candidate from Pim Dik, not a preselected winner.

## Test populations

Phase A shall use the existing repository-backed BOFEK hydraulic archetype bank and its dry, transition, moist, wet and ponding regimes.

The current BOFEK testbank is a screening bank, not an authoritative complete BOFEK catalogue. Therefore Phase A can establish numerical and mechanistic evidence, but it cannot by itself justify a BOFEK-ID-specific production mapping.

Wet and ponding cases are mandatory because the former top-boundary/Jacobian defect has now been corrected. Elastic storage must not receive credit for masking a defect that no longer exists.

Phase B, if Phase A is promising, shall use a broader authoritative soil/profile population with a frozen calibration/holdout split before deriving a soil relation.

## Soil predictors to retain

At minimum preserve, where available:

- saturated water content / porosity `theta_s`;
- residual water content `theta_r`;
- van Genuchten `alpha`;
- van Genuchten `n`;
- saturated conductivity `Ksat`;
- conductivity-shape parameter `lambda`;
- layer thickness and profile composition;
- derived retention/capacity descriptors near saturation;
- derived conductivity descriptors near saturation.

Additional predictors may be introduced only with a documented physical or numerical rationale.

## Primary measurements

For every soil/regime/candidate combination record:

- success/failure;
- accepted timesteps;
- rejected trials/retries;
- nonlinear iterations;
- backtracking count;
- minimum accepted timestep;
- runtime where the runner is suitable for performance comparison;
- terminal pressure head profile;
- groundwater level where defined;
- runoff/ponding;
- drainage;
- bottom flux;
- actual evapotranspiration where active;
- total water-balance residual.

Prefer deterministic work counters over wall-clock time for first-stage qualification.

## Reference and accuracy boundary

The current corrected Reference calculation remains the scientific reference.

A candidate may reduce computational work only if deviations in hydrological state and flux quantities remain inside preregistered tolerances. Tolerances must be stated before inspecting candidate outcomes.

No production claim may be based on solver success alone.

## Derived quantity: minimum required elastic storage

For each soil/regime case define:

`S_e,min` = the smallest tested elastic-storage coefficient that satisfies both:

1. the robustness criterion;
2. the hydrological-equivalence criterion.

If the unmodified Reference already satisfies those criteria, `S_e,min = 0/reference`; the study must not force a positive coefficient.

This derived response is the primary target for the later soil-parameter relation.

## Hypotheses

H1. `1e-6` improves robustness or work for at least part of the difficult wet/ponding population.

H2. The useful elastic-storage magnitude is not constant across soils.

H3. Variation in `S_e,min` can be explained materially better by hydraulic soil properties than by a single global value.

H4. A soil-driven rule can reproduce the robustness gain on holdout profiles without materially increasing hydrological error.

H5. If the required coefficient correlates primarily with numerical stiffness indicators rather than physically interpretable storage properties, the mechanism shall be classified as numerical regularization rather than physical elastic storage.

## Model-selection discipline

The first soil-driven model shall be deliberately simple and interpretable.

Candidate forms may include:

- bounded log-linear relation;
- small decision tree;
- monotone piecewise rule;
- hydraulic-archetype mapping only as a diagnostic comparator.

No high-capacity regression or black-box model is allowed before a simple relation has been tested and its failure documented.

Calibration and holdout profiles must remain separated. Predictor selection and thresholds are frozen on calibration data before holdout evaluation.

## Production decision classes

Possible outcomes are intentionally separated:

### A. PHYSICAL_SOIL_PARAMETER

Evidence supports interpretation as an actual soil storage property and a defensible soil-property mapping.

### B. SOIL_DRIVEN_NUMERICAL_REGULARIZATION

A soil-dependent coefficient is useful and generalizes, but evidence does not justify calling it physical storage.

### C. GLOBAL_BOUNDED_REGULARIZATION

A single value such as `1e-6` is robust and useful, but soil dependence does not add reproducible value.

### D. NO_ADMISSION

Benefits are too small, accuracy costs are too large, generalization fails, or effects are inconsistent.

No class is preferred in advance.

## Production boundary

This preregistration authorizes experiment and instrumentation work only.

It does not authorize:

- changing the SWAP5 default coefficient;
- hard-coding `1e-6`;
- introducing a BOFEK lookup table;
- claiming physical meaning from a numerical correlation;
- changing production `src/**` behaviour before qualification.

Any production implementation requires a separate qualification/admission step on then-current canonical authority.

## Relation to prior BOFEK numerical-policy work

F-PE-BOFEK-PRACTICAL01–03 found real soil/regime-dependent timestep structure but no sufficiently robust static numerical policy for production.

F-PE-ELASTIC01 asks a different question: whether elastic storage changes the stiffness/conditioning of the Richards solve in a way that is both bounded in hydrological effect and predictable from soil properties.

The previous negative static-timestep result is therefore retained as evidence, not treated as a reason to skip this line.
