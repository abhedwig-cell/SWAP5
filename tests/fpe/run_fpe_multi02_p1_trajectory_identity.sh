#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

PART="$BUILD/mod_fmr_groundwater_swap_participant.f90"
REG="$BUILD/mod_fmr_groundwater_participant_registry.f90"
RUN="$BUILD/run.sh"
cp src/runtime/mod_fmr_groundwater_swap_participant.f90 "$PART"
cp src/runtime/mod_fmr_groundwater_participant_registry.f90 "$REG"

python3 - "$PART" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle="    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts\n"
if needle not in s: raise SystemExit("participant procedure seam missing")
s=s.replace(needle,needle+"    procedure, public :: multi02_diagnostics => fmr_swap_multi02_diagnostics\n",1)
end="end module mod_fmr_groundwater_swap_participant"
insert=r'''
  subroutine fmr_swap_multi02_diagnostics(self, diagnostics)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    diagnostics = self%diagnostics
  end subroutine fmr_swap_multi02_diagnostics

'''
if end not in s: raise SystemExit("participant end seam missing")
s=s.replace(end,insert+end,1)
p.write_text(s)
PY

python3 - "$REG" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t\n",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_diagnostics_t\n",1)
needle="    procedure, public :: identity => registry_identity\n"
if needle not in s: raise SystemExit("registry procedure seam missing")
s=s.replace(needle,needle+"     procedure, public :: multi02_diagnostics => registry_multi02_diagnostics\n",1)
end="end module mod_fmr_groundwater_participant_registry"
insert=r'''
  subroutine registry_multi02_diagnostics(self, handle, diagnostics, status)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    integer :: idx
    diagnostics = kernel_diagnostics_t()
    call resolve_handle_const(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    call self%slots(idx)%participant%multi02_diagnostics(diagnostics)
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_multi02_diagnostics

'''
if end not in s: raise SystemExit("registry end seam missing")
s=s.replace(end,insert+end,1)
p.write_text(s)
PY

python3 - "$PART" "$REG" "$RUN" <<'PY'
from pathlib import Path
import sys
part,reg,out=map(Path,sys.argv[1:])
s=Path("tests/fpe/run_fpe_multi02_p0_worker_local.sh").read_text()
s=s.replace('ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"','ROOT="$(pwd)"',1)

# Compile generated diagnostic-capable participant and registry copies.
needle='mapfile -t MODULE_SRC < <(python3 - <<\'PY\'\n'
# Insert path replacement after MODULE_SRC extraction closes.
marker='PY\n)\n\nobjects=()'
repl=f'''PY
)
for i in "${{!MODULE_SRC[@]}}"; do
  if [[ "${{MODULE_SRC[$i]}}" == "src/runtime/mod_fmr_groundwater_swap_participant.f90" ]]; then
    MODULE_SRC[$i]="{part}"
  elif [[ "${{MODULE_SRC[$i]}}" == "src/runtime/mod_fmr_groundwater_participant_registry.f90" ]]; then
    MODULE_SRC[$i]="{reg}"
  fi
done

objects=()'''
if marker not in s: raise SystemExit("module list marker missing")
s=s.replace(marker,repl,1)

# Import diagnostics type into embedded test.
old="  use mod_kernel_transactions, only: kernel_committed_state_t\n"
new="  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_diagnostics_t\n"
if old not in s: raise SystemExit("kernel import seam missing")
s=s.replace(old,new,1)

# Add diagnostics/lifecycle storage.
old="  type(groundwater_swap_trial_t), allocatable :: serial_trials(:), parallel_trials(:)\n  integer, allocatable :: pstatus(:), rstatus(:)\n"
new=old+"""  type(kernel_diagnostics_t), allocatable :: s_before(:),s_after(:),p_before(:),p_after(:)
  integer(int64) :: ident_tile,ident_lineage,ident_revision
  logical :: ident_origin,ident_candidate
"""
if old not in s: raise SystemExit("declaration seam missing")
s=s.replace(old,new,1)

old="  allocate(serial_trials(n),parallel_trials(n),pstatus(n),rstatus(n))\n"
new=old+"  allocate(s_before(n),s_after(n),p_before(n),p_after(n))\n"
s=s.replace(old,new,1)

# Snapshot diagnostics immediately before serial trials.
old="""    call system_clock(c0,count_rate=rate)
    do i=1,n
      call registry%trial_from_origin(handles(i),window,target_head(i),serial_trials(i),participant_status,status)
"""
new="""    do i=1,n
      call registry%multi02_diagnostics(handles(i),s_before(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'serial diagnostic before'
    end do
    call system_clock(c0,count_rate=rate)
    do i=1,n
      call registry%trial_from_origin(handles(i),window,target_head(i),serial_trials(i),participant_status,status)
"""
if old not in s: raise SystemExit("serial before seam missing")
s=s.replace(old,new,1)

