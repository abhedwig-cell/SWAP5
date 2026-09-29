# F-PE-ELASTIC24 — offline BRO profile retrieval result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic24-clean-admission`

Baseline:
`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

Qualified clean postimage:
`f678c5cc5041c2329877c88d7251847db9baf059`

Workflow run:
`36567989992`

Job:
`109404588440`

Conclusion:
SUCCESS.

## Architecture result

The ELAS preprocessing chain is now split by ownership:

- ELASTIC23 owns the canonically admitted typed
  `maparea_id -> normalsoilprofile_id` association;
- ELASTIC22 owns typed in-memory exact profile selection and source-horizon
  assembly;
- ELASTIC24 owns only offline retrieval of an already explicit
  `normalsoilprofile_id` from the frozen local BRO GeoPackage.

No source acquisition, spatial selection and runtime activation are combined in
one module.

## Frozen source authority

Qualification used:
- workflow run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- artifact id `11024079961`;
- producer head `6f81df17d74308fa423f75095cb3d448f95d773c`;
- archive SHA-256
  `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

The Actions download independently reported the exact same SHA-256.

## Qualification

- A1 required source schema: PASS.
- A2 all 368 explicit `normalsoilprofile_id` values retrieve: PASS.
- A3 total retrieved source horizons = 1568: PASS.
- A4 every emitted source field equals the independent direct-SQL oracle: PASS.
- A5 profile `16160` exact source identity: PASS.
- A6 missing/nonpositive profile identity fails closed: PASS.
- A7 malformed schema and malformed profile geometry fail closed: PASS.
- A8 repeated retrieval is semantically deterministic: PASS.
- A9 emitted frozen-artifact provenance SHA-256 is exact: PASS.
- A10 boundary hygiene and zero `src/**` production-source scope: PASS.

## Qualified seam

`explicit normalsoilprofile_id + frozen local BRO GeoPackage`
-> exact source profile metadata
-> exact ordered source horizons
-> source-bound JSON `swap5.elastic24.bro-profile.v1`.

No coordinate, polygon or location is accepted by the tool.

No Staringreeks retention, theta(-100 cm), material-regime classification,
ELAS prediction, SWAP-grid mapping or application activation occurs.

## Production/source scope

No `src/**` file changes are part of ELASTIC24.

The admitted candidate consists only of:
- one offline preprocessing tool;
- its qualification oracle/runner;
- one workflow;
- preregistration and result evidence.

## Preserved boundary

Still outside scope:
- location-to-maparea spatial selection;
- automatic profile choice;
- user-facing SWAP input syntax;
- runtime parsing of the preprocessing artifact;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
