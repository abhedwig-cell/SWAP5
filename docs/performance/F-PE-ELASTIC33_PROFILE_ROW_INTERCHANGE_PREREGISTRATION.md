# F-PE-ELASTIC33 — ELASTIC24 profile to ELASTIC22 row interchange preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TOOL_CHANGE

Baseline:
`integration/f-ci-canonical@bcb727b27c3586accb5a481ec3eb5ce90b1e8cef`

Parent authority:
- `F-PE-ELASTIC24_CLOSURE.md`;
- `F-PE-ELASTIC22_CLOSURE.md`.

Parallel ownership:
- F-PE-ELASTIC32 owns a separate spatial-source audit and is not modified by
  this work unit.

## Purpose

Add one deterministic offline preprocessing tool that converts one admitted
ELASTIC24 source-profile JSON artifact into a line-oriented interchange whose
rows map one-to-one onto the nine fields of
`fmr_elastic_storage_bro_horizon_row_t` admitted by ELASTIC22.

The seam is:

`swap5.elastic24.bro-profile.v1 JSON`
-> exact source-profile validation
-> exact ELASTIC22 row-field projection
-> `SWAP5_ELASTIC33_BRO_ROWS_V1` interchange.

ELASTIC33 does not parse the interchange into Fortran objects. That future
adapter is deliberately separate.

## Source authority

Accepted input must contain:

- schema exactly `swap5.elastic24.bro-profile.v1`;
- source artifact SHA-256 exactly
  `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`;
- one positive `normalsoilprofile_id`;
- horizon count equal to the horizon-array length;
- ordered contiguous horizons beginning at 0 m;
- required ELASTIC24 source fields.

No alternate schema, source hash, aliases or silent fallback are admitted.

## ELASTIC22 row projection

Each output row contains exactly, in this order:

1. `normalsoilprofile_id`;
2. `layer_number`;
3. `top_depth_m`;
4. `bottom_depth_m`;
5. `staringseriesblock`;
6. `rho_dry_g_cm3`;
7. `organic_matter_available` as 0/1;
8. `organic_matter_pct`;
9. `peat_type_present` as 0/1.

Projection rules:

- `layer_number = ELASTIC24 layernumber`;
- geometry, block and dry density preserve source values;
- non-NULL organic matter -> available=1 and exact numeric value;
- NULL organic matter -> available=0 and numeric placeholder 0.0;
- non-NULL peat type -> peat_type_present=1;
- NULL peat type -> peat_type_present=0.

The peat-type source text itself is not retained because ELASTIC22 consumes only
the explicit presence flag.

## Interchange format

Line 1:
`SWAP5_ELASTIC33_BRO_ROWS_V1`

Line 2:
`source_artifact_sha256=<exact hash>`

Line 3:
`normalsoilprofile_id=<integer>`

Line 4:
`row_count=<integer>`

Line 5:
`columns=normalsoilprofile_id|layer_number|top_depth_m|bottom_depth_m|staringseriesblock|rho_dry_g_cm3|organic_matter_available|organic_matter_pct|peat_type_present`

Subsequent lines are pipe-delimited row values in that exact order.

Binary64 values are serialized with 17 significant digits to permit exact
round-trip reconstruction.

## Fail-closed behavior

Reject:
- missing/unreadable input;
- malformed JSON;
- wrong schema or source hash;
- invalid/missing profile identity;
- row-count mismatch;
- invalid layer ordering;
- non-finite/invalid geometry, density or organic matter;
- non-integral block or layer values.

No partial output file survives failure.

## Qualification matrix

A1. known profile 16160 materializes the exact interchange header/provenance.

A2. every projected row maps field-for-field onto the ELASTIC22 row contract.

A3. source floating-point geometry/density/organic values round-trip bit
identically through 17-digit interchange serialization.

A4. NULL organic matter projects to unavailable + 0.0 placeholder without
inventing availability.

A5. peat-type NULL/non-NULL projects exactly to presence false/true.

A6. malformed/wrong-schema/wrong-source-hash inputs fail closed.

A7. malformed layer sequence/geometry/data fail closed.

A8. repeated materialization is byte-identical.

A9. all 368 frozen profiles materialize successfully and together contain
exactly 1568 rows.

A10. source scope contains no `src/**` change; ELASTIC33 is preprocessing
tooling/tests/docs only.

## Admission boundary

A green ELASTIC33 admits only deterministic ELASTIC24 JSON -> ELASTIC22-row
interchange materialization.

Still outside:
- Fortran parsing of the interchange into
  `fmr_elastic_storage_bro_horizon_row_t(:)`;
- spatial location -> maparea selection;
- automatic profile choice;
- runtime source I/O.
