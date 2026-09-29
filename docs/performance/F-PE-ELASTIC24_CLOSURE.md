# F-PE-ELASTIC24 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@d02ad40a413513764d56546db1eae4570328d621`

Merged PR:
`#837`

Admitted preprocessing file:
`tools/fpe_elastic24_profile_retrieval.py`

Admitted file blob:
`68229bf19eee554296a96532696f1c0ed7ab3f3f`

## Admission summary

F-PE-ELASTIC24 admits deterministic offline retrieval of one already explicit
BRO `normalsoilprofile_id` from the frozen local BRO Bodemkaart GeoPackage.

The admitted seam is:

`explicit normalsoilprofile_id + frozen local GeoPackage`
-> exact source profile metadata
-> exact ordered source horizons
-> source-bound JSON `swap5.elastic24.bro-profile.v1`.

No `src/**` production source is changed.

## Clean qualification authority

Clean current-canonical branch:
`work/f-pe-elastic24-current-clean-admission`.

Qualified postimage:
`4a9c83fc68a773151ab3d114cdbb887be0b259e4`.

Result-document head:
`f5e1e6cf282cbae52d3309e35fe130e27eba582f`.

Qualification:
- workflow run `36568463248`;
- job `109406180337`;
- conclusion SUCCESS.

Passed:
- required source schema;
- all 368 explicit profile IDs;
- all 1568 source horizons;
- field-for-field direct SQL identity;
- profile `16160` identity;
- missing/nonpositive profile fail closed;
- malformed schema/geometry fail closed;
- deterministic repeated retrieval;
- exact source-artifact SHA-256 provenance;
- boundary hygiene;
- zero `src/**` production-source scope.

## Frozen source authority

Source artifact:
- producer workflow run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- artifact id `11024079961`;
- producer head `6f81df17d74308fa423f75095cb3d448f95d773c`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

No live PDOK/BRO fallback is admitted.

## Ownership boundary

ELASTIC24 owns only local offline source retrieval for an explicit profile ID.

It does not own:
- location-to-maparea spatial selection;
- automatic profile choice;
- polygon/CRS logic;
- Staringreeks retention evaluation;
- material-regime classification;
- ELAS prediction;
- SWAP-grid mapping;
- runtime file or network I/O;
- automatic generated-prior activation.

## Current chain

frozen BRO source artifact
-> ELASTIC24 offline explicit-profile retrieval
-> ELASTIC23 typed maparea-to-profile association where caller already owns the maparea identity
-> ELASTIC22 exact in-memory profile selection/source-horizon assembly
-> ELASTIC21 block-code projection
-> ELASTIC20 Staringreeks catalog
-> ELASTIC19 descriptor construction
-> ELASTIC18/17 grid normalization and horizon-to-node mapping
-> ELASTIC16 assembly
-> ELASTIC15 explicit application binding
-> existing ELAS runtime.

The ordering above is an ownership map, not an assertion that ELASTIC24 itself
performs ELASTIC23 or any downstream operation.

## Remaining boundary

Still external:
- location or coordinate -> maparea selection;
- user-facing preprocessing/application syntax;
- end-to-end application-host orchestration;
- explicit generated-prior request wiring from user/application configuration.

## Closure

F-PE-ELASTIC24 is canonically admitted and closed.
