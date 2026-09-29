# F-PE-ELASTIC20 — offline BOFEK/BRO ELAS horizon catalog preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_CATALOG_MATERIALIZATION

Baseline:
`integration/f-ci-canonical@7b34fb5a980b647423d8c5062d0ec64f0568e0f7`

Parent authority:
- `F-PE-ELASTIC12_CLOSEOUT.md`;
- `F-PE-ELASTIC13_CLOSEOUT.md`;
- `F-PE-ELASTIC19_CLOSURE.md`.

## Purpose

Materialize one deterministic offline catalog that contains the complete
source-bound horizon information required to feed the admitted ELASTIC19
descriptor builder without any network access inside SWAP runtime.

The catalog is preprocessing data, not a runtime physics owner.

## Frozen source artifacts

Use exactly the previously qualified external-source artifacts:

### BOFEK/Staringreeks source artifact

- workflow run `36549054287`;
- artifact `11023058542`;
- expected contents include:
  - `bofek.zip`;
  - `staring.zip`.

### PDOK BRO Bodemkaart GeoPackage artifact

- workflow run `36550782840`;
- artifact `11024079961`;
- expected GeoPackage contains:
  - `normalsoilprofiles`;
  - `soilhorizon`.

No live network request is authorized in ELASTIC20.

## Source identity gates

Require:

- 368 unique BOFEK `iprofile` IDs;
- exactly the same 368 `normalsoilprofile_id` values in BRO;
- 1568 source horizons total;
- exact BOFEK/BRO layer identity already established by ELASTIC12;
- valid Staringreeks 2018 material set B01..B18/O01..O18.

Any source drift fails closed.

## Staringreeks code resolution

BRO `staringseriesblock` is resolved deterministically:

- 101..118 -> B01..B18;
- 201..218 -> O01..O18.

No fuzzy name mapping is allowed.

## Catalog row schema

One row per BRO horizon, sorted by:

1. `normalsoilprofile_id`;
2. `layernumber`.

Required fields:

- `profile_id`;
- `bofek_unit`;
- `soilunit`;
- `layer_number`;
- `top_depth_m`;
- `bottom_depth_m`;
- `staring_code`;
- `rho_dry_g_cm3`;
- `organic_matter_available`;
- `organic_matter_pct`;
- `peat_type_present`;
- `peat_type`;
- `wcr`;
- `wcs`;
- `alpha_cm_inv`;
- `npar`;
- `theta_ref_h_minus100`;
- `regime`.

## Frozen descriptor derivation

ELASTIC20 independently reproduces ELASTIC19 semantics for catalog
qualification:

`m = 1 - 1/n`

`theta_ref =
 wcr + (wcs-wcr)/(1+(alpha*100)^n)^m`.

Regime:

1. explicit peat type -> PEAT;
2. else missing organic matter -> UNKNOWN;
3. else OM > 15% -> ORGANIC_RICH_NONPEAT;
4. else MINERAL.

This duplication exists only as an offline catalog oracle. It does not create a
second runtime physics owner.

## Expected population authority

From qualified ELASTIC13:

- total horizons: 1568;
- MINERAL: 1356;
- ORGANIC_RICH_NONPEAT: 8;
- PEAT: 204;
- UNKNOWN: 0.

The catalog must reproduce these counts exactly.

## Determinism

Produce:

1. `elastic20_bofek_horizon_catalog.csv`;
2. `elastic20_bofek_horizon_catalog.meta.json`.

The metadata must record:

- source run/artifact IDs;
- source file SHA-256 hashes;
- catalog row count;
- regime counts;
- CSV SHA-256;
- schema version `swap5.elastic20.bofek_horizon_catalog.v1`.

Two independent materializations from the same frozen artifacts must produce
byte-identical CSV and semantic-identical metadata except for no
non-deterministic timestamp field; therefore the metadata itself must also be
byte deterministic.

## Qualification gates

A1. source identity: 368 profiles and 1568 horizons exact.

A2. all Staringreeks block codes resolve to one of B01..B18/O01..O18.

A3. source fields required by ELASTIC19 are complete or explicitly marked
unavailable; no silent imputation.

A4. theta(-100 cm) independently rederived for all rows and finite within
[wcr,wcs].

A5. regime counts exactly equal 1356/8/204/0.

A6. catalog ordering is deterministic and unique by (profile_id,layer_number).

A7. sampled rows rebuilt through admitted ELASTIC19 produce bit-identical
theta/regime and source geometry/density.

A8. catalog contains all 79 BOFEK units represented by the 368-profile
population.

A9. repeated materialization is byte-identical.

A10. no `src/**` production source change.

## Admission boundary

A green ELASTIC20 qualifies a frozen offline preprocessing catalog only.

It does not admit:
- location-to-profile selection;
- runtime file parsing;
- automatic catalog loading by SWAP;
- network access;
- generated-prior activation;
- peat/high-organic auto-assignment.

A later work unit may define a bounded application-side catalog lookup by
explicit profile ID.
