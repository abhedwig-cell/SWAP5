# GC-RZM06E09A preregistration

**Status:** preregistered response-blind local-interface census  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `e151ee9c19c58d27c7f446d60c1042743f507882`

E08 supports residual fixed-interface response memory while total profile water and upper-30-cm water are matched at the frozen `1e-9 cm` aggregate-storage resolution. The E08 pair still differs in the bottom-node pressure head `H16`.

E09A asks the next structural question before opening any new response fields: can two already qualified E07 endpoints be matched in `W_profile`, `W_root30` and `H16`, while retaining a materially different immediately overlying state `H15`?

The primary state controls are frozen at:

- `|ΔW_profile| <= 1e-9 cm`;
- `|ΔW_root30| <= 1e-9 cm`;
- nested `|ΔH16|` matching rungs from `1e-2` through `1e-9 cm`;
- `|ΔH15| >= 1e-2 cm`.

The local pressure-gradient diagnostic is `(H16-H15)/10` for the 10-cm node spacing. H15 and H16 were chosen from the hydraulic structure before response access, not from response correlation.

The census uses only the immutable E07 qualification artifact and parses committed H/theta plus provenance. Bottom exchange, terminal flux and E08 response are forbidden to the selector.

If a pair exists, the tightest H16-matching rung is selected and its complete 16-node state is persisted before any E09B response probe. If no pair exists, E09A closes as NO_MATCH without relaxing thresholds.
