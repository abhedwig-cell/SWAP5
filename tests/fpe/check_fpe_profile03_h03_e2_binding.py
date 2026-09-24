#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
task2 = (root / "src/adapter/mod_b110_production_soil_water_task2.f90").read_text()
binding = (root / "src/adapter/mod_reference_richards_legacy_binding.f90").read_text()
headcalc = (root / "src/legacy/b1_10_port/headcalc.f90").read_text()
soilwater = (root / "src/legacy/b1_10_port/soilwater.f90").read_text()

checks = {
    "soilwater_dispatches_typed_task2":
        "use mod_b110_production_soil_water_task2, only: run_b110_production_task2" in soilwater
        and "call run_b110_production_task2" in soilwater,
    "hupsel_profile_enters_explicit_production_route":
        "m1_b111_legacy_application_profile_active" in task2
        and "type(reference_richards_legacy_solver_t) :: solver" in task2
        and "call invoke_soil_water_solver(solver, request, workspace, result)" in task2,
    "reference_solver_calls_headcalc":
        "subroutine reference_richards_legacy_solve" in binding
        and "call headcalc" in binding,
    "h03_tuple_validity_present":
        "provider_tuple_valid" in headcalc,
    "h03_iteration_reuse_present":
        "provider_tuple_valid = .true." in headcalc
        and "if (.not. provider_tuple_valid)" in headcalc
        and "provider_tuple_valid = .false." in headcalc,
}

for name, ok in checks.items():
    print(f"PROFILE03_E2_BIND_{name.upper()}={'PASS' if ok else 'FAIL'}")
if not all(checks.values()):
    raise SystemExit(1)

print("PROFILE03_E2_HUPSEL_TO_H03_ROUTE_BINDING=PASS")
