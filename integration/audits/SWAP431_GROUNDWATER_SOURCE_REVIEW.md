# Groundwater source census reconciliation

Status: source review and bounded executable comparison, not admission.
Canonical baseline: `78acf56f931763d2e1d4924b3dea0742f231d2e8`.

## Three different responsibilities

`SWAP/calcgwl.f90` derives a soil-profile water-table diagnostic from pressure
heads. This is not external aquifer storage or MODFLOW head ownership. Its
outputs are consumed by lower-boundary, drainage and macropore physics, so its
active branches cannot be dismissed as output formatting.

The existing `SW431-GW` admission establishes fixed-interface external exchange.
Its meaning is narrowed accordingly; that admission is neither withdrawn nor
used to cover every internal diagnostic branch. The admitted PERCH21 route
separately reconstructs perched zones using `derive_matrix_perched_zone_view`,
including the critical unsaturated volume and upper/lower water-level geometry.
The ordinary saturated-zone view reads the supplied `matrix%groundwater_level`;
it does not independently reconstruct that value from heads.

## Active and inactive source branches

CALCGWL searches upward from a saturated bottom node, interpolates a zero-head
crossing, handles a completely saturated profile using ponding/head, and uses
999 as its no-interior-water-table sentinel. It derives a perched zone bottom
using `gwlevel(3,...)` and its upper surface using `gwlevel(1,...)`, with a
critical-air-volume test when macropores are enabled. Warning formatting and
the saved warning suppression switch are executable diagnostics, not extra
water storage.

`swoptlev` is an internal function argument, not a user selector. Every live
`gwlevel` call passes 1 or 3. The old option 2, averaging elevations at h=-1 and
h=+1, has no active call site in this exact member; the replacements are
explicitly documented in source comments. `SW431-GW-INACTIVE-AVERAGE` therefore
has disposition NOT_APPLICABLE, classification OBSOLETE_CONTROL_FLOW. No new
physics implementation or rejection decision is needed for unreachable code.

## Existing service and missing production binding

`mod_b110_smooth_freatic_projection` intentionally supports only nonmacropore,
bottom-mode-2 strict interior crossings. Its explicit statuses exclude fully
saturated profiles, bottom/other zero-pressure nodes and below-profile water
tables. Those exclusions protect the directional derivative contract; they
are not a bug to repair by silently widening that service.

The Reference state binding initializes `gwl` from the input accepted state.
HeadCalc does not call CALCGWL after solving; the old call is commented out.
`mod_reference_richards_legacy_binding` copies the resulting binding value to
the candidate. The runtime updates the candidate from the smooth projection
only in its opted-in drainage projection route. The macropore saturated view
and inner provider otherwise consume the accepted GWL carrier. A general
candidate profile-to-GWL resolver covering the remaining source branches is
therefore a separate missing binding, `SW431-GW-PROJECTION`, owned by MC-LOW01.

This does not reopen already bounded LOW4, drainage, PERCH21 or external-GW
admissions. It identifies the additional source envelope required for complete
legacy functional coverage. An externally owned head must never be overwritten
by a diagnostic profile level merely because both use the word groundwater.

## Executable evidence

`tools/audits/probe_swap431_groundwater_projection.py` compiles the **unchanged
complete** bundled CALCGWL member with minimal data/error-formatting stubs and
the actual current smooth projection module. It runs six profiles at O0/O2.
Both builds produce identical output:

| Profile | Literal GWL, cm | Smooth service |
| --- | ---: | --- |
| Strict interior crossing | -20 | Value defined, -20 |
| All nodes saturated, no pond | -4 | Fully saturated excluded |
| All nodes saturated, pond=2 | 2 | Fully saturated excluded |
| Bottom unsaturated | 999 | No interior water table |
| Bottom head exactly zero | -35 | Nonsmooth excluded |
| All heads exactly zero | 0 | Nonsmooth excluded |

The evidence is `evidence/SWAP431_GROUNDWATER_PROJECTION_PROBE.json`. It proves
these source values and bounded-service exclusions, not a full runtime trajectory
or a defect in the existing service.

## MC-LOW01 additional slice

Implement a value-only, recomputable profile-level view distinct from the
optional smooth derivative. Represent absent/interior/fully saturated levels
explicitly; confine translation of the legacy 999 sentinel to compatibility
boundaries. Use current immutable geometry, heads and pond state. Preserve
the source perched-zone responsibility already owned by PERCH21.

Before production binding, freeze the owner distinction: committed/start GWL
for pre-solve q(gwl), candidate-derived value after the solve, and external
aquifer head as separate forcing authority. No second water balance or aquifer
store is introduced. Rejected candidates must not update the next attempt's
GWL; accepted continuation and fresh-process restart must reproduce it.

Gates: literal branch values on nonuniform grids, saturation and zero-crossing
transitions, no-interior representation, candidate-only update, failed-trial
identity, accepted next-step sampling and restart; preserve admitted ordinary
lower boundaries, drainage projection, PERCH21 and external groundwater ownership.
The explicit legacy mode-3 resistance law consumes this prerequisite. Its
separate saturated-profile resistance physics is not closed by this resolver.
