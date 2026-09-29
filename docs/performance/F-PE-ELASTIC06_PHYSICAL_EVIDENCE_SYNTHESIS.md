# F-PE-ELASTIC06 — physical magnitude and predictor evidence synthesis

Date: 2026-09-29

Status: PHYSICAL_PRIOR_ENVELOPE_QUALIFIED_NO_PEDOTRANSFER_RULE

## Purpose

Interpret Pim Dik's nominated `ELAS = 1e-6 cm^-1` as a physical specific-storage magnitude and determine what can and cannot be inferred from currently available soil data.

This document does not fit ELAS from solver outcomes.

## Unit conversion

Legacy SWAP ELAS has unit `cm^-1`.

`1e-6 cm^-1 = 1e-4 m^-1`.

## Specific-storage physics

USGS groundwater references define specific storage as water released from or taken into storage per unit porous-medium volume per unit change in hydraulic head and express it in terms of porosity, water compressibility and porous-medium constrained/bulk elasticity.

For an unconsolidated medium, the scale can be written schematically as:

`Ss ~= rho_w * g * (alpha_matrix + n * beta_w)`.

At porosity `n = 0.4`, water compressibility alone contributes only about `1.8e-6 m^-1 = 1.8e-8 cm^-1`.

Therefore an ELAS value of `1e-6 cm^-1` is dominated by porous-matrix compressibility rather than water compressibility.

Neglecting the small water term, `Ss = 1e-4 m^-1` corresponds to a constrained-modulus scale of order `1e8 Pa`, approximately 100 MPa.

This is an order-of-magnitude interpretation, not an assignment rule.

## External magnitude evidence

A 2022 Hydrogeology Journal synthesis reports that specific-storage values for unconsolidated sandy, silty, clayey and glacial-till materials commonly occupy the `1e-5 to 1e-4 m^-1` orders of magnitude, with large multi-order spreads by material and measurement method.

USGS model/reference material gives examples and literature ranges around:

- loose-to-dense sand/gravel: roughly `1e-4 to 4.3e-4 m^-1` in one cited range;
- clay: roughly `9.2e-4 to 2e-2 m^-1` in one cited range;
- sand/gravel aquifer formation compressibility corresponding to specific storage from a few `1e-6` to `1e-5 m^-1` in other field studies.

These ranges are not directly transferable to cultivated Dutch topsoils, but they establish that `1e-4 m^-1` is physically plausible for unconsolidated porous material.

## Agricultural-soil mechanical evidence

Agricultural-soil compression literature shows that elastic/recompression and compression behaviour depends on structural and pedological variables rather than only hydraulic retention-fit parameters.

Relevant evidence includes:

- Schjønning (2024), Soil & Tillage Research 235, 105866, DOI 10.1016/j.still.2023.105866:
  confined-compression behaviour across 14 agricultural topsoils; compressibility metrics vary with bulk density, organic matter, texture and moisture state.

- Reichert et al. (2018), Catena 165, 345-357, DOI 10.1016/j.catena.2018.02.014:
  soil elasticity/decompressibility and compressibility depend on bulk density, organic matter, clay content and water state.

- Nawaz et al. (2013), Agronomy for Sustainable Development 33, 291-309, DOI 10.1007/s13593-011-0071-8:
  review identifies water content, texture/structure and organic matter as major controls on compaction response.

The literature does not supply a validated Dutch Staringreeks-class ELAS pedotransfer function.

## Dutch data bridge already present in SWAP5 research

F-HYDROFIT02 established depth-scoped BRO descriptor provenance on a frozen 31-interval hydrophysical corpus:

- horizonCode: 31 ASSIGNED;
- dryBulkDensity: 21 ASSIGNED, 10 AMBIGUOUS;
- organicMatterContent: 21 ASSIGNED, 10 AMBIGUOUS;
- clayContent: 19 ASSIGNED, 12 MISSING;
- sandContent: 10 ASSIGNED, 21 MISSING;
- siltContent: 2 ASSIGNED, 29 MISSING.

Those data provide a physically relevant Dutch descriptor basis for a prior study, but not complete enough for a universal deterministic rule without imputation.

No ambiguous descriptor may be silently averaged.

## Interpretation of Pim's 1e-6 cm^-1 proposal

The current evidence supports the following bounded statement:

- `1e-6 cm^-1` is physically plausible as an elastic specific-storage magnitude for unconsolidated mineral material;
- it is much larger than water-compressibility storage alone and therefore implies appreciable matrix elasticity;
- it should not automatically be universal across mineral, clay-rich, organic and peat materials;
- its appropriate value should depend on mechanical/pedological state, with bulk density, organic matter, texture and moisture history as candidate controls;
- MvG Alpha/N/Lambda/Ksat are useful numerical-response descriptors but do not constitute a mechanistic ELAS generator.

## Production implication

F-PE-ELASTIC05 should restore typed per-layer ELAS capability with default OFF.

The physical assignment path should be separate:

`pedological/mechanical descriptors -> physical ELAS prior/value -> typed per-layer input`.

The numerical qualification path remains:

`ELAS + MvG near-saturation shape + saturation exposure -> solver/trajectory risk`.

These two mappings must not be conflated.

## Next evidence step

A future physical-prior experiment may use only BRO intervals with unambiguous source-bound bulk density/organic matter and, where available, clay content.

Its first target should be broad physically defensible ELAS envelopes or material classes, not point regression.

The 12 frozen Staringreeks dynamic material holdouts remain irrelevant to physical prior fitting and must not be used as solver-tuned targets.
