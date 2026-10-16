#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi04-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BASE="tests/fpe/run_fpe_multi02_p0_worker_local.sh"
RUN="$BUILD/run.sh"
cp "$BASE" "$RUN"

python3 - "$RUN" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace('ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"','ROOT="$(pwd)"',1)

# Bind every participant to the serial authority backend. Worker trials below
# deliberately override that binding so discard/commit must follow the live
# candidate backend rather than the slot's default backend.
s=s.replace(
'    w=1+mod(i-1,workers)\n    call registry%bind(columns(i)%column_id,backends(w),columns(i),template,parameters,committed(i),materializers(i), &',
'    w=1\n    call registry%bind(columns(i)%column_id,backends(w),columns(i),template,parameters,committed(i),materializers(i), &',
1)

s=s.replace(
'  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen\n',
'  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen\n  logical :: did_commit\n',
1)

s=s.replace(
'!$omp parallel default(shared) private(i,participant_status,status) num_threads(workers)',
'!$omp parallel default(shared) private(i,w,participant_status,status) num_threads(workers)',
1)

old='''      call registry%trial_from_origin(handles(i),window,target_head(i),parallel_trials(i),participant_status,status)
      pstatus(i)=participant_status
'''
new='''      w=1+mod(i-1,workers)
      call registry%trial_from_origin_on_backend(handles(i),backends(w),window,target_head(i),parallel_trials(i), &
           participant_status,status)
      pstatus(i)=participant_status
'''
if old not in s: raise SystemExit("parallel trial seam missing")
s=s.replace(old,new,1)

marker='''  call sort5(serial_t); call sort5(parallel_t)
'''
insert='''  ! Candidate backend ownership must survive beyond the trial call and route
  ! commit through the exact worker backend that produced the live candidate.
  call registry%trial_from_origin_on_backend(handles(1),backends(workers),window,target_head(1),parallel_trials(1), &
       participant_status,status)
  if(status/=FMR_GW_REGISTRY_OK .or. participant_status/=GW_SWAP_PARTICIPANT_OK .or. .not.parallel_trials(1)%valid) &
       error stop 'worker-owned commit trial'
  call registry%commit_candidate(handles(1),window,did_commit,participant_status,status)
  if(status/=FMR_GW_REGISTRY_OK .or. participant_status/=GW_SWAP_PARTICIPANT_OK .or. .not.did_commit) &
       error stop 'worker-owned commit'
  if(.not.registry%quiescent()) error stop 'registry not quiescent after worker-owned commit'

  call sort5(serial_t); call sort5(parallel_t)
'''
if marker not in s: raise SystemExit("post-loop seam missing")
s=s.replace(marker,insert,1)

s=s.replace("MULTI02_P0|","MULTI04_P1|")
s=s.replace("FPE_MULTI02_P0=PASS","FPE_MULTI04_P1=PASS")
s=s.replace("MULTI02_P0_SUMMARY|","MULTI04_P1_SUMMARY|")
s=s.replace("FPE_MULTI02_P0_AGGREGATE=PASS","FPE_MULTI04_P1_AGGREGATE=PASS")
p.write_text(s)
PY

bash "$RUN"
