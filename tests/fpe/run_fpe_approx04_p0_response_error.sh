#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx04-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX04_P0_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -O2)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
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
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
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
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_approx01_tangent_matrix.f90 -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

CSV="$BUILD/results.csv"
echo 'material,regime,offset_cm,tangent,bottom_flux' > "$CSV"
offsets=(-0.5 -0.25 -0.1 -0.05 0 0.05 0.1 0.25 0.5)
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")

for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for offset in "${offsets[@]}"; do
    hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
    raw="$("$BUILD/test" "$material" "$h0" "$hbot")"
    line="$(printf '%s\n' "$raw" | grep '^APPROX01_MATRIX_POINT|')"
    python3 - "$material" "$regime" "$offset" "$line" "$CSV" <<'PY'
import csv,sys
material,regime,offset,line,path=sys.argv[1:]
d={}
for p in line.strip().split('|')[1:]:
    k,v=p.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([material,regime,offset,d['TANGENT'],d['BOTTOM_FLUX']])
print(f"APPROX04_P0_POINT|MATERIAL={material}|REGIME={regime}|OFFSET_CM={offset}|TANGENT={d['TANGENT']}|BOTTOM_FLUX={d['BOTTOM_FLUX']}")
PY
  done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
if len(rows)!=54: raise SystemExit(f"expected 54 points, got {len(rows)}")
global_abs=0.0
global_exc=0.0
global_tdrift=0.0
for material,regime in [
    ("B01","wet"),("B01","mid"),("B12","wet"),
    ("O05","wet"),("O14","wet"),("O14","mid")
]:
    rr=[r for r in rows if r["material"]==material and r["regime"]==regime]
    rr=sorted(rr,key=lambda r:float(r["offset_cm"]))
    origin=next(r for r in rr if abs(float(r["offset_cm"]))<1e-15)
    q0=float(origin["bottom_flux"]); t0=float(origin["tangent"])
    abs_err=[]; exc_rel=[]; q_rel=[]; tdrift=[]; signs_ok=True
    for r in rr:
        dh=float(r["offset_cm"])
        q=float(r["bottom_flux"]); t=float(r["tangent"])
        qpred=q0+t0*dh
        err=abs(qpred-q)
        excursion=abs(q-q0)
        abs_err.append(err)
        if excursion>1e-14:
            exc_rel.append(err/excursion)
        if abs(q)>1e-12:
            q_rel.append(err/abs(q))
        tdrift.append(abs(t-t0)/max(abs(t0),1e-30))
        # local response orientation must remain compatible with origin derivative.
        if t0!=0 and t*t0<0: signs_ok=False
        print(
          f"APPROX04_P0_ERROR|MATERIAL={material}|REGIME={regime}|OFFSET_CM={dh:.6f}"
          f"|Q_EXACT={q:.17e}|Q_PRED={qpred:.17e}|ABS_ERROR={err:.17e}"
          f"|REL_Q={(err/max(abs(q),1e-30)):.17e}|REL_EXCURSION={(err/max(excursion,1e-30)):.17e}"
          f"|TANGENT_REL_DRIFT={(abs(t-t0)/max(abs(t0),1e-30)):.17e}"
        )
    ma=max(abs_err); me=max(exc_rel) if exc_rel else 0.0; mq=max(q_rel) if q_rel else 0.0; mt=max(tdrift)
    global_abs=max(global_abs,ma); global_exc=max(global_exc,me); global_tdrift=max(global_tdrift,mt)
    print(
      f"APPROX04_P0_CASE|MATERIAL={material}|REGIME={regime}|MAX_ABS_ERROR={ma:.17e}"
      f"|MAX_REL_Q={mq:.17e}|MAX_REL_EXCURSION={me:.17e}|MAX_TANGENT_REL_DRIFT={mt:.17e}"
      f"|ORIENTATION_OK={str(signs_ok).upper()}"
    )
print(
  f"APPROX04_P0_SUMMARY|CASES=6|MAX_ABS_ERROR={global_abs:.17e}"
  f"|MAX_REL_EXCURSION={global_exc:.17e}|MAX_TANGENT_REL_DRIFT={global_tdrift:.17e}"
)
print("FPE_APPROX04_P0=PASS")
PY
