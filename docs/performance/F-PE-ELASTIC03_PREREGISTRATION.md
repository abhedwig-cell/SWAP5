# F-PE-ELASTIC03 — physical predictor source audit

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_SOURCE_AUDIT_RESULTS

Parent: F-PE-ELASTIC02A.

## Scientific premise

Legacy SWAP ELAS is a specific elastic storage coefficient with dimension inverse length.

Specific storage is physically related to compressibility of the porous medium and water and to porosity. The Staringreeks MvG parameters are retention/conductivity parameters and are therefore not assumed to be causal predictors of ELAS.

## Question

Does the official Staringreeks 2018 source package contain pedological/material descriptors that can support a physically defensible proxy for porous-medium compressibility?

## Target source members

Audit, without modifying them:

- `staringreeks/Data/unit_properties_2018.csv`;
- `staringreeks/Data/allsamples_2018.csv`;
- `staringreeks/Data/staringreeks_2018.csv`.

Record hashes, dimensions and columns. Persist the complete unit-properties table in CI evidence and only a bounded sample/header of the sample-level table.

## Predictors of interest before inspection

Priority:
- dry bulk density or related density;
- organic matter / humus;
- clay or lutum fraction;
- silt / loam fraction;
- sand fraction or median sand size;
- porosity;
- soil class / topsoil-versus-subsoil.

Secondary:
- MvG parameters only as empirical covariates and numerical-risk descriptors.

No ELAS mapping is to be fitted from these variables in this audit.
