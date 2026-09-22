# GC-RZM06C01 richer real-SWAP carrier qualification

Date: 2026-09-22  
Machine-readable preregistration: `11ae66fb732e404cf9f51391c693a1db21e2470a`  
Production changes: none

## Carrier decision

The four-node F-GC44 fixture has reached its useful H2 construction ceiling. GC-RZM06C01 therefore moves the research line to the already qualified F-ROM1A-I0 pure-hydraulics Reference carrier:

- 16 nodes;
- 10 cm layer thickness;
- 160 cm profile depth;
- B01 homogeneous hydraulic material;
- real HeadCalc through the serialized Reference backend;
- explicit B110 MvG constitutive provider;
- immutable committed origin, opaque candidate, explicit commit/discard;
- strict single physical Reference advance;
- hard transaction mass gate of `1e-12 cm`.

The upper 30 cm now contains three separately resolved nodes.

## Why this carrier

Hupsel has stronger application realism and has been whole-run qualified, but its exact raw case and transaction snapshot payload are not durably materialized in the repository or retained M1-C3 artifacts for independent coupling-origin reconstruction.

The F-WOF PP02 fixtures are crop-state fixtures, not hydraulic profile carriers.

The existing F-GC44 and MAP carriers inherit the four-node geometry already diagnosed in RZM06A6.

The F-ROM1A-I0 carrier is therefore the strongest currently replayable research carrier that already has qualified Reference, mass, state and transaction semantics.

## Current-branch requalification

C01 does not rely only on historical qualification. On the current branch it rebuilds the 16-node geometry with the existing ROM test materializer and qualifies:

1. `n = 16`, `dz = 10 cm`;
2. the upper 30 cm spans exactly nodes 1 through 3;
3. B01 initial state at `Se = 0.85`;
4. bottom mode 5;
5. public coupling head mapped through the existing `fmr_groundwater_head_forcing_materializer_t`;
6. mapped bottom pressure head equals the intended Reference boundary value;
7. one strict accepted physical advance with complete mass accounting;
8. the uncommitted sample leaves the committed origin unchanged;
9. discard leaves the committed origin unchanged;
10. explicit commit advances exactly one revision and one sample interval;
11. a controlled failed sample leaves revision, time and physical state unchanged;
12. O0/O2 output identity.

The lower face datum is `-1.6 m`, consistent with the 160 cm column.

## Scope boundary

This is research carrier qualification only. It does not admit the ROM observation seam as a production groundwater-coupling API and it does not test H2.

If C01 passes, C02 will use the separately qualified ROM1AR2 768-state artifact as a response-blind accepted-state source. H2 response will remain unavailable until a pair satisfies the preregistered state-selection criteria.
