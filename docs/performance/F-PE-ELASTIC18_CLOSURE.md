# F-PE-ELASTIC18 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@7323dce8a9addf2abc1f5624d95e6ce0d04a969c`

Merged PR:
`#804`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`

Admitted production blob:
`d9138f57a2c0b354b454cf99062b84d8b584d1c2`

## Admission summary

F-PE-ELASTIC18 admits the bounded conversion from raw SWAP grid geometry to
the normalized geometry consumed by ELASTIC17:

`z_cm -> node_depth_m = -z_cm / 100`

`dz_cm -> node_thickness_m = dz_cm / 100`.

The adapter owns sign/unit normalization and geometry validation only.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic18-clean-admission`.

Qualified clean postimage:
`ef3723bff884b5def6494f16a4576408fd764baa`.

Qualification:
- workflow run `36560822452`;
- job `109380988592`;
- conclusion SUCCESS.

Passed:
- canonical SWAP fixture;
- heterogeneous compartment thickness;
- sign fail closed;
- non-finite/value fail closed;
- compartment-contiguity fail closed;
- ELASTIC17 composition;
- O0/O2 identity;
- exact source scope.

## Blob identity

The admitted canonical production blob is exactly the clean qualification blob:

`d9138f57a2c0b354b454cf99062b84d8b584d1c2`.

No production source changed between qualification and admission.

## Admitted grid semantics

SWAP-native input:
- `z` in cm relative to soil surface;
- below-surface node centres are non-positive;
- `dz` is positive compartment thickness in cm.

Normalized output:
- positive depth in metres below surface;
- positive compartment thickness in metres.

Adjacent compartments must tile continuously from the soil surface within the
fixed geometric tolerance.

No resampling, interpolation or material assignment occurs in ELASTIC18.

## Relationship to ELASTIC chain

Current admitted chain:

direct mechanical evidence
-> ELASTIC11 predictor
-> ELASTIC12 BOFEK/BRO transfer
-> ELASTIC13 mineral policy
-> ELASTIC14 prior materializer
-> ELASTIC15 explicit application binding
-> ELASTIC16 descriptor assembly
-> ELASTIC17 horizon-to-node mapping
-> ELASTIC18 raw SWAP grid normalization.

## Remaining boundary

Still outside this chain:
- BOFEK/BRO profile retrieval in production/application preprocessing;
- source horizon descriptor construction;
- Staringreeks `theta(h=-100 cm)` evaluation for the selected source horizon;
- profile selection from a location/soil identity;
- file syntax;
- automatic generated-prior request.

## Closure

F-PE-ELASTIC18 is canonically admitted and closed.
