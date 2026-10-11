# F-PE-ELASTIC24 — current-canonical offline BRO profile retrieval result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic24-current-clean-admission`

Baseline:
`integration/f-ci-canonical@67e6abbacf53aada2f2613644446eea826602806`

Qualified postimage:
`4a9c83fc68a773151ab3d114cdbb887be0b259e4`

Workflow run:
`36568463248`

Job:
`109406180337`

Conclusion:
SUCCESS.

## Qualification

- required BRO source schema: PASS;
- all 368 explicit `normalsoilprofile_id` values retrieve: PASS;
- total source horizons = 1568: PASS;
- every emitted field equals direct SQL source rows: PASS;
- profile `16160` identity: PASS;
- missing/nonpositive profile identity fails closed: PASS;
- malformed schema and malformed profile geometry fail closed: PASS;
- deterministic repeated retrieval: PASS;
- frozen source artifact SHA-256 provenance: PASS;
- no network/spatial/ELAS semantics and no `src/**` changes: PASS.

## Frozen source authority

- workflow run `36550782840`;
- artifact id `11024079961`;
- producer head `6f81df17d74308fa423f75095cb3d448f95d773c`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

## Admitted candidate seam

`explicit normalsoilprofile_id + frozen local BRO GeoPackage`
-> exact source profile metadata
-> exact ordered source horizons
-> source-bound JSON `swap5.elastic24.bro-profile.v1`.

ELASTIC24 owns offline source retrieval only.

It does not own:
- location-to-maparea selection;
- automatic profile choice;
- retention or ELAS derivation;
- SWAP-grid mapping;
- runtime file/network I/O;
- automatic generated-prior activation.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
