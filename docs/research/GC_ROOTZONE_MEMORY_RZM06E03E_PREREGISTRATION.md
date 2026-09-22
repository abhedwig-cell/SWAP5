# GC-RZM06E03E preregistration

**Status:** preregistered response-blind interface-state census  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `446300e92b135c8dffee833f7f5b85876bb75ca2`

E03D found 59 immutable state pairs that match both total profile water and upper-30-cm water within `1e-4 cm`, but none with a materially different deep-profile centroid. A direct response comparison of all tolerance-matched pairs would be hard to interpret because the small remaining storage mismatches could themselves explain small response differences.

E03E therefore remains response-blind and asks a more mechanistic state question first. It reuses exactly the E03D state library and searches only storage-matched pairs for a materially different pressure head in node 16, the SWAP node adjacent to the fixed groundwater interface.

The frozen gate is:

- `|ΔW_profile| <= 1e-4 cm`;
- `|ΔW_root30| <= 1e-4 cm`;
- `|ΔH16| >= 0.01 cm`.

The `0.01 cm` H16 threshold is fixed before the census and is many orders above the carrier's head convergence tolerance. It is a state-separation gate, not a response threshold.

Selection uses only node `H/theta` and immutable provenance. Bottom-node water content and root-zone centroid may be reported diagnostically but cannot rescue a failing pair. No fixed-`H_c` response, bottom exchange, terminal flux or tangent information may enter the selector.

If a pair passes, all 16 node states are persisted before E04. E04 may then reuse the already qualified E02 fixed-`H_c` probe, with total and root30 storage gates rechecked before any response is evaluated.
