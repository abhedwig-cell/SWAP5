from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

context = (ROOT / "src/runtime/mod_fmr_groundwater_application_context.f90").read_text()
capi = (ROOT / "src/adapter/mod_fmr_groundwater_application_c_api.f90").read_text()
runtime = (ROOT / "src/adapter/fmr_groundwater_application_runtime.py").read_text()
linear = (ROOT / "src/runtime/mod_modflow6_linear_response_backend.f90").read_text()
service = (ROOT / "src/adapter/modflow6_groundwater_application_service.py").read_text()

lower_context = context.lower()
lower_capi = capi.lower()
lower_runtime = runtime.lower()
lower_linear = linear.lower()
lower_service = service.lower()


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


for forbidden in (
    "fgc47",
    "fgc46",
    "fgc45",
    "fgc44",
    "610049",
    "7001",
    "7002",
    "0.35_real64",
    "0.65_real64",
):
    require(forbidden not in lower_context, f"context topology fixture leakage: {forbidden}")
    require(forbidden not in lower_capi, f"C API topology fixture leakage: {forbidden}")
    require(forbidden not in lower_runtime, f"Python topology fixture leakage: {forbidden}")

require("type(groundwater_application_plan_t), pointer" in lower_context, "plan remains referenced")
require("type(fmr_groundwater_participant_registry_t), pointer" in lower_context, "registry remains referenced")
require("type(groundwater_interface_mass_ledger_t), pointer" in lower_context, "ledgers remain referenced")
require("logical :: published = .false." in lower_context, "one-window publication state explicit")
require("if (self%published)" in lower_context and "self%published = .true." in lower_context, "published context reuse fails closed")
require("aggregate_groundwater_cell_tiles" in lower_context, "F-GC40 aggregation authority delegated")
require("evaluate_modflow6_linear_boundary_flux_density" in lower_context, "F-GC33 evaluation delegated")
require("reanchor_modflow6_linear_boundary_term" in lower_context, "F-GC33 reanchor delegated")
require("hcof_m2_per_day * hydraulic_head_m" not in lower_context, "context does not duplicate HCOF evaluation")
require("rhs = term%hcof_m2_per_day" not in lower_context, "context does not duplicate reanchor equation")

require("evaluate_modflow6_linear_boundary_flux_density" in lower_linear, "linear authority has density helper")
require("reanchor_modflow6_linear_boundary_term" in lower_linear, "linear authority has reanchor helper")
require("rhs = term%hcof_m2_per_day * hydraulic_head_m - reference_volume_flux" in lower_linear, "reanchor equation lives in F-GC33 authority")

require("register_fmr_groundwater_application_context" in lower_capi, "opaque registration seam")
require("type(fmr_groundwater_application_context_t), pointer :: context" in lower_capi, "bridge stores references")
require("handle_id" in lower_capi and "next_handle" in lower_capi, "opaque monotonically changing handles")
require("slots(slot)%active = .false." in lower_capi and "nullify(slots(slot)%context)" in lower_capi, "released handles invalidated")
require("if (.not. slots(i)%active) cycle" in lower_capi, "resolver rejects inactive slot")
require("fgc49d_tile_view_c" in lower_capi and "participant_handles" in lower_capi, "participant handles exposed opaquely")
require("xmiwrapper" not in lower_capi and "finalize_time_step" not in lower_capi, "C API does not own MODFLOW")

require("class fmrgroundwaterapplicationruntime" in lower_runtime.replace("_", ""), "production Python runtime exists")
require("participant_handles" in lower_runtime, "Python receives opaque participant handle view")
require("aggregate_groundwater_cell_tiles" not in lower_runtime, "no F-GC40 implementation in Python")
require("86400" not in lower_runtime, "no day conversion duplicated in Python")
require("hcof_m2_per_day *" not in lower_runtime, "no HCOF equation in Python")
require("area_fraction *" not in lower_runtime, "no tile aggregation in Python")
require("tests." not in lower_runtime and "fgc47" not in lower_runtime, "production adapter independent of qualification fixtures")

require("modflow6preparedsolvesession" in lower_service.replace("_", ""), "F-GC49C retains MODFLOW backend")
require("fmr_groundwater_application_runtime" not in lower_service, "generic service not hardwired to FMR adapter")
require("finalize_time_step_once" in lower_service, "F-GC41 publication boundary retained")
run_block = lower_service[lower_service.find("def run_groundwater_application_window") :]
modflow_publish = run_block.find("finalize_time_step_once")
swap_publish = run_block.find("runtime.commit_swaps")
ledger_publish = run_block.find("runtime.commit_ledgers")
require(modflow_publish >= 0 and swap_publish >= 0 and ledger_publish >= 0, "publication calls present")
require(modflow_publish < swap_publish < ledger_publish, "MODFLOW then SWAP then ledger publication")

print("FVQ124_NO_QUALIFICATION_BRIDGE_PROMOTION=PASS")
print("FVQ124_EXTERNAL_FORTRAN_OWNERSHIP_RETAINED=PASS")
print("FVQ124_ONE_WINDOW_CONTEXT_REUSE_FAIL_CLOSED=PASS")
print("FVQ124_FGC40_AGGREGATION_DELEGATED=PASS")
print("FVQ124_FGC33_EVALUATION_REANCHOR_DELEGATED=PASS")
print("FVQ124_OPAQUE_CONTEXT_HANDLE_STALE_FAIL_CLOSED=PASS")
print("FVQ124_PARTICIPANT_HANDLES_EXPOSED_NOT_OWNED=PASS")
print("FVQ124_NO_MODFLOW_OWNERSHIP_IN_FMR_ABI=PASS")
print("FVQ124_GENERIC_FGC49C_SERVICE_REMAINS_UNBOUND=PASS")
print("FVQ124_MODFLOW_SWAP_LEDGER_PUBLICATION_ORDER_RETAINED=PASS")
print("F-VQ124 F-GC49D INDEPENDENT QUALIFICATION PASS")
