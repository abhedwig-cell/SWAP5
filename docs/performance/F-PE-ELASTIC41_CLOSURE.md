# F-PE-ELASTIC41 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@3bb557151dd3d86dfed64d0d5ff429c07a9b246a`

Merged PR:
`#883`

Admitted preprocessing file:
`tools/fpe_elastic41_rd_application_handoff.py`

Admitted preprocessing blob:
`714193f455a91897ccf87a0aa9f5a082b0c94302`

## Admission summary

F-PE-ELASTIC41 admits request-gated offline handoff from an already resolved
EPSG:28992 RD point through ELASTIC36 spatial/profile preprocessing to the
canonical ELASTIC33 row interchange and provenance artifact consumed by the
admitted application-side chain.

Request=false remains source-independent and produces no outputs.

No CRS transformation, live network access, automatic request creation or SWAP
runtime mutation is introduced.

## Qualification authority

Qualified branch:
`research/f-pe-elastic41-rd-end-to-end`.

Qualified result head:
`0cd206cc2a83be0e1828ef658e892d6ca18623a3`.

Workflow run:
`36595836774`.

Job:
`109500386721`.

Conclusion:
SUCCESS.

Passed:
- inactive request requires no source access;
- ELASTIC36 row/provenance identity over 64 real-source RD points;
- ELASTIC33/35/37-consumable row files;
- spatial and missing-source failures fail closed;
- repeated byte/provenance identity;
- explicit request discovery;
- real profile application binding;
- positive generated priors;
- explicit/user ELAS ownership preservation;
- O0/O2 identity;
- zero `src/**` changes.

Selected real profile in both O0/O2:
- profile `90116260`;
- maparea `V2025-1..soilarea.0000003954`;
- RD point `179362.75550490862, 418659.84937244334`.

## Qualification-driven repairs

The route was not physically changed during qualification.

Repairs were restricted to:
- correcting provenance schema overwrite order;
- reusing loaded polygon authority in tests;
- restoring the Fortran composition preparer;
- emitting valid real64 literals;
- deallocating generated fixture arrays before reuse;
- diagnostic test syntax/signature fixes.

## Ownership boundary

ELASTIC41 owns only offline request-gated RD preprocessing and explicit output
handoff.

It does not own:
- CRS transformation;
- request generation;
- source/output path discovery;
- live BRO/PDOK access;
- application binding semantics;
- runtime parameter mutation.

ELASTIC37 remains binding authority.

## Related qualified research result

ELASTIC42 independently qualifies the full explicit RD-point + explicit request
composition through to an active positive ELAS postimage. Its admission is
research evidence only and does not remove the CRS dependency blocker.

## Remaining boundary

Still open or externally blocked:
- geographic coordinate -> EPSG:28992 transformation;
- dependency/governance decision for CRS tooling;
- any future explicit application-host subprocess integration for offline
  preprocessing.

## Closure

F-PE-ELASTIC41 is canonically admitted and closed.
