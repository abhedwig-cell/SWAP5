#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-repair03-heap-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT

BASE=807c19f543acc1eb24de8ac17015ba76497a5ee5
git fetch --no-tags --depth=1 origin "$BASE"
git show "$BASE:src/transaction/mod_accepted_trajectory_directional_sensitivity.f90" > "$BUILD/src/direction_base.f90"
git show "$BASE:src/runtime/mod_fmr_serialized_reference_backend.f90" > "$BUILD/src/backend_base.f90"

cat > "$BUILD/heap_wrap.c" <<'C'
#include <stddef.h>
#include <stdio.h>
void *__real_malloc(size_t);
void *__real_calloc(size_t,size_t);
void *__real_realloc(void*,size_t);
void __real_free(void*);
static unsigned long long nm=0,nc=0,nr=0,nf=0,bm=0,bc=0,br=0;
void *__wrap_malloc(size_t n){nm++;bm+=n;return __real_malloc(n);}
void *__wrap_calloc(size_t n,size_t s){nc++;bc+=(unsigned long long)n*s;return __real_calloc(n,s);}
void *__wrap_realloc(void*p,size_t n){nr++;br+=n;return __real_realloc(p,n);}
void __wrap_free(void*p){nf++;__real_free(p);}
void dir01_heap_reset(void){nm=nc=nr=nf=bm=bc=br=0;}
void dir01_heap_report(void){
 printf("DIR01_R3_HEAP|MALLOC=%llu|CALLOC=%llu|REALLOC=%llu|FREE=%llu|MALLOC_BYTES=%llu|CALLOC_BYTES=%llu|REALLOC_BYTES=%llu\n",nm,nc,nr,nf,bm,bc,br);
}
C

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_profile03_h03_application_host_timing.f90").read_text()
src=src.replace("SW_STEP_CONTROL_BOTTOM_FLUX","SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace("forcing%bottom_head = -999999.0_real64","forcing%bottom_head = h0")
src=src.replace("  implicit none\n","""  implicit none
  interface
    subroutine dir01_heap_reset() bind(C,name='dir01_heap_reset')
    end subroutine
    subroutine dir01_heap_report() bind(C,name='dir01_heap_report')
    end subroutine
  end interface
""",1)
src=src.replace("  checksum = 0.0_real64\n  call system_clock(clock_start, clock_rate)",
                "  call dir01_heap_reset()\n  checksum = 0.0_real64\n  call system_clock(clock_start, clock_rate)",1)
src=src.replace("  call system_clock(clock_end)\n  elapsed_seconds = real(clock_end-clock_start,real64)/real(clock_rate,real64)",
                "  call system_clock(clock_end)\n  call dir01_heap_report()\n  elapsed_seconds = real(clock_end-clock_start,real64)/real(clock_rate,real64)",1)
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  DIRECTION_PLACEHOLDER
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
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
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  BACKEND_PLACEHOLDER
)

compile_variant(){
  local name="$1"
  local out="$BUILD/$name"
  local objects=()
  for source in "${SRC[@]}"; do
    if [[ "$source" == DIRECTION_PLACEHOLDER ]]; then
      [[ "$name" == base ]] && source="$BUILD/src/direction_base.f90" || source="src/transaction/mod_accepted_trajectory_directional_sensitivity.f90"
    elif [[ "$source" == BACKEND_PLACEHOLDER ]]; then
      [[ "$name" == base ]] && source="$BUILD/src/backend_base.f90" || source="src/runtime/mod_fmr_serialized_reference_backend.f90"
    fi
    local obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gcc -O2 -c "$BUILD/heap_wrap.c" -o "$out/heap_wrap.o"
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$BUILD/test.f90" -o "$out/test.o"
  gfortran -O2 "${objects[@]}" "$out/test.o" "$out/heap_wrap.o" -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=free -o "$out/test"
}
compile_variant base
compile_variant candidate

CALLS=100000
for variant in base candidate; do
  "$BUILD/$variant/test" "$CALLS" directional zero-waste-paired > "$BUILD/$variant.out"
  grep '^DIR01_R3_HEAP|' "$BUILD/$variant.out" | sed "s/^/DIR01_R3_${variant^^}_/"
  grep '^PROFILE03_E1_TIMING' "$BUILD/$variant.out"
done

python3 - "$BUILD/base.out" "$BUILD/candidate.out" "$CALLS" <<'PY'
import re,sys
calls=int(sys.argv[3])
def read(path):
    txt=open(path).read()
    m=re.search(r'^DIR01_R3_HEAP\|(.+)$',txt,re.M)
    if not m: raise SystemExit(f'missing heap record {path}')
    d={}
    for p in m.group(1).split('|'):
        k,v=p.split('=',1); d[k]=int(v)
    return d
b=read(sys.argv[1]); c=read(sys.argv[2])
for k in ('MALLOC','CALLOC','REALLOC','FREE','MALLOC_BYTES','CALLOC_BYTES','REALLOC_BYTES'):
    delta=c[k]-b[k]
    print(f'DIR01_REPAIR03_HEAP_DELTA|FIELD={k}|TOTAL={delta}|PER_INTERVAL={delta/calls:.6f}')
if c['MALLOC'] >= b['MALLOC']:
    raise SystemExit('REPAIR03 did not reduce malloc count')
print('FPE_DIR01_REPAIR03_HEAP=PASS')
PY
