# GC-RZM06E05 preregistration

**Status:** preregistered response-blind nested-resolution census  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `21bbfdf16edbe842647b345223454bd3507a1a03`

E04 found a deterministic fixed-`H_c` response difference for a pair with exactly equal total profile water and upper-30-cm water matched within `1e-4 cm`. That supports non-uniqueness only at that aggregate resolution.

E05 therefore contains no response experiment. It reuses exactly the immutable D04/E01/E03/E03B/E03C state library and asks how tightly both storage coordinates can be matched while retaining `|ΔH16| >= 0.01 cm`.

The frozen tolerance ladder is:

`1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9, 1e-10, 1e-12 cm`.

A separate exact rung requires numeric equality of both reconstructed `W_profile` and `W_root30`.

For every rung, selection is response-blind and uses only node `H/theta` plus provenance. A pair qualifies only when both storage differences are within the rung and `|ΔH16| >= 0.01 cm`. The selected pair, if any, comes from the tightest qualifying rung. Within that rung, ranking is largest `|ΔH16|`, then smallest root30 mismatch, then smallest profile-water mismatch.

If no rung tighter than `1e-4 cm` contains a qualifying pair, E05 closes the present library as a resolution ceiling. No tolerance is relaxed and no new artifact is added after observing the census.
