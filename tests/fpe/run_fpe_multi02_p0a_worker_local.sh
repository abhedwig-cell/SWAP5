#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p0a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod" "$BUILD/patch"
trap 'rm -rf "$BUILD"' EXIT

cp src/runtime/mod_fmr_production_application_bootstrap.f90 "$BUILD/patch/mod_fmr_production_application_bootstrap.f90"
cp src/runtime/mod_fmr_groundwater_application_context.f90 "$BUILD/patch/mod_fmr_groundwater_application_context.f90"

python3 - "$BUILD/patch/mod_fmr_production_application_bootstrap.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace(
"module mod_fmr_production_application_bootstrap\n",
"module mod_fmr_production_application_bootstrap\n"
"  use mod_multi02_research_config, only: get_multi02_workers\n",1)
s=s.replace(
"    type(fmr_serialized_reference_backend_t), pointer :: backend => null()",
"    type(fmr_serialized_reference_backend_t), pointer :: backends(:) => null()",1)
s=s.replace("    integer :: i, local_status, n",
            "    integer :: i, local_status, n, worker_count, worker_id",1)
s=s.replace(
"    allocate(self%backend, self%top_boundary)\n"
"    self%numerical = config%numerical\n\n"
"    call self%backend%initialize(self%top_boundary)",
"    worker_count = get_multi02_workers()\n"
"    allocate(self%backends(worker_count), self%top_boundary)\n"
"    self%numerical = config%numerical\n\n"
"    do worker_id = 1, worker_count\n"
"      call self%backends(worker_id)%initialize(self%top_boundary)\n"
"    end do",1)
old="""        call self%registry%bind(config%tiles(i)%tile_id, self%backend, self%columns(i), self%templates(i), &
             self%parameters(i), self%committed(i), self%materializers(i), self%numerical, &
"""
new="""        worker_id = mod(i - 1, worker_count) + 1
        call self%registry%bind(config%tiles(i)%tile_id, self%backends(worker_id), self%columns(i), self%templates(i), &
             self%parameters(i), self%committed(i), self%materializers(i), self%numerical, &
"""
if old not in s: raise SystemExit("MULTI02 bootstrap bind seam missing")
s=s.replace(old,new,1)
s=s.replace("associated(self%backend) .and. associated(self%top_boundary)",
            "associated(self%backends) .and. associated(self%top_boundary)")
s=s.replace("if (associated(self%backend)) deallocate(self%backend)",
            "if (associated(self%backends)) deallocate(self%backends)")
s=s.replace("nullify(self%backend)","nullify(self%backends)")
if "self%backend" in s:
    raise SystemExit("MULTI02 bootstrap scalar backend reference remains")
p.write_text(s)
PY

python3 - "$BUILD/patch/mod_fmr_groundwater_application_context.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace(
"module mod_fmr_groundwater_application_context\n",
"module mod_fmr_groundwater_application_context\n"
"  use mod_multi02_research_config, only: get_multi02_workers\n",1)

