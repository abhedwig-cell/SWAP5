#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-heap-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

cat > "$BUILD/heap_wrap.c" <<'C'
#include <stddef.h>
#include <stdio.h>
#include <stdint.h>

void *__real_malloc(size_t);
void *__real_calloc(size_t,size_t);
void *__real_realloc(void*,size_t);
void __real_free(void*);

static unsigned long long n_malloc=0, n_calloc=0, n_realloc=0, n_free=0;
static unsigned long long b_malloc=0, b_calloc=0, b_realloc=0;

#define NSITE 2048
struct site_rec { uintptr_t addr; unsigned long long count; unsigned long long bytes; };
static struct site_rec sites[NSITE];

static void record_site(uintptr_t addr, size_t bytes) {
  unsigned long long idx=((unsigned long long)(addr>>4)) & (NSITE-1);
  unsigned long long start=idx;
  while (sites[idx].addr && sites[idx].addr!=addr) {
    idx=(idx+1)&(NSITE-1);
    if (idx==start) return;
  }
  if (!sites[idx].addr) sites[idx].addr=addr;
  sites[idx].count++;
  sites[idx].bytes+=(unsigned long long)bytes;
}

void *__wrap_malloc(size_t n) {
  n_malloc++; b_malloc += (unsigned long long)n;
  record_site((uintptr_t)__builtin_return_address(0),n);
  return __real_malloc(n);
}
void *__wrap_calloc(size_t n, size_t s) {
  size_t b=n*s;
  n_calloc++; b_calloc += (unsigned long long)b;
  record_site((uintptr_t)__builtin_return_address(0),b);
  return __real_calloc(n,s);
}
void *__wrap_realloc(void *p, size_t n) {
  n_realloc++; b_realloc += (unsigned long long)n;
  record_site((uintptr_t)__builtin_return_address(0),n);
  return __real_realloc(p,n);
}
void __wrap_free(void *p) {
  n_free++;
  __real_free(p);
}
void dir01_heap_reset(void) {
  int i;
  n_malloc=n_calloc=n_realloc=n_free=0;
  b_malloc=b_calloc=b_realloc=0;
  for (i=0;i<NSITE;i++) { sites[i].addr=0; sites[i].count=0; sites[i].bytes=0; }
}
void dir01_heap_report(void) {
  int i;
  printf("DIR01_HEAP|MALLOC=%llu|CALLOC=%llu|REALLOC=%llu|FREE=%llu|MALLOC_BYTES=%llu|CALLOC_BYTES=%llu|REALLOC_BYTES=%llu\n",
    n_malloc,n_calloc,n_realloc,n_free,b_malloc,b_calloc,b_realloc);
  for (i=0;i<NSITE;i++) if (sites[i].addr)
    printf("DIR01_HEAP_SITE|ADDR=0x%llx|COUNT=%llu|BYTES=%llu\n",
      (unsigned long long)sites[i].addr,sites[i].count,sites[i].bytes);
}
C

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_profile03_h03_application_host_timing.f90").read_text()
src=src.replace("SW_STEP_CONTROL_BOTTOM_FLUX", "SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace("forcing%bottom_head = -999999.0_real64", "forcing%bottom_head = h0")
src=src.replace(
"  implicit none\n",
"""  implicit none

  interface
    subroutine dir01_heap_reset() bind(C,name='dir01_heap_reset')
    end subroutine dir01_heap_reset
    subroutine dir01_heap_report() bind(C,name='dir01_heap_report')
    end subroutine dir01_heap_report
  end interface
""",1)
src=src.replace(
"  checksum = 0.0_real64\n  call system_clock(clock_start, clock_rate)",
"  call dir01_heap_reset()\n  checksum = 0.0_real64\n  call system_clock(clock_start, clock_rate)",1)
src=src.replace(
"  call system_clock(clock_end)\n  elapsed_seconds = real(clock_end-clock_start,real64)/real(clock_rate,real64)",
"  call system_clock(clock_end)\n  call dir01_heap_report()\n  elapsed_seconds = real(clock_end-clock_start,real64)/real(clock_rate,real64)",1)
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -fno-pie)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
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
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gcc -O2 -fno-pie -c "$BUILD/heap_wrap.c" -o "$BUILD/heap_wrap.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 -no-pie "${objects[@]}" "$BUILD/test.o" "$BUILD/heap_wrap.o" \
  -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=free -o "$BUILD/test"

CALLS=200000
for mode in reference directional; do
  "$BUILD/test" "$CALLS" "$mode" zero-waste-paired > "$BUILD/$mode.out"
  grep '^DIR01_HEAP|' "$BUILD/$mode.out" | sed "s/^/DIR01_${mode^^}_/"
  grep '^PROFILE03_E1_TIMING' "$BUILD/$mode.out"
done

python3 - "$BUILD/reference.out" "$BUILD/directional.out" "$CALLS" "$BUILD/test" <<'PY'
import re,sys,subprocess
calls=int(sys.argv[3]); exe=sys.argv[4]

def read(path):
    txt=open(path).read()
    m=re.search(r'^DIR01_HEAP\|(.+)$',txt,re.M)
    if not m: raise SystemExit(f'missing heap record {path}')
    totals={}
    for p in m.group(1).split('|'):
        k,v=p.split('=',1); totals[k]=int(v)
    sites={}
    for sm in re.finditer(r'^DIR01_HEAP_SITE\|ADDR=(0x[0-9a-fA-F]+)\|COUNT=(\d+)\|BYTES=(\d+)$',txt,re.M):
        sites[sm.group(1)]=(int(sm.group(2)),int(sm.group(3)))
    return totals,sites

r,rs=read(sys.argv[1]); d,ds=read(sys.argv[2])
print("DIR01_HEAP_DELTA")
for k in ('MALLOC','CALLOC','REALLOC','FREE','MALLOC_BYTES','CALLOC_BYTES','REALLOC_BYTES'):
    delta=d[k]-r[k]
    print(f"DIR01_HEAP_DELTA|FIELD={k}|TOTAL={delta}|PER_INTERVAL={delta/calls:.6f}")

rows=[]
for a in set(rs)|set(ds):
    rc,rb=rs.get(a,(0,0)); dc,db=ds.get(a,(0,0))
    count_delta=dc-rc; byte_delta=db-rb
    if count_delta<=0 and byte_delta<=0:
        continue
    resolved=subprocess.check_output(['addr2line','-f','-C','-e',exe,a],text=True).strip().splitlines()
    fn=resolved[0] if resolved else '?'
    loc=resolved[1] if len(resolved)>1 else '?'
    rows.append((count_delta,byte_delta,a,fn,loc,dc,rc))
rows.sort(reverse=True)
print("DIR01_HEAP_SITE_DELTA_TOP")
for count_delta,byte_delta,a,fn,loc,dc,rc in rows[:40]:
    print(f"DIR01_HEAP_SITE_DELTA|COUNT_DELTA={count_delta}|BYTES_DELTA={byte_delta}|PER_INTERVAL={count_delta/calls:.6f}|ADDR={a}|FUNCTION={fn}|LOCATION={loc}|DIR_COUNT={dc}|REF_COUNT={rc}")
print('FPE_DIR01_HEAP_ATTRIBUTION=PASS')
PY
