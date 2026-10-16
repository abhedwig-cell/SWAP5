# F-PE-ELASTIC22 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@c62c6de8886030767c70e699448077aa70a7f269`

Merged PR:
`#826`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_explicit_profile_source.f90`

Admitted production blob:
`ae33538861682506681eb540ddfc66e53cddcf67`

## Admission summary

F-PE-ELASTIC22 admits explicit in-memory selection of one resolved BRO
`normalsoilprofile_id` plus deterministic source-horizon assembly through the
already admitted ELASTIC21, ELASTIC20 and ELASTIC19 seams.

No file, database, network or spatial lookup is introduced.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic22-clean-admission`

Qualified clean workflow postimage:
`08400c0904200ed943c31596ae073c24f369a2ef`

Result-document head:
`8d5fcbbab9d3aa72d2d8cfbf898fad61f268c4ef`

Qualification:
- workflow run `36565951650`;
- job `109397765909`;
- conclusion SUCCESS.

Passed:
- explicit mixed-input profile selection;
- source geometry/density identity;
- ELASTIC21+20+19 nested composition;
- absent/invalid profile request fail closed;
- selected-profile structural validation;
- atomic nested block/descriptor rejection;
- ELASTIC17/16 downstream composition;
- PEAT provenance preservation and downstream rejection;
- O0/O2 identity;
- exact source scope.

## Blob identity

The admitted canonical production blob is exactly the clean qualification blob:

`ae33538861682506681eb540ddfc66e53cddcf67`.

## Admitted ownership semantics

The caller owns the selected positive `normalsoilprofile_id`.

ELASTIC22:
- filters only exact matching source rows;
- does not sort them;
- requires layer numbering 1,2,3,... in encountered source order;
- requires contiguous horizon geometry from the soil surface;
- assembles every selected row through admitted block/catalog/descriptor
  contracts;
- rejects the complete profile atomically on any selected-row failure.

Rows belonging to other profile IDs do not affect the selected profile.

## Preserved boundary

Still external:
- GeoPackage/file/database loading;
- network retrieval;
- location-to-profile selection;
- spatial polygon lookup;
- automatic profile-ID choice;
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
-> ELASTIC18 SWAP grid normalization
-> ELASTIC19 source-horizon descriptor construction
-> ELASTIC20 Staringreeks catalog
-> ELASTIC21 BRO block-code projection
-> ELASTIC22 explicit in-memory profile source.

## Closure

F-PE-ELASTIC22 is canonically admitted and closed.
