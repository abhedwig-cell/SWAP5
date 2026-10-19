# MC-NUT01 GROSS01: corrected surface-N control-volume candidate

## Purpose and status

The 2026-10-19 MC-NUT01 final review identified a non-invertible atmospheric boundary: equal signed net water can represent different gross precipitation and evaporation, hence different atmospheric NH4/NO3 input. This candidate restores the missing information with independently supplied **gross chemical source amounts** and a water-consistent **surface N inventory**. The existing admitted aggregate soil-N owner is unchanged.

**Status:** process candidate, not historical SWAP4.3.1 equivalence and not canonical admission.

## Conservative interface

Inputs are accepted gross rain, irrigation, runon, infiltration, runoff and evaporation depths in cm, together with chemically sourced NH4/NO3 masses in kg N/m2, initial dissolved pond stocks and initial dry surface stocks. The hard water identity is

`pond_end - pond_start - gross_rain - gross_irrigation - gross_runon + infiltration + runoff + evaporation = 0`.

The two species independently satisfy

`initial_pond_N + initial_dry_N + gross_external_N = final_pond_N + final_dry_N + soil_infiltration_N + runoff_export_N`.

Evaporation has zero direct N export. Under instant complete mixing, wet exports share a concentration based on `pond_end + infiltration + runoff`. When that denominator is zero, external atmospheric mass becomes **dry retained deposition**, rather than being discarded. Future wetting may remobilize that stock. This is an *explicit corrected B1 hypothesis* requiring scientific review, not an assertion that the historical source always used this ordering.

## Reproduced blocker cases

For 4 mm rain and 4 mm evaporation at a net-zero water endpoint, original source-based external input of 0.000020 kg NH4 N/m2 and 0.000060 kg NO3 N/m2 remains in the dry surface store. There is no fictitious zero-net-water transport to the mineral soil compartment. A subsequent 4 mm wetting with 2 mm infiltration, 1 mm runoff and 1 mm remaining pond partitions that retained inventory between soil, runoff and water storage in ratios 2:1:1, preserving each species. Fabricated water flux is rejected.

This resolves the **gross-versus-net identifiability problem in the candidate process**, but not the historical timing/equivalence question: original soil-N handling may enter N directly in soil in this counterexample. Source ordering and surface sorption/dissolution policy must be settled before promoting this new route.

## What is still required before admission

1. Consume accepted gross water flux trace from the Reference hydraulic owner, not independently supplied speculative forcing.
2. Choose and validate surface N dry-deposition/mixing/ponding policy against historical source and plausible physical constraints.
3. Add persistent NH4/NO3 surface owner with revisions and process-safe restart, not surface-age substitution.
4. Stage coupled soil-N, surface-N and hydraulic candidates and commit/rollback once, preserving no-double-counting accounting.
5. Execute actual Richards water + full mineral N time windows, positive runon/runoff, rejection/retry, and independent-process restart with O0/O2.
6. Preserve existing qualified MC-NUT01 and MC-SOL01 contracts, and obtain new admission evidence before canonical merge.

Native gate: `bash tests/nut-crop/run_surface_n_gross_budget.sh`; GitHub Actions run `39302906079` succeeded for O0/O2 at the initial candidate head. This is **isolated process evidence** only. The original gross/net witness remains the scientific problem authority: `docs/science/MC_NUT01_HIST_GROSS_NET_BLOCKER_20261018.md`.

## Actual accepted Reference gross trace candidate

`src/runtime/mod_b111_surface_n_reference_bridge.f90` now forms the gross rain, irrigation and runon depth from `fmr_water_flux_substep_trace_t` with explicit final-converged gross-source provenance and accepted pond water depths. Infiltration comes from accepted negative qtop, runoff from the accepted runoff depth, and evaporation from the accepted pond evaporation rate; the bridge rejects unsupported snowmelt/exfiltration or invalid source concentrations. NH4 and NO3 precipitation/irrigation/runon concentrations are converted from kg/m3 to kg/m2 by `0.01 * depth_cm`. The bridge then uses exactly the independent N-volume budget without changing the hydraulic net water carrier. An actual typed Reference trace oracle and O0/O2 full module-closure compile were added to the targeted workflow in run `39303390381` (queued at the time of authoring). This is **not** a proof that a production Reference trial called the bridge or atomically committed a mineral-soil transfer.

## Native historical mineral owner opt-in alternative

The existing `advance_mineral_day` in `src/process/mod_b111_soil_n_mineral_owner.f90` now offers an optional `gross_surface_n_carrier` in **m/day**. It is independent from the unchanged signed `surface_water` hydrological carrier: water closure continues to use signed net water, while `evaluate_b111_soil_n_transport` uses the opt-in gross value for chemical atmospheric NH4/NO3 input. The external N ledger uses the same gross amount. With the parameter absent, the legacy `max(0, net)` path is identical.

This is a bounded **direct historical-style soil source** alternative to the new surface pond/dry deposition hypothesis. The two mechanisms MUST NOT deliver the same N to soil on the same step. The separate explicit surface control volume remains an experimental corrected-B1 candidate for cases requiring pond/runoff retention, whereas the opt-in direct source follows the original `Wofost_SoilWaterN` atmospheric transport convention for the non-ponded gross/net witness. Only an accepted Reference hydraulic source may authorize the future opt-in production call; this change does not itself prove source provenance, calling order or integrated all-process admission.

