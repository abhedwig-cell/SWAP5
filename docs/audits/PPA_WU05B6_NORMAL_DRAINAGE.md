# PPA-WU05B6 normal frost drainage composition

Status: implemented and locally tested candidate; central qualification and admission pending.

The explicit `frost_drainage` option composes the ordinary legacy normal FrozenBounds nodal rule with Reference mode2 and prescribed signed drainage by level/node. Each final nodal flux is its immutable proposal multiplied by the trial-start hydraulic frost factor. Level and aggregate diagnostics derive from these final nodes. The existing source/sink provider and mass owner book the final node flux once; the bottom flux keeps its separate existing owner.

The proposal is retained as disposable worker input and reused for each full, half and retry trial. It is never progressively scaled. No new physical continuation state or restart payload is introduced. The sensible temperature owner remains unchanged; this capability does not add ice content or latent heat.

The shared source-bound branch classifier retains the decrement-before-test deepest index and bottom-up available-air rule. A deep frozen profile with available air below 0.01cm rejects before solver execution. The normal branch needs no drain depths or frozen-depth interpolation. Outlet heads are not inferred to be physical drain depths. Air-threshold equality and last-node-only freezing keep the existing reference indexing semantics.

The option requires finite positive local head and temperature budgets and external full/half temporal comparison. Its temporal norm uses the maximum of head and temperature errors and rejects terminal candidates in the excluded low-air branch. Initial local budgets are head1e-6cm and temperature1e-7C; qualification retains separate cumulative head1e-6cm and temperature1e-4C bounds rather than claiming a local tolerance is a cumulative error bound. Hard mass remains 1e-12cm.

The actual unchanged B1 FrozenBounds component is compared at O0/O2 across 27 signed normal-branch cases, with factor transitions, shallow freezing, and the reference last-node exclusion. Additional probes exercise inactive exact copy, low-air rejection, the exact air threshold, NaN factors, missing budgets and unrepresentable report totals. This is a FrozenBounds component claim, not a full legacy simulation.

The actual runtime matrix has twelve signed multilevel drainage/bottom cases, including opposing level exchanges. It exercises real retries, fresh worker replay, 2048-step direct trajectories, accepted-state restart export and empty-registry restore, normal application execution, and unchanged committed state on a rejected low-air profile. An air-rich all-frozen case verifies zero actual drainage and zero ledger exchange. The existing hydraulic-only, root, no-drain bottom and joint root/bottom fixtures are rerun using the candidate's freshly compiled O0/O2 modules.

The [corrected reporting reference](PPA_WU05B5_CORRECTED_B1_DRAIN_REPORT.md) remains the authority for the separate low-air ordinary branch. It does not expand this unit's claim. Active drainage-response generation, SWDIVD=1 redistribution, low-air drain geometry, root/salt/macropore/snow combinations, frost-bottom composition, groundwater-owned bottom and new phase-change physics remain outside this admission.

Preregistration: `integration/audits/PPA_WU05B6_PREREGISTRATION.json`. Run `bash tests/frost/run_ppa_wu05b6_normal_drain_source.sh` and `bash tests/frost/run_ppa_wu05b6_normal_drain_runtime.sh`.
