#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TEST=tests/fsi/test_fsi16_prescribed_bottom_head.F90
GATE=tests/fsi/run_fsi16_prescribed_bottom_head_gate.sh
TMP="${TMPDIR:-/tmp}/fsi16-response-diag-$$"
mkdir -p "$TMP"
cp "$TEST" "$TMP/test.F90"
cp "$GATE" "$TMP/gate.sh"
restore() {
  cp "$TMP/test.F90" "$TEST"
  cp "$TMP/gate.sh" "$GATE"
  rm -rf "$TMP"
}
trap restore EXIT

python3 - <<'PY'
from pathlib import Path
p=Path('tests/fsi/test_fsi16_prescribed_bottom_head.F90')
s=p.read_text()
old='''  call prepare_workspace(workspace)
  call solver%solve(request_c, workspace, result_c)
  if (result_c%status /= SW_SOLVE_CONVERGED) failures = failures + 1
  if (trim(result_c%diagnostics%route) /= 'legacy-reference-bound') failures = failures + 1
  head_tolerance = max(1.0e-10_real64, 64.0_real64*epsilon(1.0_real64) * &
       max(1.0_real64, abs(request_c%boundary%bottom_head)))
  if (abs(result_c%candidate_state%pressure_head(numnod)-request_c%boundary%bottom_head) > head_tolerance) &
       failures = failures + 1
  if (transfer(result_c%candidate_state%pressure_head(numnod),0_int64) == &
      transfer(result_a%candidate_state%pressure_head(numnod),0_int64)) failures = failures + 1
  expected_qbot = continuity_qbot(request_c, result_c)
  if (transfer(result_c%bottom_flux,0_int64) /= transfer(expected_qbot,0_int64)) failures = failures + 1
  if (transfer(result_c%bottom_flux,0_int64) == transfer(request_c%boundary%bottom_flux,0_int64)) failures = failures + 1
'''
new='''  call prepare_workspace(workspace)
  call solver%solve(request_c, workspace, result_c)
  write(*,'(A,I0,1X,A)') 'F-SI16_DIAG_STATUS ', result_c%status, trim(result_c%diagnostics%route)
  write(*,'(A,L1)') 'F-SI16_DIAG_HEAD_ALLOCATED ', allocated(result_c%candidate_state%pressure_head)
  write(*,'(A,ES24.16)') 'F-SI16_DIAG_REQUEST_HEAD ', request_c%boundary%bottom_head
  if (result_c%status /= SW_SOLVE_CONVERGED) failures = failures + 1
  if (trim(result_c%diagnostics%route) /= 'legacy-reference-bound') failures = failures + 1
  if (allocated(result_c%candidate_state%pressure_head)) then
     write(*,'(A,ES24.16)') 'F-SI16_DIAG_SOLVED_HEAD ', result_c%candidate_state%pressure_head(numnod)
     write(*,'(A,ES24.16)') 'F-SI16_DIAG_BASELINE_HEAD ', result_a%candidate_state%pressure_head(numnod)
     write(*,'(A,ES24.16)') 'F-SI16_DIAG_RESULT_QBOT ', result_c%bottom_flux
     expected_qbot = continuity_qbot(request_c, result_c)
     write(*,'(A,ES24.16)') 'F-SI16_DIAG_EXPECTED_QBOT ', expected_qbot
     write(*,'(A,ES24.16)') 'F-SI16_DIAG_SEEDED_QBOT ', request_c%boundary%bottom_flux
     head_tolerance = max(1.0e-10_real64, 64.0_real64*epsilon(1.0_real64) * &
          max(1.0_real64, abs(request_c%boundary%bottom_head)))
     if (abs(result_c%candidate_state%pressure_head(numnod)-request_c%boundary%bottom_head) > head_tolerance) &
          failures = failures + 1
     if (transfer(result_c%candidate_state%pressure_head(numnod),0_int64) == &
         transfer(result_a%candidate_state%pressure_head(numnod),0_int64)) failures = failures + 1
     if (transfer(result_c%bottom_flux,0_int64) /= transfer(expected_qbot,0_int64)) failures = failures + 1
     if (transfer(result_c%bottom_flux,0_int64) == transfer(request_c%boundary%bottom_flux,0_int64)) failures = failures + 1
  else
     failures = failures + 4
  end if
'''
if s.count(old) != 1:
    raise SystemExit(f'F-SI16 diagnostic response block count={s.count(old)}')
p.write_text(s.replace(old,new,1))

g=Path('tests/fsi/run_fsi16_prescribed_bottom_head_gate.sh')
q=g.read_text()
old='  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"\n'
new='''  if ! timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"; then
    cat "$out/output.txt" >&2
    exit 1
  fi
'''
if q.count(old) != 1:
    raise SystemExit(f'F-SI16 diagnostic runner marker count={q.count(old)}')
g.write_text(q.replace(old,new,1))
PY

set +e
bash "$GATE"
rc=$?
set -e
echo "F-SI16_RESPONSE_DIAGNOSTIC_UNDERLYING_RC=$rc"
# Diagnostic evidence is informational. The unmodified focused gate runs next
# in the normal workflow and remains the blocking authority.
exit 0