start=s.index("  subroutine application_context_trial_cell_heads(")
end=s.index("  end subroutine application_context_trial_cell_heads",start)
end=s.index("\n",end)+1
replacement=r'''  subroutine application_context_trial_cell_heads(self, cell_heads_m, cell_q_swap_m_per_s, status)
    class(fmr_groundwater_application_context_t), intent(inout) :: self
    real(real64), intent(in) :: cell_heads_m(:)
    real(real64), intent(out) :: cell_q_swap_m_per_s(:)
    integer, intent(out) :: status

    type(groundwater_tile_exchange_t), allocatable :: exchanges(:)
    type(groundwater_cell_exchange_t) :: aggregate
    integer :: i, idx, first, participant_status, local_status
    integer :: worker_count, failures

    cell_q_swap_m_per_s = 0.0_real64
    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(cell_heads_m) /= size(self%cells) .or. size(cell_q_swap_m_per_s) /= size(self%cells)) return
    if (self%published) then
      status = FMR_GW_APP_CONTEXT_PUBLICATION_FAILED
      return
    end if
    if (any(self%trial_valid) .or. any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if
    if (any(.not. ieee_is_finite(cell_heads_m))) return
    if (any(self%cells%tile_count /= 1)) then
      status = FMR_GW_APP_CONTEXT_PLAN_FAILED
      return
    end if

    worker_count = get_multi02_workers()
    if (worker_count /= 1 .and. worker_count /= 2 .and. worker_count /= 4) return
    failures = 0

    !$omp parallel do num_threads(worker_count) default(shared) &
    !$omp private(i,idx,first,participant_status,local_status,exchanges,aggregate) &
    !$omp reduction(+:failures) schedule(static,1)
    do i = 1, size(self%cells)
      first = self%cells(i)%tile_begin
      idx = first
      if (idx < 1 .or. idx > size(self%tiles)) then
        failures = failures + 1
        cycle
      end if

      call self%registry%trial_from_origin(self%participant_handles(idx), self%window, cell_heads_m(i), &
           self%trials(idx), participant_status, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK .or. .not. self%trials(idx)%valid) then
        failures = failures + 1
        cycle
      end if
      self%trial_valid(idx) = .true.

      allocate(exchanges(1))
      exchanges(1)%groundwater_cell_id = self%tiles(idx)%groundwater_cell_id
      exchanges(1)%tile_id = self%tiles(idx)%tile_id
      exchanges(1)%tile_lineage_id = self%tiles(idx)%swap_lineage_id
      exchanges(1)%component_kind = GW_TILE_COMPONENT_SWAP
      exchanges(1)%area_fraction = self%tiles(idx)%area_fraction
      exchanges(1)%q_swap_m_per_s = self%trials(idx)%q_swap_m_per_s
      call aggregate_groundwater_cell_tiles(self%cells(i)%topology%groundwater_cell_id, exchanges, aggregate, local_status)
      deallocate(exchanges)
      if (local_status /= GW_TILE_AGG_OK .or. .not. aggregate%available) then
        failures = failures + 1
        cycle
      end if
      cell_q_swap_m_per_s(i) = aggregate%q_swap_area_weighted_m_per_s
    end do
    !$omp end parallel do

    if (failures /= 0 .or. .not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
      call discard_live_candidates_internal(self)
      cell_q_swap_m_per_s = 0.0_real64
      return
    end if
    status = FMR_GW_APP_CONTEXT_OK
  end subroutine application_context_trial_cell_heads
'''
s=s[:start]+replacement+s[end:]
p.write_text(s)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)

mapfile -t BASE_SRC < <(python3 - <<'PY'
from pathlib import Path
s=Path("tests/fpe/run_fpe_profile04_repeated_decomposition.sh").read_text()
a=s.index("MODULE_SRC=(")+len("MODULE_SRC=(")
b=s.index("\n)\n",a)
for line in s[a:b].splitlines():
    line=line.strip()
    if line: print(line)
PY
)

MODULE_SRC=()
config_added=0
for src in "${BASE_SRC[@]}"; do
  if [[ "$src" == "src/runtime/mod_fmr_groundwater_application_context.f90" ||         "$src" == "src/runtime/mod_fmr_production_application_bootstrap.f90" ]]; then
    if [[ "$config_added" == "0" ]]; then
      MODULE_SRC+=(tests/fpe/mod_multi02_research_config.f90)
      config_added=1
    fi
  fi
  if [[ "$src" == "src/runtime/mod_fmr_groundwater_application_context.f90" ]]; then
    MODULE_SRC+=("$BUILD/patch/mod_fmr_groundwater_application_context.f90")
  elif [[ "$src" == "src/runtime/mod_fmr_production_application_bootstrap.f90" ]]; then
    MODULE_SRC+=("$BUILD/patch/mod_fmr_production_application_bootstrap.f90")
  else
    MODULE_SRC+=("$src")
  fi
done

objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$BUILD/mod/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$src" -o "$obj"
  objects+=("$obj")
done

BASE="tests/fapp/test_ppa_wu01_production_application_bootstrap.f90"
OUT="$BUILD/results.txt"
: > "$OUT"

for n in 100 1000 10000; do
  for workers in 1 2 4; do
    SRC="$BUILD/test_n${n}_w${workers}.f90"
    python3 - "$BASE" "$SRC" "$n" "$workers" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2]); n=int(sys.argv[3]); workers=int(sys.argv[4])

src=src.replace("program test_ppa_wu01_production_application_bootstrap",
                "program test_fpe_multi02_p0a",1)
src=src.replace("end program test_ppa_wu01_production_application_bootstrap",
                "end program test_fpe_multi02_p0a",1)
src=src.replace("integer, parameter :: NTILE = 2",f"integer, parameter :: NTILE = {n}",1)
src=src.replace("real(real64), parameter :: T1 = 4100.6875_real64",
                "real(real64), parameter :: T1 = 4100.1876_real64",1)
