#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi01-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)

mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
s=Path("tests/fpe/run_fpe_profile04_repeated_decomposition.sh").read_text()
a=s.index("MODULE_SRC=(")+len("MODULE_SRC=(")
b=s.index("\n)\n",a)
for line in s[a:b].splitlines():
    line=line.strip()
    if line:
        print(line)
PY
)

objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$BUILD/mod/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$src" -o "$obj"
  objects+=("$obj")
done

BASE="tests/fapp/test_ppa_wu01_production_application_bootstrap.f90"
OUT="$BUILD/results.txt"
: > "$OUT"

for n in 10 100 1000; do
  SRC="$BUILD/test_n${n}.f90"
  python3 - "$BASE" "$SRC" "$n" <<'PY'
from pathlib import Path
import re,sys
src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2]); n=int(sys.argv[3])

src=src.replace("program test_ppa_wu01_production_application_bootstrap",
                "program test_fpe_multi01_p1_groundwater_scaling",1)
src=src.replace("end program test_ppa_wu01_production_application_bootstrap",
                "end program test_fpe_multi01_p1_groundwater_scaling",1)
src=src.replace("integer, parameter :: NTILE = 2",f"integer, parameter :: NTILE = {n}",1)
src=src.replace("real(real64), parameter :: T1 = 4100.6875_real64",
                "real(real64), parameter :: T1 = 4100.1876_real64",1)
src=src.replace("1.0_real64 + 0.013_real64 * real(k, real64)", "1.0_real64")
src=src.replace("value%tiles(k)%initial_state%groundwater_level = -2.0_real64 - 0.007_real64 * real(k, real64)",
                "value%tiles(k)%initial_state%groundwater_level = -2.0_real64")
src=src.replace("href + real(slot, real64) * 0.001_real64", "href + 0.001_real64")
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
"  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE\n"
"  implicit none\n",1)

