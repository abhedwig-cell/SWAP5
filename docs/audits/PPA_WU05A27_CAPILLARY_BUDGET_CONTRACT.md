# A27 capillary-capacity/history diagnostic

Status: PROPOSED_RESEARCH_ONLY. Date: 2026-10-02 UTC.
Pinned A27 source: 0b989d5fcfbb01f40cfcca48e78b4c549ee2c354.
Pinned canonical: 828df126e0c0d70f5cbfae51614bfc3b53e832a4.
Production composer, A26H state and all solver interfaces remain unchanged.

## Source reconciliation

The current SWAP theory manual, https://swap.wur.nl/manual/06_macropore_flow.html, section 6.3.2 equations 6.42-6.45, describes sorptivity as a first-contact quantity with an adjustment for moisture changes from other matrix processes. It also provides diffusion as an alternative. It does not establish the proposed reduced-model capacity closure below.

Repository standard sorptivity implementation: mod_ppa_wu05a6_sorptivity_rate has history sorptivity, absorption time and theta-reference, plus an actual saturation-deficit gate; mod_ppa_wu05a6_sorptivity_history updates the theoretical reference and resets events; unsat_absorption_rate selects max(sorptivity,Darcy). These are behavioral/source locators, not automatic physical truth. A26H instead explicitly preserves one endpoint-wide event S while wet. Do not silently overwrite that accepted production contract.

## Proposed closure and scope

For a finite wetted node segment, first calculate the existing analytically integrated max(Philip,Darcy) potential P. Calculate its nonnegative Darcy-only integral D independently. The capillary enhancement above Darcy is E=max(0,P-D). Supply the explicit accepted-state matrix water deficit B=max(0,theta_s-theta)*dz in areic cm. Proposed actual potential is D+min(E,B), before the existing total receipt/receiver-water budgets.

This limits only the transient capillary enhancement, not saturated hydraulic through-flow. It preserves the max-law potential when the capillary budget is inactive. It is not an additive independent Philip-plus-Darcy source. A26H event seeds can remain stored even when their current extra uptake is zero. As B tends to zero near matrix saturation, E_actual tends to zero, while the saturated/unsaturated Darcy limits match for this finite segment.

This is a physically motivated necessary-capacity diagnostic, not a derived transient wall PDE or calibrated/validated uptake law. Vertical redistribution may replenish capacity during a step; freezing B is an explicit split hypothesis. A bounded and continuous flux does not prove an adequate physical closure.

Add optional per-contact accepted ages and capillary budgets to the research-only request. Preserve absent-field behavior exactly. First-wet node S is seeded from the actual constitutive sorptivity provider and then retained. Node contact age advances only while the accepted receiver wets that node; fully dry contact resets. This remains one clock per node, not per newly wetted wall fraction.

## Preregistered falsifiers and experiments

1. Reproduce the old frozen-S saturation jump, then sweep budget toward zero on both head sides. The proposed amount must converge to the same signed Darcy limit.
2. Zero capillary budget must not remove saturated Darcy receipt or reverse drainage.
3. Test capillary bound, full/empty receiver, deterministic replay, NaN/shape errors and O0/O2.
4. Explicit mixed-age wall counterexample: compare an old 50% wet contact plus a newly wet 50% contact against homogenizing their age. Equal mean age/S need not imply equal square-root uptake. If unequal, one scalar node/endpoint clock is not a closed representation.
5. Extend the existing real-Richards column fixture with mode 5 (finite geometry, node-frozen event S, unbounded capillary term) and mode 6 (same history, proposed capillary budget). Run all 2 Ks x 3 initial states x 7 modes x 5 timestep resolutions = 210 cases. Retain matrix/receiver trajectories, whole-column ledger, solver counters and research CPU values. Five resolutions are 0.002 to 0.000125 day.
6. This remains an ablation with zero rain and a controlled bottom-head change. No full production A/B/C, performance superiority, ensemble scaling or E1 production claim is permitted from it.

A successful saturation boundary test can remove that local flux discontinuity, but cannot waive a failed mixed-contact-memory test. The experiment must distinguish resolved capacity pathology from unresolved state sufficiency. No production dispatch, persistence layout or central regie authority is changed.