Native targeted `test_mineral_gross_carrier.f90` exercises 0, 4 and 8 mm gross infiltration-source equivalents under unchanged zero-net water, checks both species amounts, exact owner ledger closure, rejected negative gross input and unchanged state on rejection. O0/O2 job `historical-mineral-owner-o0-o2` was added in GitHub run `39303817500`; do not claim PASS until its terminal result is confirmed.

## Bounded original-style Reference-to-mineral path

`mod_b111_n_gross_direct_binding.f90` extracts a gross **rain-only** chemical carrier (m/day) from a getypeerde, accepted Reference water substep. It explicitly rejects nonzero stored pond, runoff, snowmelt, runon and irrigation, because the original single `c_top` cannot represent mixed source concentrations without further contracts. It keeps the signed net hydraulic carrier separate from the gross atmospheric N source. The production mineral owner supports the separate optional `gross_surface_n_carrier`; unchanged callers still receive the old net-only default. This is a bounded source bridge candidate; a real end-to-end production caller has **not** yet been wired to carry this receipt into a joint commit.

The native bridge test checks 4mm rain plus equal evaporation, correct 0.004m/day conversion and fail-closed pond/runon cases. The original source comparison uses the pinned B1.11 SWAP4.3.1 watern routine with NH4/NO3 at 0, 4 and 8mm atmospheric rain. The newest scoped GitHub run is `39304855073`, queued at the time of this update. No new whole-historical admission is claimed without that evidence and real coupled rollback/restart qualification.

## Reference-to-mineral candidate composition, 19 October 2026

`src/runtime/mod_b111_n_reference_mineral_trial.f90` now takes a source-validated Reference accepted water-flux receipt and stages a **copy** of the actual `mineral_state_t`. The hydraulic surface carrier is computed from signed qtop (upward-positive cm/day to downward-positive m/day), whereas the independently admitted analytical nitrogen source receives only the bounded, rain-only gross chemical carrier. The existing mineral owner's water closure remains in force. On failed mineral validation it discards the candidate and retains the committed mineral state. The O0/O2 test checks NH4/NO3 inventory increments, retained original owner/revision and rejected runon without mixing policy. This still **does not** constitute a complete hydraulically atomic joint application: the Reference water trial is not committed by this helper, and end-to-end native Richards restart remains absent. New focused run `39305169920` was queued at the last read. Do not claim admission or merge from these isolated gates.

## Transactional multi-day mineral stage (19 October 2026)

The private `trial_mineral_gross_days` now consumes a sequence of **accepted typed daily hydraulic receipts**, derives each bounded rain-only gross N carrier and stages actual mineral-owner candidates over successive days without committing the original. A rejected later day discards the whole candidate; the committed mineral owner is not modified. The native oracle includes two successive gross days and a deliberately rejected day 2 with zero committed NH4/NO3 revision and time change. This is explicitly **not** the common hydraulic+chemical transaction executor; it is a prerequisite candidate stage. The O0/O2 gate for this source revision is `39307333483`, queued at the time recorded. No PASS can be claimed for this revision yet.

## Signed qtop identity and source gate

The bounded direct rain-source binder now additionally verifies that, for its zero-pond/no-runon/no-irrigation/no-runoff domain, the actual accepted upward-positive top flux obeys `-qtop = gross_rain - pond_evaporation` (cm/day), within a magnitude-scaled 1e-10 tolerance. An inconsistent trace is rejected before the independent gross-N transport coefficient can enter the mineral owner. The native negative oracle changes only qtop with identical gross rain/evaporation and asserts rejection; retained old callers without opt-in are not modified. This strengthens physical provenance, but does not replace real Richards+soil-N joint commit/restart tests. Dedicated post-change workflow run `39307796665` was queued at the last check; no PASS is claimed for this newest source revision.

Canonical had advanced by seven commits relative to this candidate branch at the last check. Reconciliation is mandatory prior to any admission.

## Auxiliary carrier rejection extension

The staged mineral trial now explicitly rejects negative external auxiliary fluxes before calling the mineral owner. A native oracle checks that a rejected negative root carrier does not change the committed mineral revision or stock. This guards the rain-only accepted Reference candidate domain; it is not an extension of historical soil-N admission. New source-exact hosted test run `39311282815` was queued at the last status check. Earlier joint-scope runs also remained queued. Canonical was nine commits ahead of this draft branch at the latest comparison; no integration is authorized without reconciliation and physical joint qualification.

## 19 October: verified gates and committed clock consistency

Hosted runs `39307333483`, `39307796665`, and `39311282815` each completed SUCCESS across the isolated, original-mineral-owner and Reference gross bridge O0/O2 jobs. A new fail-closed guard verifies the accepted Reference trace begins exactly at the committed mineral owner clock, and a new native negative test rejects a stale trace without changing the original owner. The post-change run `39319743593` was queued at last read, so these earlier passes do not qualify the latest source. No hydraulic+mineral N common-commit application or native fresh-process whole-N restart has yet passed. This PR remains draft and outside canonical.
