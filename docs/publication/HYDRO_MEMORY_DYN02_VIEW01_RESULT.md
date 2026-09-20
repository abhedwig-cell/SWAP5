# HYDRO-MEMORY DYN02-VIEW01 result

**Decision:** `DYN02_VIEW01_QUALIFIED_RESTRICTED_TEMPORAL_CARRIER`

DYN02 run 35460379501 exposed a narrow adapter mismatch rather than a forcing, Feddes or groundwater failure. The committed state used by the governed temporal route is `fmr_b110_temporal_indicator_state_t`, which extends the physical SWAP state. The process hydraulic-view binding previously accepted only the exact base type.

The qualified change adds one explicit temporal-carrier branch. It copies only the inherited hydraulic fields used by process physics. It deliberately does not use a broad `CLASS IS` selector, so fixed-weir, evaporation and unrelated continuation carriers are not silently admitted.

Final qualification: workflow **35501364477**, job **106053581783**, head `23c2bfe07763ba26bbcc15fb650e27a1380fb352`.

Evidence:
- plain physical carrier: PASS;
- temporal-history carrier: PASS;
- hydraulic fields bit-identical between both carriers;
- committed revision/time unchanged;
- unrelated transaction carrier: fail-closed as required;
- O0/O2 output identity: PASS.

No root-water-uptake equation, Richards equation, forcing composition, timestep/accuracy policy or groundwater-coupling logic changed.

The next step is to rerun the existing DYN02 preregistration from canonical including this adapter authority.
