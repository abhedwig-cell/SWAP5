# F-PE-ELASTIC37 — row-interchange to application binding preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@3d860286270fcb70c6e55798b9d38ed4c440cff7`

Parent authority:
- `F-PE-ELASTIC35_CLOSURE.md`;
- `F-PE-ELASTIC22_CLOSURE.md`;
- `F-PE-ELASTIC18_CLOSURE.md`;
- `F-PE-ELASTIC17_CLOSURE.md`;
- `F-PE-ELASTIC16_CLOSURE.md`;
- `F-PE-ELASTIC15_CLOSURE.md`.

## Purpose

Add one application-level composition seam from an already selected/materialized
ELASTIC33 row-interchange file to a bound physical-parameter postimage.

The seam is:

`explicit generated-prior request + explicit ELASTIC33 row file + base SWAP parameters`
-> ELASTIC35 row parser
-> ELASTIC22 source-horizon assembly
-> ELASTIC18 SWAP-grid normalization
-> ELASTIC17 horizon-to-node mapping
-> ELASTIC16 generated-prior assembly
-> ELASTIC15 binding
-> bound parameter postimage.

No spatial selection, profile selection, GeoPackage parsing or automatic request
creation occurs in ELASTIC37.

## Default-off contract

If `generated_prior_requested=.false.`:

- return an exact copy of the base parameters;
- do not open or inspect the supplied row-file path;
- report INACTIVE.

Therefore a missing/invalid path cannot affect default-off applications.

## Active request contract

If request=true:

1. parse the explicit row file through ELASTIC35;
2. use the parser-selected profile identity to assemble horizons through
   ELASTIC22;
3. normalize `base_parameters%z` and `base_parameters%dz` through ELASTIC18;
4. map horizons to nodes through ELASTIC17;
5. assemble and bind generated priors through ELASTIC16/15.

Any nested failure rejects the complete generated binding atomically.

## Ownership invariants

Preserve:
- explicit/user ELAS has higher ownership;
- PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN remain non-auto-assigned;
- no partial row/node/prior binding survives failure;
- no spatial or network I/O;
- no file discovery;
- no solver/runtime-owned source loading.

ELASTIC37 may open only the explicit application-side ELASTIC33 file through
ELASTIC35 and only when request=true.

## Diagnostics

Persist nested statuses for:
- row-file parser;
- profile-source assembly;
- grid normalization;
- horizon-node mapping;
- descriptor/prior assembly.

Also report:
- selected profile ID;
- whether request was present;
- whether generated prior was applied.

## Qualification matrix

A1. request=false with a nonexistent path returns exact base-parameter identity
and performs no file-dependent failure.

A2. valid two-horizon MINERAL interchange + matching two-node SWAP grid applies
generated priors successfully.

A3. output from A2 is identical to direct manual composition of admitted
ELASTIC35 -> 22 -> 18 -> 17 -> 16.

A4. existing explicit/user ELAS remains untouched and active request fails
closed through ELASTIC15 ownership.

A5. PEAT row provenance reaches ELASTIC16 and causes generated-prior rejection;
ELASTIC37 does not reclassify it.

A6. malformed/missing interchange fails closed atomically.

A7. invalid/noncontiguous SWAP grid fails closed atomically.

A8. node that straddles a source-horizon boundary fails closed through ELASTIC17.

A9. O0/O2 identity.

A10. production source scope is exactly one new application adapter module;
no solver, kernel, legacy or source-preprocessing tool changes.

## Admission boundary

A green ELASTIC37 admits only explicit application-side row-file-to-bound-
parameter composition.

Still outside:
- automatic invocation by production bootstrap;
- spatial/location preprocessing invocation;
- automatic generated-prior request from soil/location identity;
- runtime/solver file discovery.
