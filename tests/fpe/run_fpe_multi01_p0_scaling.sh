#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi01-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
git cat-file blob "$MATRIX_BLOB" > "$BUILD/base.f90"

python3 - "$BUILD/base.f90" "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()

start=src.index("  integer, parameter :: ncases")
end=src.index("\ncontains\n", start)
main="""  integer, parameter :: NSIZES=3, NBATCH=3, NWORK=3
  integer, parameter :: SIZES(NSIZES)=[100,1000,10000]
  integer, parameter :: BATCHES(NBATCH)=[1,64,1024]
  integer, parameter :: WORKERS(NWORK)=[1,2,4]
  integer :: is, ib, iw

  do is=1,NSIZES
    do ib=1,NBATCH
      if(BATCHES(ib)>SIZES(is) .and. BATCHES(ib)/=1024) cycle
      do iw=1,NWORK
        call run_timing_case(SIZES(is),min(BATCHES(ib),SIZES(is)),WORKERS(iw))
      end do
    end do
  end do
  write(*,'(A)') 'FPE_MULTI01_P0=PASS'
"""
src=src[:start]+main+src[end:]

insert_at=src.index("  subroutine run_positive_case")
sub=r"""
  subroutine run_timing_case(n,batch_size,workers)
    integer,intent(in)::n,batch_size,workers
    integer,parameter::NREP=5
    type(fmr_logical_column_t),allocatable::columns(:)
    type(fmr_template_t)::templates(1)
    type(fmr_b110_physical_parameters_t)::parameters(1)
    type(fmr_b110_physical_forcing_t),allocatable::forcings(:)
    type(fmr_b110_physical_state_t)::seed
    type(kernel_committed_state_t),allocatable::states(:)
    type(fmr_serialized_column_result_t),allocatable::results(:)
    type(fmr_column_diagnostics_t),allocatable::diagnostics(:)
    type(fmr_aggregate_diagnostics_t)::aggregate
    type(fmr_serialized_batch_diagnostics_t)::runtime
    type(fixed_flux_top_boundary_provider_t),target::top_provider
    type(canonical_numerical_config_t)::config
    real(real64)::conductivity0,seconds(NREP),tstart,tstop,med
    integer::rep,dispatch_status,pool_status
    integer(int64)::c0,c1,rate
    logical::identity_ok

    call build_fixture(n,columns,templates,parameters,forcings,seed,conductivity0)
    call configure_transaction(config)
    identity_ok=.true.

    do rep=1,NREP
      call initialize_states(states,columns,seed)
      call system_clock(c0,count_rate=rate)
      call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,states,config,top_provider, &
           t0,t1,batch_size,workers,results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
      call system_clock(c1)
      if(pool_status/=FMR_PARALLEL_POOL_OK .or. dispatch_status/=FMR_SERIAL_DISPATCH_OK) &
        error stop 'MULTI01 parallel status'
      if(.not.all_committed(results)) error stop 'MULTI01 commit'
      if(max_abs_residual(results)>hard_mass_gate) error stop 'MULTI01 mass'
      if(runtime%number_requested/=n .or. runtime%number_executed/=n .or. runtime%number_committed/=n) &
        error stop 'MULTI01 runtime counts'
      if(workers>1 .and. runtime%max_simultaneous_real_physical_solves<2) &
        error stop 'MULTI01 no real overlap'
      seconds(rep)=real(c1-c0,real64)/real(rate,real64)
    end do

    call sort5(seconds)
    med=seconds(3)
    write(*,'(*(g0))') 'MULTI01_P0|N=',n,'|BATCH=',batch_size,'|WORKERS=',workers, &
      '|MEDIAN_SECONDS=',med,'|NS_PER_COLUMN=',1.0e9_real64*med/real(n,real64), &
      '|THROUGHPUT=',real(n,real64)/med,'|ATTEMPTS=',aggregate%attempts, &
      '|RETRIES=',aggregate%retries,'|MAX_SIMULTANEOUS=',runtime%max_simultaneous_real_physical_solves, &
      '|BATCHES=',aggregate%batches,'|REQUESTED=',runtime%number_requested, &
      '|EXECUTED=',runtime%number_executed,'|COMMITTED=',runtime%number_committed, &
      '|MASS_COMPLETE=',runtime%authoritative_aggregate_mass%complete
  end subroutine run_timing_case

  subroutine sort5(v)
    real(real64),intent(inout)::v(5)
    real(real64)::tmp
    integer::i,j
    do i=1,4
      do j=i+1,5
        if(v(j)<v(i))then
          tmp=v(i); v(i)=v(j); v(j)=tmp
        end if
      end do
    end do
  end subroutine sort5

"""
src=src[:insert_at]+sub+src[insert_at:]
Path(sys.argv[2]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)
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
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)

objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O3 -fopenmp "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

"$BUILD/test" | tee "$BUILD/out.txt"
grep -Fq 'FPE_MULTI01_P0=PASS' "$BUILD/out.txt"

python3 - "$BUILD/out.txt" <<'PY'
import collections,re,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI01_P0|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if not rows: raise SystemExit("no timing rows")
by={(int(r["N"]),int(r["BATCH"]),int(r["WORKERS"])):r for r in rows}
for n in sorted({int(r["N"]) for r in rows}):
  for b in sorted({int(r["BATCH"]) for r in rows if int(r["N"])==n}):
    base=by[(n,b,1)]
    t1=float(base["MEDIAN_SECONDS"])
    for w in (1,2,4):
      r=by[(n,b,w)]
      tw=float(r["MEDIAN_SECONDS"])
      speed=t1/tw
      eff=speed/w
      print(f"MULTI01_P0_SUMMARY|N={n}|BATCH={b}|WORKERS={w}|SECONDS={tw:.9f}|SPEEDUP={speed:.6f}|EFFICIENCY={eff:.6f}|NS_PER_COLUMN={float(r['NS_PER_COLUMN']):.3f}|MAX_SIMULTANEOUS={r['MAX_SIMULTANEOUS']}")
PY
