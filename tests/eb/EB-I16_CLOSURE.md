# EB-I16 Closure Disposition

EB-I16 is a design-freeze workunit only. It starts from the exact qualified EB-I15 head `0181b7b674cc89d729e361dafc1135b719e23a7d` and changes no production source.

The principal architectural finding is that SWAP5 already has the necessary water-side authorities. `mod_groundwater_coupling_contract` owns interface sign/window semantics, `mod_groundwater_exchange_service_contract` owns groundwater checkpoint/candidate/prepared lifecycle, and `mod_groundwater_interface_mass_ledger` owns committed interface mass. EB-I16 must therefore not introduce another groundwater exchange or another mass ledger.

The frozen new boundary is a thermal-only runtime/coupler sidecar. For EB-I13 inward samples it supplies an explicit finite external donor-water temperature for the exact candidate lifecycle. It owns no water amount. Local outward and exact-zero samples bypass it. Under the currently qualified EB-I14 temporal convention the external donor temperature is the current-reference value at sample `t1`, not a silently substituted interval mean.

Thermal provenance may not be detached and later authorized from only visible lineage/window/revision scalars. Same-origin candidates can represent distinct materializations. A future implementation must therefore bind thermal provenance inside the exact candidate/prepared lifecycle, or use an equivalently strong opaque one-shot handle. Missing, stale, replayed or invalid provenance makes energy incomplete and never substitutes zero or local SWAP temperature.

This workunit does not authorize energy commit/publication and does not alter hydrologic or groundwater mass acceptance. It introduces no groundwater-temperature model, deep-vadose temperature model or MODFLOW heat transport.

Closure is justified only when `.github/workflows/eb-i16-contract.yml` succeeds on the exact final branch HEAD and confirms: all 30 architecture invariants reconciled, existing groundwater/EB authorities byte-unchanged, executable adversarial binding semantics passing, no production delta and clean diff.

Until that exact-head run is green, disposition remains `DESIGN_FROZEN_PENDING_EXACT_HEAD_QUALIFICATION`. After that run the status may be advanced to `QUALIFIED_DESIGN_FREEZE_CLOSED_PENDING_IMPLEMENTATION`, followed by one final exact-head rerun.