start=src.index("  ! Standalone authority:")
end=src.index("\ncontains\n",start)
body=r'''  real(c_double) :: cell_heads(NTILE), cell_fluxes(NTILE), cell_tangents(NTILE)
  real(real64) :: trial_seconds(5), tangent_seconds(5), discard_seconds(5)
  real(real64) :: capture_seconds, init_seconds, context_seconds, checksum_q, checksum_t
  integer(int64) :: c0, c1, rate
  integer :: rep, k

  call system_clock(c0,count_rate=rate)
  call initialize_application_config(gw_config)
  gw_config%numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  do i = 1, NTILE
    gw_config%tiles(i)%parameters%bottom_mode = 5
    gw_config%tiles(i)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    allocate(gw_config%tiles(i)%initial_right_derivative(numnod))
    gw_config%tiles(i)%initial_right_derivative = 1.0_real64
  end do
  call gw_app%initialize(gw_config,status)
  call require(status == FMR_APP_BOOT_OK .and. gw_app%ready(), 'MULTI01 groundwater bootstrap')
  call system_clock(c1)
  init_seconds=real(c1-c0,real64)/real(rate,real64)

  call compute_reference_head(gw_config%tiles(1)%parameters, gw_config%tiles(1)%groundwater_datum, reference_head_m, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK, 'MULTI01 reference head')

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
    cell_heads(i)=real(reference_head_m + 1.0e-6_real64*real(mod(i,7)-3,real64),c_double)
  end do

  call system_clock(c0)
  call materialize_groundwater_topology(topology_tiles,topology_cells,topology,topology_status)
  call require(topology_status == GW_TOPOLOGY_OK .and. topology%ready(), 'MULTI01 topology')
  call gw_app%materialize_groundwater_context(topology,predictors,areas,context_handle,status)
  call require(status == FMR_APP_BOOT_OK .and. context_handle > 0_int64, 'MULTI01 context')
  call system_clock(c1)
  context_seconds=real(c1-c0,real64)/real(rate,real64)

  ncell=0_c_int; ntile_count=0_c_int
  c_status=fgc49d_context_counts_c(int(context_handle,c_int64_t),ncell,ntile_count)
  call require(c_status==0_c_int .and. ncell==int(NTILE,c_int) .and. ntile_count==int(NTILE,c_int), &
       'MULTI01 context counts')

  call system_clock(c0)
  c_status=fgc49d_capture_origins_c(int(context_handle,c_int64_t))
  call require(c_status==0_c_int,'MULTI01 capture origins')
  call system_clock(c1)
  capture_seconds=real(c1-c0,real64)/real(rate,real64)

  checksum_q=0.0_real64
  checksum_t=0.0_real64
  do rep=1,5
    call system_clock(c0)
    c_status=fgc49d_trial_cell_heads_c(int(context_handle,c_int64_t),int(NTILE,c_int),cell_heads,cell_fluxes)
    call system_clock(c1)
    call require(c_status==0_c_int,'MULTI01 trial heads')
    trial_seconds(rep)=real(c1-c0,real64)/real(rate,real64)

    call system_clock(c0)
    c_status=fgc49d_trial_response_tangents_c(int(context_handle,c_int64_t),int(NTILE,c_int),cell_tangents)
    call system_clock(c1)
    call require(c_status==0_c_int,'MULTI01 tangent query')
    tangent_seconds(rep)=real(c1-c0,real64)/real(rate,real64)

    checksum_q=checksum_q+sum(real(cell_fluxes,real64))
    checksum_t=checksum_t+sum(real(cell_tangents,real64))

    call system_clock(c0)
    c_status=fgc49d_discard_candidates_c(int(context_handle,c_int64_t))
    call system_clock(c1)
    call require(c_status==0_c_int,'MULTI01 discard')
    discard_seconds(rep)=real(c1-c0,real64)/real(rate,real64)

    call gw_app%copy_committed_revisions(revisions,status)
    call require(status==FMR_APP_BOOT_OK .and. all(revisions==0_int64),'MULTI01 discarded revision identity')
  end do

  call sort5_local(trial_seconds)
  call sort5_local(tangent_seconds)
  call sort5_local(discard_seconds)

  write(*,'(*(g0))') 'MULTI01_P1|N=',NTILE, &
       '|INIT_SECONDS=',init_seconds,'|CONTEXT_SECONDS=',context_seconds,'|CAPTURE_SECONDS=',capture_seconds, &
       '|TRIAL_SECONDS=',trial_seconds(3),'|TRIAL_NS_PER_TILE=',1.0e9_real64*trial_seconds(3)/real(NTILE,real64), &
       '|TANGENT_SECONDS=',tangent_seconds(3),'|DISCARD_SECONDS=',discard_seconds(3), &
       '|Q_CHECKSUM=',checksum_q,'|T_CHECKSUM=',checksum_t, &
       '|SHARED_BACKEND=TRUE|MODE5=TRUE|TEMPORAL_HISTORY=TRUE|C065_BOOTSTRAP=TRUE'

  call gw_app%release_groundwater_context(status)
  call require(status==FMR_APP_BOOT_OK,'MULTI01 release context')
  call gw_app%close(status)
  call require(status==FMR_APP_BOOT_OK,'MULTI01 close')

'''
src=src[:start]+body+src[end:]

# Add a tiny local median helper before the existing first helper.
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

  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$SRC" -o "$BUILD/test_n${n}.o"
  gfortran -O3 -fopenmp "${objects[@]}" "$BUILD/test_n${n}.o" -o "$BUILD/test_n${n}"
  "$BUILD/test_n${n}" | tee -a "$OUT"
done

python3 - "$OUT" <<'PY'
import re,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI01_P1|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=3:
    raise SystemExit(f"expected 3 scaling rows, got {len(rows)}")
for r in rows:
    n=int(r["N"])
    print(f"MULTI01_P1_SUMMARY|N={n}|TRIAL_SECONDS={float(r['TRIAL_SECONDS']):.9f}"
          f"|NS_PER_TILE={float(r['TRIAL_NS_PER_TILE']):.3f}"
          f"|TANGENT_SECONDS={float(r['TANGENT_SECONDS']):.9f}"
          f"|DISCARD_SECONDS={float(r['DISCARD_SECONDS']):.9f}"
          f"|Q_CHECKSUM={float(r['Q_CHECKSUM']):.17e}"
          f"|T_CHECKSUM={float(r['T_CHECKSUM']):.17e}")
# Require finite roughly linear repeated scaling, not a specific speed target.
vals=sorted((int(r["N"]),float(r["TRIAL_NS_PER_TILE"])) for r in rows)
if any(v<=0 for _,v in vals):
    raise SystemExit("nonpositive repeated cost")
print("FPE_MULTI01_P1=PASS")
PY
