#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-endpoint01-historical-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ENDPOINT01_HIST_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
bindir=Path("$BUILD/modflow-bin")
downloads=Path("$BUILD/downloads")
run_main(bindir,owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=downloads,force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
MODULE_SRC=(
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
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
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link F-GC44 shared library"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_swap_initialize_c' || fail "missing SWAP C ABI"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc34_publish_c' || fail "missing F-GC34 publisher C ABI"

export PYTHONPATH="$ROOT/src/adapter:$ROOT/tests/fgc/support:$ROOT/tests/fgc"
cat > "$BUILD/bridge/historical.py" <<'PY'
from __future__ import annotations
import math, os, sys
from pathlib import Path

ROOT=Path(os.environ["ENDPOINT01_REPO_ROOT"]).resolve()
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"))

os.environ["FGC44_CLOSEOUT_ONECELL"]="1"
os.environ["FGC44_CLOSEOUT_COMPATIBLE_SOLVER"]="1"

import test_fgc44_real_swap_modflow_end_to_end as base
from fgc44_real_swap_ctypes import Fgc44RealSwap

base.CLOSEOUT_ONECELL=True
base.CLOSEOUT_COMPATIBLE_SOLVER=True

libmf6=Path(os.environ["LIBMF6"]).resolve()
swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
swap=Fgc44RealSwap(swaplib)
hcof,rhs,href=swap.initialize()
origin_state=swap.state()
if origin_state!=(0,0.0,0,0.0):
    raise RuntimeError(f"unexpected historical origin {origin_state}")

old_root,old_res,slope,intercept,fit_error=base.closeout_independent_endpoint(
    libmf6,swaplib,swap,href,origin_state
)
print(f"ENDPOINT01_HIST_OLD_ROOT_H={old_root:.17e}")
print(f"ENDPOINT01_HIST_OLD_ROOT_RES={old_res:.17e}")
print(f"ENDPOINT01_HIST_OLD_FIT_ERROR={fit_error:.17e}")

def swap_q(head):
    q=float(swap.trial(head))
    swap.discard()
    if swap.state()!=origin_state:
        raise RuntimeError("historical SWAP probe changed authority")
    return q

def gw(q):
    h,qgw,it=base.solve_closeout_constant_flux(libmf6,swaplib,href,q)
    return float(h),float(qgw),int(it)

def residual(q):
    h,qgw,it=gw(q)
    qs=swap_q(h)
    return qs-qgw,h,qs,it

qcenter=swap_q(href)
half=max(2e-8,0.25*abs(qcenter))
lo=qcenter-half; hi=qcenter+half
rlo,hlo,_,_=residual(lo)
rhi,hhi,_,_=residual(hi)
exp=0
while not (rlo==0.0 or rhi==0.0 or rlo*rhi<0.0) and exp<6:
    half*=2.0
    lo=qcenter-half; hi=qcenter+half
    rlo,hlo,_,_=residual(lo)
    rhi,hhi,_,_=residual(hi)
    exp+=1
if not (rlo==0.0 or rhi==0.0 or rlo*rhi<0.0):
    raise RuntimeError("historical direct root not bracketed")

if rlo==0.0:
    qroot=lo; rroot=rlo; hroot=hlo
elif rhi==0.0:
    qroot=hi; rroot=rhi; hroot=hhi
else:
    qroot=0.5*(lo+hi); rroot=math.inf; hroot=math.nan
    for n in range(80):
        qroot=0.5*(lo+hi)
        rroot,hroot,_,_=residual(qroot)
        if abs(rroot)<=base.FLUX_TOL:
            break
        if rlo*rroot<=0.0:
            hi=qroot; rhi=rroot
        else:
            lo=qroot; rlo=rroot

if abs(rroot)>base.FLUX_TOL:
    raise RuntimeError(f"historical direct residual failed {rroot}")

head_diff=hroot-old_root
print(f"ENDPOINT01_HIST_DIRECT_ROOT_Q={qroot:.17e}")
print(f"ENDPOINT01_HIST_DIRECT_ROOT_H={hroot:.17e}")
print(f"ENDPOINT01_HIST_DIRECT_ROOT_RES={rroot:.17e}")
print(f"ENDPOINT01_HIST_DIRECT_VS_OLD_HEAD_DIFF={head_diff:.17e}")

if abs(head_diff)>base.CLOSEOUT_ENDPOINT_HEAD_TOL_M:
    raise RuntimeError("historical direct oracle disagrees with old endpoint")
if abs(old_res)>base.FLUX_TOL:
    raise RuntimeError("historical old endpoint no longer closes")
print("FPE_ENDPOINT01_HISTORICAL_PRESERVATION=PASS")
PY

ENDPOINT01_REPO_ROOT="$ROOT" FGC44_CLOSEOUT_ONECELL=1 FGC44_CLOSEOUT_COMPATIBLE_SOLVER=1 \
LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
python3 "$BUILD/bridge/historical.py" | tee "$BUILD/historical.txt"

grep -Fq 'FPE_ENDPOINT01_HISTORICAL_PRESERVATION=PASS' "$BUILD/historical.txt" || fail "historical preservation marker"
echo 'FPE_ENDPOINT01_P3=PASS'
