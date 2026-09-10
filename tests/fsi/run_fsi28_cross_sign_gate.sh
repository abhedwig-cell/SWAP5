#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_RUNNER="$ROOT/tests/fsi/run_fsi28_interface_sensitivity_gate.sh"
TMP_RUNNER="$ROOT/tests/fsi/.fsi28_cross_sign_gate_$$.sh"
trap 'rm -f "$TMP_RUNNER"' EXIT

[[ -f "$BASE_RUNNER" ]] || { echo 'FSI28_CROSS_SIGN_FAIL base runner missing' >&2; exit 1; }
cp "$BASE_RUNNER" "$TMP_RUNNER"

python3 - "$TMP_RUNNER" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()

# Frozen-contract sign coverage. Preserve the original three F-SI27-local
# tangent probes and add only the qbot=0 crossing plus a minimal positive
# companion at 1% of |qeq|. No FD step, tolerance, physics or solver policy is
# changed by this wrapper.
anchor = "  call check_fsi28_tangent(qeq, 1.01_real64*qeq, 'symmetric-neighbor')\n"
insert = anchor + "  ! Frozen-contract cross-sign probes. Keep the F-SI27 top forcing and\n" \
    + "  ! cross qbot=0 by the smallest predeclared 1% qeq-scale companion.\n" \
    + "  ! These establish native-qbot sign coverage only; they do not widen the\n" \
    + "  ! qualified forcing envelope beyond the explicitly tested points.\n" \
    + "  call check_fsi28_tangent(qeq, 0.0_real64, 'zero-qbot')\n" \
    + "  call check_fsi28_tangent(qeq, -0.01_real64*qeq, 'positive-qbot-minimal')\n"
if s.count(anchor) != 1:
    raise SystemExit('FSI28_CROSS_SIGN_TRANSFORM_FAIL tangent insertion anchor mismatch')
s = s.replace(anchor, insert, 1)
old = "[[ \"$(grep -c '^FSI28_TANGENT:' \"$out/output.txt\")\" == 3 ]] || fail \"O${opt} expected three tangent cases\""
new = "[[ \"$(grep -c '^FSI28_TANGENT:' \"$out/output.txt\")\" == 5 ]] || fail \"O${opt} expected five tangent cases\""
if s.count(old) != 1:
    raise SystemExit('FSI28_CROSS_SIGN_TRANSFORM_FAIL tangent-count anchor mismatch')
s = s.replace(old, new, 1)

# The prescribed-qbot tangent must be unavailable for the other already-bound
# lower-boundary families. Exercise the same production adapter with sensitivity
# explicitly requested and prove that no tangent backsolve/publication occurs.
call_anchor = "  call check_fsi28_retry(qeq, qpert)\n"
call_insert = call_anchor + "  call check_fsi28_nonprescribed_modes(qeq, qpert)\n"
if s.count(call_anchor) != 1:
    raise SystemExit('FSI28_NONPRESCRIBED_TRANSFORM_FAIL call anchor mismatch')
s = s.replace(call_anchor, call_insert, 1)

proc_anchor = "  end subroutine check_fsi28_retry\n\n'''\n"
# Use a double-quoted Python raw literal here because the replacement itself
# deliberately contains the base runner's triple-single-quote terminator.
proc_insert = r"""  end subroutine check_fsi28_retry

  subroutine check_fsi28_nonprescribed_modes(qtop_case, qbot_case)
    real(real64), intent(in) :: qtop_case, qbot_case
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: res5, res7, resm2
    type(reference_richards_legacy_workspace_t) :: ws5, ws7, wsm2

    call configure_request(req, parameters, constitutive, source_sink, top_provider, initial_state, &
         qtop_case, qbot_case)
    req%request_interface_sensitivity = .true.
    req%boundary%bottom_mode = 5
    req%boundary%bottom_head = h0
    call solver%solve(req, ws5, res5)
    call require(.not.res5%interface_sensitivity%available, 'mode 5 publishes no prescribed-qbot tangent')
    call require(res5%diagnostics%interface_sensitivity_backsolves == 0, 'mode 5 performs no tangent backsolve')

    call configure_request(req, parameters, constitutive, source_sink, top_provider, initial_state, &
         qtop_case, qbot_case)
    req%request_interface_sensitivity = .true.
    req%boundary%bottom_mode = 7
    call solver%solve(req, ws7, res7)
    call require(.not.res7%interface_sensitivity%available, 'mode 7 publishes no prescribed-qbot tangent')
    call require(res7%diagnostics%interface_sensitivity_backsolves == 0, 'mode 7 performs no tangent backsolve')

    call configure_request(req, parameters, constitutive, source_sink, top_provider, initial_state, &
         qtop_case, qbot_case)
    req%request_interface_sensitivity = .true.
    req%boundary%bottom_mode = -2
    call solver%solve(req, wsm2, resm2)
    call require(.not.resm2%interface_sensitivity%available, 'mode -2 publishes no prescribed-qbot tangent')
    call require(resm2%diagnostics%interface_sensitivity_backsolves == 0, 'mode -2 performs no tangent backsolve')

    write(*,'(A,I0,A,I0,A,I0)') 'FSI28_NONPRESCRIBED_MODES:MODE5=',res5%status, &
         ':MODE7=',res7%status,':MODEM2=',resm2%status
  end subroutine check_fsi28_nonprescribed_modes

'''
"""
if s.count(proc_anchor) != 1:
    raise SystemExit('FSI28_NONPRESCRIBED_TRANSFORM_FAIL procedure anchor mismatch')
s = s.replace(proc_anchor, proc_insert, 1)
p.write_text(s)
PY

bash "$TMP_RUNNER"
echo 'FSI28_CROSS_SIGN_GATE PASS'
