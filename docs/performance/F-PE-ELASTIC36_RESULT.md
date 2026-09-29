# F-PE-ELASTIC36 — RD point to BRO profile-row interchange result

Date: 2026-09-29

Status: QUALIFIED_OFFLINE_PREPROCESSING_CANDIDATE

Branch:
`research/f-pe-elastic36-rd-point-profile-interchange`

Qualified postimage:
`12165549601a43744b652bd13416938a41a1f9d7`

Workflow run:
`36589811329`

Job:
`109479659647`

Conclusion:
SUCCESS.

## Qualified composition

`RD point`
-> ELASTIC34 strict maparea selection
-> exact `soilarea_normalsoilprofile` relation
-> ELASTIC24 explicit profile retrieval
-> ELASTIC33 canonical row interchange.

The output is the admitted `SWAP5_ELASTIC33_BRO_ROWS_V1` format plus exact
maparea/profile/source provenance.

## Qualification

- A1 parent source/hash/relation authority preserved: PASS;
- A2 real-source maparea selection: PASS;
- A3 selected profile ID equals direct SQL oracle: PASS;
- A4 ELASTIC24 explicit profile retrieval identity: PASS;
- A5 ELASTIC33 output byte-identical to independent direct composition: PASS;
- A6 broad deterministic real-source sample: 64/64 successful points covering
  57 distinct normal soil profiles: PASS;
- A7 spatial BOUNDARY/NOT_FOUND/AMBIGUOUS outcomes propagate fail closed before
  relation access: PASS;
- A8 missing/duplicate relation rows fail closed: PASS;
- A9 repeated same point is provenance- and byte-identical: PASS;
- A10 zero `src/**` production-source change: PASS.

## Ownership boundary

ELASTIC36 owns only offline composition.

It does not:
- transform CRS;
- perform runtime GIS/file I/O;
- access live PDOK/BRO;
- parse the interchange into Fortran rows;
- derive ELAS;
- activate generated priors.

ELASTIC35, now independently present on canonical, owns the bounded Fortran
parser from ELASTIC33 interchange into ELASTIC22 typed source rows.

## Current canonical reconciliation

The canonical delta since the ELASTIC36 baseline consists only of the
independently admitted ELASTIC35 row-interchange parser and does not intersect
ELASTIC36 tooling/tests/docs.

Current observed canonical:
`1d1913723626a4a6c5ae4092c477502e6ad0e434`.

## Decision

Classification:
`QUALIFIED_OFFLINE_PREPROCESSING_CANDIDATE_READY_FOR_ADMISSION`.
