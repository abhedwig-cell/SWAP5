# F-PE-ELASTIC20 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@fb8e5fc203dffc7f102165d01cd0374a6366ba82`

Merged PR:
`#817`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90`

Admitted production blob:
`de407defe1a69375edbe757bfe5772f262d5458e`

## Admission summary

F-PE-ELASTIC20 admits an immutable Staringreeks 2018 code-to-retention catalog
for the generated ELAS preprocessing chain.

The admitted seam is:

`B01..B18/O01..O18`
-> exact frozen 2018 `wcr,wcs,alpha,npar`
-> admitted ELASTIC19 retention input.

No runtime file I/O is required.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic20-current-clean-admission-v2`

Qualified clean postimage:
`883575d55b0e2574b10cade028cb5dc5a011337b`

Result-document head:
`3e613d6ce6de2ac2843cbfef79b5efe5f6f4c79f`

Qualification:
- workflow run `36563658270`;
- job `109390268359`;
- conclusion SUCCESS.

Passed:
- all 36 exact codes resolve in frozen order;
- all `wcr,wcs,alpha,npar` values bit-identical to independent oracle;
- B01/O18 endpoint identity;
- malformed/unsupported code fail closed;
- ELASTIC19 composition identity;
- all 36 theta(-100 cm) evaluations finite and within [wcr,wcs];
- O0/O2 identity;
- exact source scope.

## Source authority

Official source:
`https://nhi.nu/documents/224/staringreeks_1.0.0.zip`

Official zip SHA-256:
`9d06dff19392111dad110802058e3894c30355f553842ce32d89eed005071cd5`

Selected member:
`staringreeks/Data/staringreeks_2018.csv`

Member SHA-256:
`ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494`

Catalog:
36 exact records ordered B01..B18, O01..O18.

## Blob identity

The admitted canonical production blob is exactly the clean qualification blob:

`de407defe1a69375edbe757bfe5772f262d5458e`.

No production source changed between clean qualification and canonical
admission.

## Lookup semantics

Accepted input:
- exact 2018 material code B01..B18 or O01..O18.

Trailing character padding is harmless.

Not admitted:
- lowercase normalization;
- aliases;
- leading-space normalization;
- numeric-only identifiers;
- historical Staringreeks years;
- nearest-code fallback.

Unsupported codes fail closed.

## Preserved boundary

Still external:
- BOFEK/BRO profile retrieval;
- selected source-horizon to Staringreeks-code association;
- location/profile selection;
- file/data-catalog syntax;
- automatic generated-prior request.

## Current admitted chain

direct mechanical evidence
-> ELASTIC11 predictor
-> ELASTIC12 BOFEK/BRO transfer
-> ELASTIC13 mineral policy
-> ELASTIC14 prior materializer
-> ELASTIC15 explicit application binding
-> ELASTIC16 descriptor assembly
-> ELASTIC17 horizon-to-node mapping
-> ELASTIC18 raw SWAP grid normalization
-> ELASTIC19 source-horizon descriptor construction
-> ELASTIC20 immutable Staringreeks 2018 catalog.

## Closure

F-PE-ELASTIC20 is canonically admitted and closed.
