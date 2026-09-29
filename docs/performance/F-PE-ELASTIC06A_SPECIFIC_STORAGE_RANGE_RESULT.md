# F-PE-ELASTIC06A — quantitative specific-storage range synthesis

Date: 2026-09-29

Status: EVIDENCE_SYNTHESIS_NO_PRODUCTION_RULE

## Question

How should Pim Dik's proposed `ELAS = 1e-6 cm^-1` be interpreted physically, and does current literature support one universal value across Dutch soils?

## Unit identity

`1e-6 cm^-1 = 1e-4 m^-1`.

Legacy SWAP ELAS is therefore directly comparable in magnitude to hydrogeological specific storage `Ss` when interpreted on the saturated constitutive branch.

## Specific-storage equation

A standard uniaxial formulation is:

`Ss = rho_w g (alpha_matrix + n beta_w)`

where:

- `alpha_matrix` is matrix compressibility;
- `n` is porosity;
- `beta_w` is water compressibility.

At typical soil porosity, water compressibility alone gives only a small fraction of `1e-4 m^-1`. A value of `1e-4 m^-1` therefore primarily expresses soil/aquifer-matrix elasticity.

Primary theory source:
Donald G. Jorgensen (1980), USGS Water-Supply Paper 2064,
DOI 10.3133/wsp2064.

## Broad hydrogeological evidence

Chowdhury et al. (2022), *Multifactor analysis of specific storage estimates and implications for transient groundwater modelling*, Hydrogeology Journal 30, 2183-2204,
DOI 10.1007/s10040-022-02535-z, compiled 430 Ss values from 183 studies.

Reported population:
- total range: `3.2e-9 .. 6e-3 m^-1`;
- geometric mean: `1.1e-5 m^-1`;
- more than 67% of observations were in the `1e-6` to `1e-5 m^-1` orders;
- values around `1e-4 m^-1` occur for glacial till and sandy lithologies, particularly shallow/thin strata.

Interpretation:
Pim's `1e-4 m^-1` is physically plausible, but it lies above the central tendency of the broad hydrogeological compilation and should not be treated as a universal mineral-soil value without further evidence.

## Clay-rich material and scale dependence

Smith, van der Kamp and Hendry (2013), Water Resources Research,
DOI 10.1002/wrcr.20084, found that clay/aquitard Ss estimates depend strongly on measurement method and strain scale:

- in-situ estimates for clay-rich materials were commonly `1e-6 .. 1e-5 m^-1`;
- laboratory estimates were commonly around `1e-4 m^-1` and higher.

This is important for SWAP ELAS: an oedometer-derived value can represent a different deformation scale from small-strain field elastic storage.

## Agricultural topsoil mechanical evidence

Reichert et al. (2018), *Compressibility and elasticity of subtropical no-till soils varying in granulometry, organic matter, bulk density and moisture*, Catena 165, 345-357,
DOI 10.1016/j.catena.2018.02.014, studied 536 undisturbed agricultural-soil samples.

Their elastic/decompression behaviour depends significantly on:

- bulk density;
- soil organic matter;
- clay content;
- water content/tension.

Bulk density generally suppresses compressibility/elastic recovery while organic matter, clay and moisture tend to increase it.

This supports using pedological/mechanical soil descriptors for ELAS priors. It does not provide a directly transferable SWAP ELAS formula.

## Very compressible shallow soils

Recent oedometer-based shallow-soil work reports specific-storage values of roughly `3e-3 .. 1.2e-2 m^-1` under low effective-stress extrapolation.

These values are one to two orders above Pim's `1e-4 m^-1`.

Such laboratory values can contain deformation behaviour beyond the small-strain elastic regime used in classical groundwater storage, so they should be treated as an upper/deformable-soil regime rather than copied directly into SWAP.

## Peat

Peat is clearly a separate physical regime.

Camporese et al. (2006), *Hydrological modeling in swelling/shrinking peat soils*, Water Resources Research,
DOI 10.1029/2005WR004495, explicitly treats elastic storage as a porous-matrix compressibility term and shows that it becomes important in saturated peat.

More recent peat measurements report Ss values around `2.9e-3 .. 1.1e-2 m^-1`, with compressibility strongly related to humification and dry bulk density.

A constant mineral-soil ELAS default is therefore not defensible for peat.

## Consequence for a SWAP5 parameter policy

Current evidence supports a hierarchy rather than one global scalar:

1. ELAS remains a soil/material parameter.
2. `1e-6 cm^-1` is a plausible candidate/reference magnitude for some unconsolidated mineral soils.
3. Stiff/dense mineral materials may physically require smaller values.
4. soft clayey/agricultural materials can require larger values depending on effective stress and deformation scale.
5. peat/organic soils require a separate regime and may ultimately require state-dependent deformation rather than only a scalar ELAS.

## Candidate descriptor set

The physically motivated descriptor set remains:

- dry bulk density;
- organic matter;
- clay/lutum fraction;
- porosity or a defensibly derived porosity;
- horizon/depth;
- water/moisture state;
- if available, preconsolidation stress or recompression/constrained modulus.

Hydraulic MvG parameters may be retained for numerical-risk diagnostics but should not be treated as causal mechanical predictors.

## Decision

Do not replace the current ELAS research with a fitted universal MvG-to-ELAS relation.

Classification:

`SOIL_DEPENDENT_PHYSICAL_PRIOR_REQUIRED_1E6_CM_INV_PLAUSIBLE_NOT_UNIVERSAL`.
