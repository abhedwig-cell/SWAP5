# F-ROMV2 D31 — M2WC70 source-retrieval reconciliation

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D31  
**Decision:** **M2WC70_OFFICIAL_ARCHIVE_CONFIRMED_BUT_RETRIEVAL_BLOCKER_PERSISTS_NO_EQUIVALENT_ORACLE_FOUND**

## Purpose

D30 closed the natural surface-connected infiltration-front / groundwater-front contact transition as an external implementation-authority blocker.

D31 does not reopen that scientific decision. It records a fresh source-acquisition reconciliation so that future work does not silently treat the blocker as resolved or repeat weaker substitutes.

## Official archive authority

The University of Wyoming DataCorral repository entry for dataset **M2WC70** remains publicly indexed:

- title: *A New General 1-D Vadose Zone Flow Solution Method*;
- creator: Fred L. Ogden;
- publication year: 2015;
- resource type: dataset;
- advertised archive: `M2WC70.zip`;
- advertised size: 230 MB;
- official archive URL:
  `https://pathfinder.arcc.uwyo.edu/publications/Computational_Hydrology/M2WC70/M2WC70.zip`;
- rights: CC0 / public-domain dedication.

The primary Ogden et al. (2015) paper also identifies DOI `10.15786/M2WC70` as the code/data source for the eight-month finite-water-content experiment.

## Retrieval result on 2026-09-20

The metadata page was reachable and exposed the official archive URL.

The archive itself was not materialized:

1. following the official resource link through the available web route timed out;
2. a direct download attempt through the available execution route also failed;
3. targeted searches for a traceable public mirror of the M2WC70 archive did not identify one.

Therefore no archive bytes were obtained, no digest can be recorded, and no authors' FMC source routine has been inspected.

## Alternative-source check

A relevant secondary lead exists in HydPy documentation for **GARTO**. That documentation states that two authors of Lai et al. (2015), Fred L. Ogden and Cary A. Talbot, supplied original C source used to check the HydPy GARTO implementation.

This does **not** resolve D30.

GARTO is a different reduced front representation from the M2WC70 finite-water-content method. The HydPy implementation further documents material differences from the complete GARTO groundwater treatment. It is therefore not treated as an implementation oracle for the M2WC70 natural FMC surface-front / groundwater-front state conversion.

The companion 2015 GARTO and finite-water-content validation papers provide useful groundwater/front context, but do not unambiguously specify the D29 within-step FMC contact-event ordering identified by D30.

## Authority consequence

D30 remains unchanged:

`NATURAL_SURFACE_GW_CONTACT_EVENT_UPDATE_UNDERSPECIFIED_WITHOUT_IMPLEMENTATION_ORACLE`

D31 adds only a stronger source-acquisition statement:

`M2WC70_OFFICIAL_ARCHIVE_CONFIRMED_BUT_RETRIEVAL_BLOCKER_PERSISTS_NO_EQUIVALENT_ORACLE_FOUND`

No contact-capable long-window trajectory is authorized.

No D29 Stage 2 is reopened.

No GARTO state-transition rule may be substituted into FMC by analogy.

Native ET remains separately blocked by D28.

Production ROM remains unauthorized.

## Next admissible action

Only one of the following can move this frontier:

1. materialize the official M2WC70 archive and record immutable provenance plus digest;
2. locate an independently traceable copy of the same authors' FMC implementation;
3. locate an equally authoritative implementation description that uniquely determines the natural surface-front / groundwater-contact event ordering.

After that, write a clean-room event specification and preregister a microscopic contact-event preflight before any long-window R16/R2 trajectory.
