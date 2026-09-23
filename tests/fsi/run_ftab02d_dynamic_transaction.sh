#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02d-dynamic-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod" "$BUILD/obj"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_TAB02_D_DYNAMIC_GATE_FAIL $*" >&2; exit 1; }

python3 tests/fsi/make_ftab02d_generated_fmr44r.py   tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90   "$BUILD/test_generated.f90"
cp tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90 "$BUILD/test_analytic.f90"

python3 - <<'PY'
from pathlib import Path
a=Path("tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90").read_text()
g=Path(__import__("os").environ.get("BUILD_PATH","/dev/null"))
# Static source authority checks stay in the shell-visible source files.
assert "TX_TEMPORAL_MODEL_CERTIFICATE" in a
assert "FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY" in a
assert "qualification_head_budget = 2.5e-11_real64" in a
print("F_TAB02_D_FMR44R_POLICY_AUTHORITY_STATIC=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -O2 -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_generated_mvg_tspack.f90
  src/solver/mod_b110_generated_mvg_table_state.f90
  src/solver/mod_b110_generated_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

objs=()
for source in "${MODULES[@]}"; do
  obj="$BUILD/obj/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$source" -o "$obj"
  objs+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$BUILD/test_analytic.f90" -o "$BUILD/analytic-test.o"
gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$BUILD/test_generated.f90" -o "$BUILD/generated-test.o"
gfortran -O2 -fopenmp "${objs[@]}" "$BUILD/analytic-test.o" -o "$BUILD/analytic"
gfortran -O2 -fopenmp "${objs[@]}" "$BUILD/generated-test.o" -o "$BUILD/generated"

"$BUILD/analytic" > "$BUILD/analytic.txt" 2>&1 || { cat "$BUILD/analytic.txt" >&2; fail "analytical FMR44R runtime"; }
"$BUILD/generated" > "$BUILD/generated.txt" 2>&1 || { cat "$BUILD/generated.txt" >&2; fail "generated FMR44R runtime"; }

for route in analytic generated; do
  for marker in     'FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS'     'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS'     'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS'     'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'; do
    grep -Fq "$marker" "$BUILD/$route.txt" || { cat "$BUILD/$route.txt" >&2; fail "$route missing $marker"; }
  done
done

python3 - "$BUILD/analytic.txt" "$BUILD/generated.txt" "$BUILD/comparison.tsv" <<'PY'
from pathlib import Path
import math,re,sys
ap,gp,out=map(Path,sys.argv[1:])
def parse(path):
    txt=path.read_text()
    m=re.search(r'FMR44R_POSITIVE_QBOT_MASS residual=\s*([+\-0-9.Ee]+) total_in=\s*([+\-0-9.Ee]+) total_out=\s*([+\-0-9.Ee]+)',txt)
    c=re.search(r'FMR44R_POSITIVE_QBOT_CERTIFICATE Binf=\s*([+\-0-9.Ee]+) Ch=\s*([+\-0-9.Ee]+)',txt)
    b=re.search(r'FMR44R_QUALIFICATION_HEAD_BUDGET_CM=\s*([+\-0-9.Ee]+)',txt)
    if not (m and c and b):
        raise SystemExit(f"F-TAB02-D parse failure: {path}")
    return dict(res=float(m.group(1)),tin=float(m.group(2)),tout=float(m.group(3)),
                binf=float(c.group(1)),ch=float(c.group(2)),budget=float(b.group(1)))
a=parse(ap); g=parse(gp)
if not all(math.isfinite(x) for d in (a,g) for x in d.values()):
    raise SystemExit("F-TAB02-D nonfinite certificate/mass value")
if abs(a["res"])>1e-12 or abs(g["res"])>1e-12:
    raise SystemExit("F-TAB02-D hard mass gate")
if not (0.0<a["binf"]<=a["budget"] and 0.0<g["binf"]<=g["budget"]):
    raise SystemExit("F-TAB02-D certificate head budget")
if not (0.0<a["ch"]<1.0 and 0.0<g["ch"]<1.0):
    raise SystemExit("F-TAB02-D normalized certificate")
if abs(a["tin"]-g["tin"])>1e-18 or abs(a["tout"]-g["tout"])>1e-18:
    raise SystemExit("F-TAB02-D boundary mass totals differ")
# Implementation-consistency guards are deliberately much wider than the
# qualified research differences, but much tighter than the admitted head
# budget / normalized certificate envelope.
if abs(a["binf"]-g["binf"]) > 5.0e-13:
    raise SystemExit("F-TAB02-D generated Binf diverges from reference")
if abs(a["ch"]-g["ch"]) > 1.0e-3:
    raise SystemExit("F-TAB02-D generated normalized certificate diverges from reference")
lines=[
 "metric\tanalytic\tgenerated\tabs_difference",
 f"mass_residual\t{a['res']:.17e}\t{g['res']:.17e}\t{abs(g['res']-a['res']):.17e}",
 f"Binf_cm\t{a['binf']:.17e}\t{g['binf']:.17e}\t{abs(g['binf']-a['binf']):.17e}",
 f"normalized_Ch\t{a['ch']:.17e}\t{g['ch']:.17e}\t{abs(g['ch']-a['ch']):.17e}",
 f"total_in\t{a['tin']:.17e}\t{g['tin']:.17e}\t{abs(g['tin']-a['tin']):.17e}",
 f"total_out\t{a['tout']:.17e}\t{g['tout']:.17e}\t{abs(g['tout']-a['tout']):.17e}",
]
out.write_text("\n".join(lines)+"\n")
print(out.read_text(),end="")
print("F_TAB02_D_DYNAMIC_HARD_MASS=PASS")
print("F_TAB02_D_DYNAMIC_CERTIFICATE_AVAILABLE=PASS")
print("F_TAB02_D_DYNAMIC_REFERENCE_CONSISTENCY=PASS")
print("F_TAB02_D_DYNAMIC_BOUNDARY_MASS_IDENTITY=PASS")
PY

cat "$BUILD/analytic.txt" | grep -E '^(FMR44R_POSITIVE_QBOT_MASS|FMR44R_POSITIVE_QBOT_CERTIFICATE|FMR44R_.*PASS)' || true
cat "$BUILD/generated.txt" | grep -E '^(FMR44R_POSITIVE_QBOT_MASS|FMR44R_POSITIVE_QBOT_CERTIFICATE|F_TAB02_D_GENERATED_BINF|FMR44R_.*PASS)' || true
cat "$BUILD/comparison.tsv"

git diff --check --   src/solver/mod_soil_water_solver_contract.f90   src/solver/mod_b110_default_mvg_provider.f90   src/solver/mod_b110_generated_mvg_provider.f90   src/solver/mod_reference_richards_temporal_indicator.f90   src/runtime/mod_fmr_serialized_reference_backend.f90   tests/fsi/make_ftab02d_generated_fmr44r.py   tests/fsi/run_ftab02d_dynamic_transaction.sh

echo "F-TAB02-D DYNAMIC TRANSACTION CERTIFICATE GATE PASS"