src=src.replace(
"       FMR_NUMERICAL_CONTINUATION_NONE",
"       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY",1)
src=src.replace(
"  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c, fgc49d_capture_origins_c, &\n"
"       fgc49d_abort_prepublication_c\n",
"  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c, fgc49d_capture_origins_c, &\n"
"       fgc49d_trial_cell_heads_c, fgc49d_trial_response_tangents_c, fgc49d_discard_candidates_c, &\n"
"       fgc49d_abort_prepublication_c\n",1)
src=src.replace(
"  implicit none\n",
"  use, intrinsic :: iso_c_binding, only: c_int, c_int64_t, c_double\n"
"  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE\n"
"  use mod_multi02_research_config, only: set_multi02_workers\n"
"  implicit none\n",1)

start=src.index("  ! Standalone authority:")
end=src.index("\ncontains\n",start)
body=f'''  integer, parameter :: MULTI02_WORKERS = {workers}
  real(c_double) :: cell_heads(NTILE), cell_fluxes(NTILE), cell_tangents(NTILE)
  real(real64) :: trial_seconds(5), tangent_seconds(5), discard_seconds(5)
  real(real64) :: checksum_q, checksum_t, reference_q, reference_t
  integer(int64) :: c0, c1, rate
  integer :: rep

  call set_multi02_workers(MULTI02_WORKERS)
  call initialize_application_config(gw_config)
  gw_config%numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  do i = 1, NTILE
    gw_config%tiles(i)%parameters%bottom_mode = 5
    gw_config%tiles(i)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    allocate(gw_config%tiles(i)%initial_right_derivative(numnod))
    gw_config%tiles(i)%initial_right_derivative = 400.0_real64
  end do
  call gw_app%initialize(gw_config,status)
  call require(status == FMR_APP_BOOT_OK .and. gw_app%ready(), 'MULTI02 bootstrap')

  call compute_reference_head(gw_config%tiles(1)%parameters, gw_config%tiles(1)%groundwater_datum, reference_head_m, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK, 'MULTI02 reference head')

  do i = 1, NTILE
    topology_tiles(i)%tile_id = gw_config%tiles(i)%tile_id
    topology_tiles(i)%swap_lineage_id = gw_config%tiles(i)%tile_id
    topology_tiles(i)%ledger_id = gw_config%tiles(i)%ledger_id
    topology_tiles(i)%groundwater_cell_id = 700000_int64 + int(i,int64)
    topology_tiles(i)%area_fraction = 1.0_real64
    topology_cells(i)%groundwater_cell_id = topology_tiles(i)%groundwater_cell_id
    topology_cells(i)%coupling_id = 800000_int64 + int(i,int64)
    topology_cells(i)%groundwater_service_id = 9001_int64
    topology_cells(i)%groundwater_lineage_id = 900000_int64 + int(i,int64)
    topology_cells(i)%package_slot = i
    topology_cells(i)%modflow_node_id = i
    topology_cells(i)%storage_state_role = GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE
    topology_cells(i)%drainage_owner = GW_DRAINAGE_OWNER_NONE
    call make_predictor(predictors(i),topology_tiles(i),topology_cells(i),reference_head_m,i)
    areas(i)%groundwater_cell_id = topology_cells(i)%groundwater_cell_id
    areas(i)%cell_area_m2 = 1.0_real64
    cell_heads(i)=real(reference_head_m,c_double)
  end do

  call materialize_groundwater_topology(topology_tiles,topology_cells,topology,topology_status)
  call require(topology_status == GW_TOPOLOGY_OK .and. topology%ready(), 'MULTI02 topology')
  call gw_app%materialize_groundwater_context(topology,predictors,areas,context_handle,status)
  call require(status == FMR_APP_BOOT_OK .and. context_handle > 0_int64, 'MULTI02 context')

  ncell=0_c_int; ntile_count=0_c_int
  c_status=fgc49d_context_counts_c(int(context_handle,c_int64_t),ncell,ntile_count)
  call require(c_status==0_c_int .and. ncell==int(NTILE,c_int) .and. ntile_count==int(NTILE,c_int), &
       'MULTI02 context counts')
  c_status=fgc49d_capture_origins_c(int(context_handle,c_int64_t))
  call require(c_status==0_c_int,'MULTI02 capture origins')

  checksum_q=0.0_real64; checksum_t=0.0_real64
  reference_q=0.0_real64; reference_t=0.0_real64
  do rep=1,5
    call system_clock(c0,count_rate=rate)
    c_status=fgc49d_trial_cell_heads_c(int(context_handle,c_int64_t),int(NTILE,c_int),cell_heads,cell_fluxes)
    call system_clock(c1)
    call require(c_status==0_c_int,'MULTI02 trial heads')
    trial_seconds(rep)=real(c1-c0,real64)/real(rate,real64)

    c_status=fgc49d_trial_response_tangents_c(int(context_handle,c_int64_t),int(NTILE,c_int),cell_tangents)
    call require(c_status==0_c_int,'MULTI02 tangent query')
    checksum_q=checksum_q+sum(real(cell_fluxes,real64))
    checksum_t=checksum_t+sum(real(cell_tangents,real64))
    if(rep==1)then
      reference_q=cell_fluxes(1)
      reference_t=cell_tangents(1)
    end if
    call require(maxval(abs(real(cell_fluxes,real64)-reference_q)) <= 1.0e-18_real64, 'MULTI02 q tile identity')
    call require(maxval(abs(real(cell_tangents,real64)-reference_t)) <= 1.0e-15_real64, 'MULTI02 tangent tile identity')

    call system_clock(c0)
    c_status=fgc49d_discard_candidates_c(int(context_handle,c_int64_t))
    call system_clock(c1)
    call require(c_status==0_c_int,'MULTI02 discard')
    discard_seconds(rep)=real(c1-c0,real64)/real(rate,real64)
    call gw_app%copy_committed_revisions(revisions,status)
    call require(status==FMR_APP_BOOT_OK .and. all(revisions==0_int64),'MULTI02 revision identity')
  end do

  call sort5_local(trial_seconds)
  call sort5_local(discard_seconds)
  write(*,'(*(g0))') 'MULTI02_P0A|N=',NTILE,'|WORKERS=',MULTI02_WORKERS, &
       '|TRIAL_SECONDS=',trial_seconds(3),'|NS_PER_TILE=',1.0e9_real64*trial_seconds(3)/real(NTILE,real64), &
       '|DISCARD_SECONDS=',discard_seconds(3),'|Q_CHECKSUM=',checksum_q,'|T_CHECKSUM=',checksum_t, &
       '|Q_FIRST=',reference_q,'|T_FIRST=',reference_t

  call gw_app%release_groundwater_context(status)
  call require(status==FMR_APP_BOOT_OK,'MULTI02 release')
  call gw_app%close(status)
  call require(status==FMR_APP_BOOT_OK,'MULTI02 close')
'''
src=src[:start]+body+src[end:]
needle="contains\n\n"
helper=r'''contains

  subroutine sort5_local(v)
    real(real64),intent(inout)::v(5)
    real(real64)::tmp
    integer::a,b
    do a=1,4
      do b=a+1,5
        if(v(b)<v(a))then
          tmp=v(a); v(a)=v(b); v(b)=tmp
        end if
      end do
    end do
  end subroutine sort5_local

'''
src=src.replace(needle,helper,1)
out.write_text(src)
PY
    gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$SRC" -o "$BUILD/test_n${n}_w${workers}.o"
    gfortran -O3 -fopenmp "${objects[@]}" "$BUILD/test_n${n}_w${workers}.o" -o "$BUILD/test_n${n}_w${workers}"
    OMP_DYNAMIC=FALSE OMP_THREAD_LIMIT=4 OMP_PROC_BIND=spread OMP_PLACES=cores       "$BUILD/test_n${n}_w${workers}" | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import math,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI02_P0A|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=9: raise SystemExit(f"expected 9 rows got {len(rows)}")
