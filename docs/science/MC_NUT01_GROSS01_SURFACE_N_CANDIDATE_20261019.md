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
