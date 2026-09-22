# GC-RZM06E09 preregistration

**Status:** preregistered response-blind near-interface state construction  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `0c13b1fc1e003f5e494d9f7ef7ec9f91b980ed4b`

E08 supports a different fixed-interface response at joint `1e-9 cm` aggregate-storage resolution, but the E07 node-6/node-16 construction has no H16-qualified pair at `1e-10 cm` or exact root30 equality.

E09 introduces a new local basis rather than extending E07. Equal internal matrix source and sink are confined to nodes 15 and 16, centred at 145 and 155 cm depth. Both are far below root30 and one is directly adjacent to the fixed interface.

The two directions are exact twins:

- LOCAL_UP: source node 15, sink node 16;
- LOCAL_DOWN: source node 16, sink node 15.

Every interval retains `q_top=q_bottom=q_eq=-K0`. Internal source and sink magnitudes are exactly equal. The frozen rates are `{1/64,1/32,1/16,1/8,1/4,1/2}*K0`, with exactly 1 or 2 strict intervals.

Selection compares only opposite-direction twins with identical rate and duration. It uses committed H/theta only. The joint storage ladder is `1e-9, 1e-10, 1e-11, 1e-12, 1e-13, 1e-14 cm`, plus exact numeric equality. Every selected pair must also satisfy `|ΔH16| >= 0.01 cm`.

If exact numeric equality qualifies, the exact rung has authority. Otherwise the tightest qualifying numeric rung is selected. All node states are persisted before any later fixed-`H_c` response test.