by={(int(r["N"]),int(r["WORKERS"])):r for r in rows}
for n in (100,1000,10000):
    base=by[(n,1)]
    q0=float(base["Q_CHECKSUM"]); t0=float(base["T_CHECKSUM"])
    tbase=float(base["TRIAL_SECONDS"])
    for w in (1,2,4):
        r=by[(n,w)]
        q=float(r["Q_CHECKSUM"]); tt=float(r["T_CHECKSUM"])
        if abs(q-q0)>64*2.220446049250313e-16*max(1.0,abs(q0)):
            raise SystemExit(f"q checksum drift N={n} W={w}")
        if abs(tt-t0)>64*2.220446049250313e-16*max(1.0,abs(t0)):
            raise SystemExit(f"tangent checksum drift N={n} W={w}")
        sec=float(r["TRIAL_SECONDS"])
        speed=tbase/sec
        print(f"MULTI02_P0A_SUMMARY|N={n}|WORKERS={w}|SECONDS={sec:.9f}|SPEEDUP={speed:.6f}|EFFICIENCY={speed/w:.6f}|NS_PER_TILE={float(r['NS_PER_TILE']):.3f}|Q_CHECKSUM={q:.17e}|T_CHECKSUM={tt:.17e}")
print("FPE_MULTI02_P0A=PASS")
PY
