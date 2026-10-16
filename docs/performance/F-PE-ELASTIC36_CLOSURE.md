# F-PE-ELASTIC36 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@9dcb34ac712badf12d160cd1b8057ee4a4c0f8da`

Merged PR:
`#870`

Admitted preprocessing file:
`tools/fpe_elastic36_rd_point_profile_interchange.py`

Admitted file blob:
`7f68a4825c3e5fd2937195b4bd13c33f874371bc`

## Admission summary

F-PE-ELASTIC36 admits deterministic offline composition:

`RD point`
-> ELASTIC34 strict maparea selection
-> exact `soilarea_normalsoilprofile` association
-> ELASTIC24 explicit profile retrieval
-> ELASTIC33 canonical row interchange.

The output is `SWAP5_ELASTIC33_BRO_ROWS_V1` plus exact selected maparea,
profile, point and source-artifact provenance.

## Qualification authority

Qualified branch:
`research/f-pe-elastic36-rd-point-profile-interchange`.

Qualified postimage:
`12165549601a43744b652bd13416938a41a1f9d7`.

Result-document head:
`76517a47f3b81f1627d25f72b17db98bfb9b5141`.

Qualification:
- workflow run `36589811329`;
- job `109479659647`;
- conclusion SUCCESS.

Passed:
- parent source/hash/relation authority;
- 64/64 real-source maparea selections;
- direct SQL profile identity;
- ELASTIC24 profile retrieval identity;
- ELASTIC33 byte identity;
- 57 distinct normal soil profiles in the sample;
- spatial BOUNDARY/NOT_FOUND/AMBIGUOUS fail-closed propagation;
- missing/duplicate relation fail closed;
- repeated byte/provenance identity;
- zero production `src/**` change.

## Ownership semantics

ELASTIC36 owns offline composition only.

ELASTIC34 owns RD point-to-maparea selection.
ELASTIC23 owns maparea-to-profile semantics.
ELASTIC24 owns profile retrieval.
ELASTIC33 owns row-interchange serialization.
ELASTIC35 owns bounded Fortran parsing of that interchange.

## Remaining boundary

Still external:
- CRS transformation into EPSG:28992;
- application-host invocation of this offline preprocessing chain;
- automatic generated-prior request from location/profile identity.

## Closure

F-PE-ELASTIC36 is canonically admitted and closed.
