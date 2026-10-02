# TOP03 bounded unchanged-source temporal retry research

Baseline134570b1d3b4b9f50e8fc5c8d1eff13eb3be598c, canonical0d44f0195c94a9732c67b5e77f2148912df9bbc8. Branch refs and AGENTS rechecked, unchanged. This follows the single step86 branch-local root-gap diagnosis. No physical/reference change, no production solver change, no participant or kernel acceptance change.

Capture the exact accepted origin before failed step86 in the shallow dry/ramped-head trajectory,2048 fixed steps over0.25 day. Replay its original interval1.220703125e-4 day with (1) uniform subdivisions1,2,4,8,16,32,64; (2) two-piece partitions1/4,1/3,1/2,2/3,3/4; (3) adaptive nonlinear rejection with halving and growth1 or2. Each packet starts from the same origin. Each accepted solve updates only packet-local state. A failed solve contributes no state/flux. Stop at the inherited minimum1e-6 day or2000 attempts; do not change that floor to force success.

Keep original piecewise constitutive law, frozen interior-conductivity policy and already researched pressure-aware line search,80/16 bounds and all mass tolerances. External head is0.02 cm throughout this late interval. Require accepted soil mass, surface closure, packet mass, exact origin preservation, deterministic O0/O2 identity and unchanged surrounding baseline trajectory. Report completion as entire original interval, not one accepted retry; compare complete-window top/bottom transfer and endpoint storage where packets complete. Successful packets do not establish full-horizon accuracy, real transaction acceptance or production qualification.

No broad Actions; narrow local runner. If subdivisions/adaptation fail before completing the original interval, falsify this bounded retry recipe and do not silently continue with a rejected endpoint.
