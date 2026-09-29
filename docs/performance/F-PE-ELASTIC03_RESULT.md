# F-PE-ELASTIC03 — physical predictor source audit result

Date: 2026-09-29

Status: PHYSICAL_SOURCE_GAP_CONFIRMED

Workflow: `36519761839`
Job: `109249829819`
Conclusion: PASS

## Official Staringreeks package audit

The official NHI Staringreeks 2018 package contains:

### unit_properties_2018.csv
- SHA-256 `7ece686bfe5af68375944d5fdacf371843d6deefdb5db2db594cbf7ab359cbb1`
- 144 rows
- variables `k`, `wc`, `z1`, `z2` over pressure-head points
- derived hydraulic properties only

### allsamples_2018.csv
- SHA-256 `0beb552f0e9a16f3ce2519ab5694897ef659f5ad4b24d40a387cfd1b2d64bc2b`
- 999 rows
- columns `unit,numid,wcr,wcs,alpha,npar,lambda,ksfit`
- individual hydraulic fit parameter sets only

### staringreeks_2018.csv
- SHA-256 `ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494`
- 36 rows
- class-average MvG hydraulic parameter sets

No audited source member provides dry bulk density, organic matter, clay/lutum, silt/leem, sand fraction, M50, compressibility or elastic modulus.

## Consequence

The official Staringreeks hydraulic package cannot by itself provide a physically derived ELAS value.

A relation `ELAS = f(alpha,n,lambda,Ksat,...)` would therefore be an empirical correlation between hydraulic-fit parameters and elastic storage, not a mechanistic specific-storage relation.

## Physical definition

The relevant hydrological quantity is specific elastic storage `Ss [L^-1]`.

A standard slightly-compressible porous-medium expression is:

`Ss = rho_w * g * (alpha_matrix + n * beta_w)`

where:
- `alpha_matrix` is bulk/formation compressibility;
- `n` is porosity;
- `beta_w` is water compressibility.

Published Richards-equation formulations likewise add specific storage in the saturated or near-saturated storage term. The openRE formulation explicitly distinguishes elastic storage from the retention derivative and notes that pore-space deformation normally dominates fluid compression.

Sources:
- Hydrogeology Journal 2022, DOI 10.1007/s10040-022-02535-z;
- GMD 2023 openRE, DOI 10.5194/gmd-16-659-2023;
- Camporese et al. 2006, DOI 10.1029/2005WR004495.

## Scale of Pim Dik's candidate

`1e-6 cm^-1 = 1e-4 m^-1`.

This is within published orders of magnitude for relatively stiff mineral aquifer materials. Published examples include specific elastic storage of order `1e-5 to 1e-4 m^-1` in coarse-grained aquifer material.

This establishes plausibility of the order, not a Dutch-soil default.

## Available Dutch soil-class information

The Staringreeks classification itself is based on:
- organic matter;
- clay/lutum;
- silt/leem;
- M50 for sandy materials;
- topsoil versus subsoil class.

These variables are documented in the 2001/2018 Staringreeks reports but are not included as sample-level predictors in the audited 2018 hydraulic zip.

Soil-mechanics literature independently supports bulk density, organic matter, clay fraction and water state as important predictors of compressibility/elastic response.

## Decision

Do not derive production ELAS from the current six MvG parameters alone.

Next evidence path:

1. obtain or reconstruct representative pedological descriptors per Staringreeks material;
2. distinguish mineral and organic classes;
3. distinguish topsoil and subsoil where mechanical state differs;
4. seek measured or defensibly transferable elastic/recompression compressibility data;
5. use MvG near-saturation contrast only as a numerical-risk descriptor after ELAS has been physically assigned.

The 12 dynamic material holdouts remain closed.
