# PPA-WU05-A3 R1 MACROSTATE bookkeeping local result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / LOCAL_INTERFACE_DIAGNOSTIC_IMBALANCE_IDENTIFIED / WHOLE_DOMAIN_MASS_PRESERVED`

## Purpose

Test the standard-route B1.11 `MACROSTATE` reconstruction of vertical macropore flux `QTopMpDmCp` using the refined E7 interface-index rule.

This is not the kinematic-wave solver path. In the kinematic route, `MACRORATE` constructs compartment fluxes directly and contains explicit compartment mass-balance checks.

The standard route reconstructs `QTopMpDmCp` after storage update using:

- top-down recurrence in the unsaturated region;
- bottom-up recurrence in the saturated region.

## Local conservation identity

For a compartment, the physical bookkeeping identity is:

`Delta W / dt = Q_top - Q_bottom - Q_exchange`

for the reduced no-rapid-drain case.

The standard-route source uses actual `Delta W` in the unsaturated recurrence but uses `Delta VlMp` in the saturated recurrence, because saturated compartments are assumed full.

## Test A — stationary interface

The interface remains within compartment 3 while its water content changes.

Result:

- every local compartment residual is below machine precision;
- whole-domain mass closes;
- the two directional recurrences imply one consistent interface flux.

Verdict:

`PASS_STATIONARY_INTERFACE_LOCAL_AND_GLOBAL_MASS`.

## Test B — interface moves upward by one compartment

Previous state:

- compartment 3 partially saturated;
- compartment 4 full.

Current state:

- compartment 3 becomes completely saturated;
- compartment 2 becomes the new partially saturated interface compartment.

Total top input was chosen so the complete domain balance closes exactly with zero bottom outflow.

Result:

- whole-domain mass residual remains approximately zero;
- local residual in new interface compartment: `+0.40 cm d-1`;
- local residual in newly saturated compartment: `-0.40 cm d-1`;
- the two deviations cancel pairwise.

## Interpretation

The refined `icgwl` rule resolves index meaning and bounds safety, but it does **not** by itself make the standard-route reconstructed `QTopMpDmCp` locally conservative when the saturation interface crosses a compartment boundary.

The source reconstructs the upper and lower sides from different state-change quantities:

- upper side: actual water-storage change;
- lower saturated side: macropore-volume change.

When a compartment changes from partially saturated to fully saturated without a volume change, its filling storage change is not represented in the saturated-side recurrence. The corresponding local deficit is transferred as an equal/opposite discrepancy to the adjacent compartment.

Whole-domain water mass remains conserved because these local discrepancies cancel.

## Scope and severity

Current classification:

`LOCAL_VERTICAL_FLUX_RECONSTRUCTION / DIAGNOSTIC_OR_INTERFACE_CONTRACT ISSUE`

not

`WHOLE_DOMAIN_WATER_BALANCE DEFECT`.

Search of the exact B1.11 source shows `QTopMpDmCp` is exported/integrated as `IQTopMpDm1Cp/IQTopMpDm2Cp`, including PEARL/ANIMO output/coupling paths.

Therefore local inconsistency may matter for compartment-resolved transport/coupling even though total SWAP water storage remains correct.

This requires follow-on before R1 is frozen.

## New research question

Should R1 reconstruct standard-route vertical compartment fluxes directly from the universal local conservation identity after accepted storage is known, rather than retaining the historical split top-down/bottom-up reconstruction?

Candidate R1 reconstruction:

`Q_bottom(ic) = Q_top(ic) - Q_exchange(ic) - DeltaW(ic)/dt`

applied monotonically top-to-bottom over the complete domain after all accepted storage and external drainage terms are known.

This would be deterministic, locally conservative and independent of the moving interface index for diagnostic flux reconstruction.

It must be checked against:

- stationary B1.11 results;
- kinematic-wave output semantics;
- rapid drainage;
- moving domain bottom;
- PEARL/ANIMO expectations.

## Next step

Create R1-MSTATE02 comparing:

1. exact historical standard-route reconstruction with corrected `icgwl`;
2. universal conservation reconstruction;
3. kinematic-wave compartment fluxes where a comparable case can be constructed.

Do not change production physics at this stage.
