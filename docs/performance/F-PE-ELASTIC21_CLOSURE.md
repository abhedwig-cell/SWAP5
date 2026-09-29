# F-PE-ELASTIC21 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@e355dacf50fcc0cceb77e02f73b78eddebcbeced`

Merged PR:
`#821`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_staringseriesblock_map.f90`

Admitted production blob:
`e0c1773549399430fd1ef20bace4303aa9ae36b2`

## Admission summary

F-PE-ELASTIC21 admits deterministic projection from the resolved BRO/BOFEK
`staringseriesblock` integer to the immutable ELASTIC20 Staringreeks-2018
catalog code:

- `101..118 -> B01..B18`;
- `201..218 -> O01..O18`.

The adapter owns no retention parameters and delegates catalog identity to
ELASTIC20.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic21-current-clean-admission`.

Qualified clean postimage:
`f078da158e831b73f00c399e13de00b8a7b44515`.

Result-document head:
`a972340b7915b6f49b7f5dcd31d997728e106acd`.

Qualification:
- workflow run `36564778634`;
- job `109393929619`;
- conclusion SUCCESS.

Passed:
- all 18 B-family blocks;
- all 18 O-family blocks;
- all 36 ELASTIC20 catalog resolutions;
- invalid/out-of-range block fail-closed behavior;
- ELASTIC20/ELASTIC19 composition identity;
- O0/O2 identity;
- exact source scope.

## Blob identity

The admitted canonical production blob is exactly the clean qualification blob:

`e0c1773549399430fd1ef20bace4303aa9ae36b2`.

## Preserved boundary

Still external:
- BOFEK/BRO profile retrieval;
- location/profile selection;
- source-horizon retrieval;
- file/data-catalog syntax;
- alternate Staringreeks years;
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
-> ELASTIC20 immutable Staringreeks catalog
-> ELASTIC21 BRO block-code projection.

## Closure

F-PE-ELASTIC21 is canonically admitted and closed.
