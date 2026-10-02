# Explicit-layer refinement extension

Date: 2026-10-02
Status: PREREGISTERED_EXTENSION_BEFORE_EXECUTION

Primary experiment source: `657f3db099dfb999d1174f7a800ff7918ee767d1`. Its 400 records per O0/O2 build are identical. All 48 weighted-harmonic analytical controls pass; dry R>=0.5 trajectories complete, but none of the initially declared eventwise comparisons has a ready space-and-time reference. The 32->64 temporal differences are still too large; some spatial differences are non-contracting even though already small. This does not authorize relaxed budgets or physical equivalence claims.

Extend only resolution: m=[4,8,16,32], n=[64,128,256,512] per original event. Keep both L=[0.02,0.20] cm decompositions, R=[0.50,1.00] day, explicit dry and separately labeled prewetted-layer origins, and reduced comparators. Same soil, lower mode7, stages, event lengths, solver gates, constitutive shortcut and harmonic face mean. No retries or altered timestep policy. Expand unused legacy stub capacity to256 solely to support explicit request grids of up to192 nodes.

R=0 and R=0.05 remain recorded numerical failures from the primary factorial, not physical falsifications. Do not tune or repair them in this extension.

Reference readiness now uses the finest three available refinements for each axis: time128/256/512 at m32 and space8/16/32 at n512. Apply all original contraction and absolute/relative budgets unchanged. Compare the six event endpoints, with event1 identified as onset and event6 as full horizon. If a finest chain remains unready, report a concrete numerical-reference blocker for that chain. A physical falsification is allowed only where both chains are ready.

Add observation-only explicit-layer endpoint pressure extrema and min/max K(h)/Ksat to distinguish initially missing storage from persistent unsaturated layer resistance. These diagnostics run after accepted solves and cannot change the candidate, origin, provider law or subsequent solver data. Saturated analytical controls and unchanged prior contact-law preservation are already passed and their evidence remains separately pinned.

Next expensive action: execute this extension at O0/O2 against its persisted test postimage; keep raw outputs and manifests for both primary and extended source versions. No production or canonical admission.
