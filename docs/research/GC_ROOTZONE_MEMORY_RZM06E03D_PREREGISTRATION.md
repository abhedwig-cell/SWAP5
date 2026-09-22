# GC-RZM06E03D preregistration

**Status:** preregistered response-blind state-library census  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `011d73f42d01dda40efe898483269fdb34deb2aa`

E03D does not generate another forcing family. It reuses immutable qualified 16-node strict Reference state evidence from D04, E01, E03, E03B and E03C.

The unresolved question is narrower than E02: can two accepted origins have both the same total profile water and the same upper-30-cm water, while differing materially only in how the remaining water is distributed over 30 to 160 cm?

For every reconstructed state E03D computes from node `theta` only:

- total profile water over nodes 1 to 16;
- upper-30-cm water over nodes 1 to 3;
- deep water over nodes 4 to 16;
- deep distribution centroid over nodes 4 to 16.

The frozen pair gate is:

- `|ΔW_profile| <= 1e-4 cm`;
- `|ΔW_root30| <= 1e-4 cm`;
- `|ΔM_deep| >= 1e-2 cm`.

Bit-identical states are deduplicated. Ranking uses the largest deep-centroid separation first, then the smallest root30 mismatch and total-water mismatch. Root-zone centroid is diagnostic only and cannot rescue a failing pair.

The census is protected by a response firewall. The parser may use only minimal state provenance plus node `H/theta`. Source-level aggregate fields, solver diagnostics, fixed-`H_c` response, exchange, terminal flux and tangent information are ignored.

The immutable source artifacts, including exact run ids, artifact ids and digests, are frozen in the JSON preregistration. No source may be added after seeing the result. If no pair passes, E03D closes NO_MATCH. If a pair passes, it must be persisted before E04 is preregistered.