old="""    call system_clock(c1)
    serial_t(rep)=real(c1-c0,real64)/real(rate,real64)
    do i=1,n
      call registry%discard_candidate(handles(i),status)
"""
new="""    call system_clock(c1)
    serial_t(rep)=real(c1-c0,real64)/real(rate,real64)
    do i=1,n
      call registry%multi02_diagnostics(handles(i),s_after(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'serial diagnostic after'
    end do
    do i=1,n
      call registry%discard_candidate(handles(i),status)
"""
if old not in s: raise SystemExit("serial after seam missing")
s=s.replace(old,new,1)

# Snapshot parallel baseline after serial discard.
old="""    pstatus=GW_SWAP_PARTICIPANT_OK
    rstatus=FMR_GW_REGISTRY_OK
    parallel_trials=groundwater_swap_trial_t()
"""
new="""    do i=1,n
      call registry%multi02_diagnostics(handles(i),p_before(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel diagnostic before'
    end do
    pstatus=GW_SWAP_PARTICIPANT_OK
    rstatus=FMR_GW_REGISTRY_OK
    parallel_trials=groundwater_swap_trial_t()
"""
if old not in s: raise SystemExit("parallel before seam missing")
s=s.replace(old,new,1)

old="""    if(team_seen/=workers) error stop 'omp team mismatch'
    if(any(rstatus/=FMR_GW_REGISTRY_OK) .or. any(pstatus/=GW_SWAP_PARTICIPANT_OK) .or. &
       any(.not.parallel_trials%valid)) error stop 'parallel trial'
    do i=1,n
      qdiff=max(qdiff,abs(parallel_trials(i)%q_swap_m_per_s-serial_trials(i)%q_swap_m_per_s))
"""
new="""    if(team_seen/=workers) error stop 'omp team mismatch'
    if(any(rstatus/=FMR_GW_REGISTRY_OK) .or. any(pstatus/=GW_SWAP_PARTICIPANT_OK) .or. &
       any(.not.parallel_trials%valid)) error stop 'parallel trial'
    do i=1,n
      call registry%multi02_diagnostics(handles(i),p_after(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel diagnostic after'
      call require_diag_equal(s_after(i),p_after(i))
      qdiff=max(qdiff,abs(parallel_trials(i)%q_swap_m_per_s-serial_trials(i)%q_swap_m_per_s))
"""
if old not in s: raise SystemExit("parallel compare seam missing")
s=s.replace(old,new,1)

# After parallel discard, require accepted origin retained and candidate cleared.
old="""    do i=1,n
      call registry%discard_candidate(handles(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel discard'
    end do
  end do
"""
new="""    do i=1,n
      call registry%discard_candidate(handles(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel discard'
      call registry%identity(handles(i),ident_tile,ident_lineage,ident_revision,ident_origin,ident_candidate,status)
      if(status/=FMR_GW_REGISTRY_OK .or. .not.ident_origin .or. ident_candidate .or. ident_revision/=0_int64) &
           error stop 'parallel lifecycle drift'
    end do
  end do
"""
if old not in s: raise SystemExit("lifecycle seam missing")
s=s.replace(old,new,1)

# Add exact comparison helper.
needle="  subroutine sort5(v)\n"
helper=r'''  subroutine require_diag_equal(s,p)
    type(kernel_diagnostics_t),intent(in)::s,p
    if(s%transaction_calls/=p%transaction_calls) error stop 'diag transaction'
    if(s%accepted_substeps/=p%accepted_substeps) error stop 'diag substeps'
    if(s%attempts/=p%attempts) error stop 'diag attempts'
    if(s%retries/=p%retries) error stop 'diag retries'
    if(s%solver_rejections/=p%solver_rejections) error stop 'diag solver rejection'
    if(s%temporal_rejections/=p%temporal_rejections) error stop 'diag temporal rejection'
    if(s%temporal_acceptance_source/=p%temporal_acceptance_source) error stop 'diag temporal source'
    if(s%nonlinear_iterations/=p%nonlinear_iterations) error stop 'diag nonlinear'
    if(s%internal_retries/=p%internal_retries) error stop 'diag internal retry'
    if(s%headcalc_calls/=p%headcalc_calls) error stop 'diag headcalc'
    if(s%jacobian_builds/=p%jacobian_builds) error stop 'diag jacobian'
    if(s%linear_solves/=p%linear_solves) error stop 'diag linear'
    if(s%backtracking_attempts/=p%backtracking_attempts) error stop 'diag backtrack'
  end subroutine require_diag_equal

'''
if needle not in s: raise SystemExit("helper seam missing")
s=s.replace(needle,helper+needle,1)

# Make output marker distinct.
s=s.replace("FPE_MULTI02_P0=PASS","FPE_MULTI02_P1=PASS")
s=s.replace("MULTI02_P0|","MULTI02_P1|")
s=s.replace("MULTI02_P0_SUMMARY|","MULTI02_P1_SUMMARY|")
s=s.replace("FPE_MULTI02_P0_AGGREGATE=PASS","FPE_MULTI02_P1_AGGREGATE=PASS")
out.write_text(s)
PY

bash "$RUN"
