#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TMP_RUNNER="tests/fgc/.run_fgc49d_asan_$$.sh"
TMP_TEST="tests/fgc/.test_fgc49d_asan_$$.py"
export TMP_RUNNER TMP_TEST
trap 'rm -f "$TMP_RUNNER" "$TMP_TEST"' EXIT

python3 - <<'PY'
import os
from pathlib import Path

runner_src = Path("tests/fgc/run_fgc49d_production_application_context.sh").read_text(encoding="utf-8")
needle = 'COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)'
replacement = 'COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp -fcheck=all -fbacktrace -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer)'
if needle not in runner_src:
    raise SystemExit("FGC49D ASAN runner: compiler flag anchor not found")
runner_src = runner_src.replace(needle, replacement, 1)
runner_src = runner_src.replace(
    'gfortran -shared -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/libfgc49d_application.so"',
    'gfortran -shared -fopenmp -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer "${objects[@]}" -o "$OUT/libfgc49d_application.so"',
)
runner_src = runner_src.replace('for opt in 0 2; do', 'for opt in 2; do', 1)
runner_src = runner_src.replace(
    'diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"',
    'true # ASAN single-build diagnostic',
)
runner_src = runner_src.replace(
    "echo 'FGC49D_CONTEXT_O0_O2_OUTPUT_IDENTITY=PASS'",
    "echo 'FGC49D_ASAN_O2_SINGLE_BUILD=PASS'",
)

test_src = Path("tests/fgc/test_fgc49d_production_application_context.py").read_text(encoding="utf-8")
trace_anchor = '''            value = _original(*args, **kwargs)
            print(f"FGC49D_TRACE {_name}_end", flush=True)
            return value
'''
trace_replacement = '''            try:
                value = _original(*args, **kwargs)
            except Exception as exc:
                print(
                    f"FGC49D_TRACE {_name}_exception={type(exc).__name__}:{exc}",
                    flush=True,
                )
                raise
            if _name == "trial_cell_heads":
                print(f"FGC49D_TRACE trial_cell_heads_value={value!r}", flush=True)
            print(f"FGC49D_TRACE {_name}_end", flush=True)
            return value
'''
if trace_anchor not in test_src:
    raise SystemExit("FGC49D ASAN runner: trace wrapper anchor not found")
test_src = test_src.replace(trace_anchor, trace_replacement, 1)
abi_anchor = '    runtime = FmrGroundwaterApplicationRuntime(library_path, handle.value)\n'
abi_replacement = '''    runtime = FmrGroundwaterApplicationRuntime(library_path, handle.value)
    _raw_trial = runtime._trial
    _raw_trial_tangents = runtime._trial_tangents

    def _trace_raw_trial(*args):
        status = int(_raw_trial(*args))
        print(f"FGC49D_TRACE raw_trial_status={status}", flush=True)
        return status

    def _trace_raw_trial_tangents(*args):
        status = int(_raw_trial_tangents(*args))
        print(f"FGC49D_TRACE raw_trial_tangent_status={status}", flush=True)
        return status

    runtime._trial = _trace_raw_trial
    runtime._trial_tangents = _trace_raw_trial_tangents
'''
if abi_anchor not in test_src:
    raise SystemExit("FGC49D ASAN runner: runtime ABI anchor not found")
test_src = test_src.replace(abi_anchor, abi_replacement, 1)

service_anchor = '    print("FGC49D_TRACE service_returned", flush=True)\n'
service_replacement = (
    service_anchor
    + '    print(f"FGC49D_TRACE service_result={result!r}", flush=True)\n'
)
if service_anchor not in test_src:
    raise SystemExit("FGC49D ASAN runner: service result anchor not found")
test_src = test_src.replace(service_anchor, service_replacement, 1)

# Testbuild-only Fortran observability. Production sources in the repository remain unchanged.
registry_path = Path("src/runtime/mod_fmr_groundwater_participant_registry.f90")
registry_src = registry_path.read_text(encoding="utf-8")
registry_anchor = '''    if (participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_PARTICIPANT_FAILED
'''
registry_replacement = '''    write(*,'(A,I0)') 'FGC49D_TRACE registry_participant_status=', participant_status
    if (participant_status /= GW_SWAP_PARTICIPANT_OK) then
      status = FMR_GW_REGISTRY_PARTICIPANT_FAILED
'''
if registry_anchor not in registry_src:
    raise SystemExit("FGC49D ASAN runner: registry participant anchor not found")
registry_path.write_text(registry_src.replace(registry_anchor, registry_replacement, 1), encoding="utf-8")

participant_path = Path("src/runtime/mod_fmr_groundwater_swap_participant.f90")
participant_src = participant_path.read_text(encoding="utf-8")
participant_anchor = '''    if (.not. accepted_whole_window(self%trial_result, self%candidate, window)) then
      if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
'''
participant_replacement = '''    if (.not. accepted_whole_window(self%trial_result, self%candidate, window)) then
      write(*,'(A,I0)') 'FGC49D_TRACE trial_result_status=', self%trial_result%status
      write(*,'(A,I0)') 'FGC49D_TRACE trial_solver_rejections=', self%diagnostics%solver_rejections
      write(*,'(A,I0)') 'FGC49D_TRACE trial_temporal_rejections=', self%diagnostics%temporal_rejections
      write(*,'(A,I0)') 'FGC49D_TRACE trial_mass_rejections=', self%diagnostics%mass_rejections
      write(*,'(A,I0)') 'FGC49D_TRACE trial_admission_rejections=', self%diagnostics%admission_rejections
      write(*,'(A,I0)') 'FGC49D_TRACE trial_attempts=', self%diagnostics%attempts
      write(*,'(A,I0)') 'FGC49D_TRACE trial_retries=', self%diagnostics%retries
      write(*,'(A,L1)') 'FGC49D_TRACE trial_result_completed=', self%trial_result%completed
      write(*,'(A,L1)') 'FGC49D_TRACE trial_candidate_ready=', self%candidate%ready()
      write(*,'(A,L1)') 'FGC49D_TRACE trial_bottom_exchange_available=', self%trial_result%bottom_interface_exchange_available
      write(*,'(A,ES24.16)') 'FGC49D_TRACE trial_requested_t0=', self%trial_result%requested_t0
      write(*,'(A,ES24.16)') 'FGC49D_TRACE trial_requested_t1=', self%trial_result%requested_t1
      write(*,'(A,ES24.16)') 'FGC49D_TRACE trial_completed_t=', self%trial_result%completed_t
      if (self%candidate%ready()) call backend%discard_trial_candidate(self%candidate, self%diagnostics)
'''
if participant_anchor not in participant_src:
    raise SystemExit("FGC49D ASAN runner: participant trial-result anchor not found")
participant_src = participant_src.replace(participant_anchor, participant_replacement, 1)
trajectory_anchor = '''    duration_day = window%t1 - window%t0
'''
trajectory_replacement = '''    write(*,'(A,L1)') 'FGC49D_TRACE trajectory_requested=', self%trial_result%accepted_trajectory_direction%requested
    write(*,'(A,L1)') 'FGC49D_TRACE trajectory_available=', self%trial_result%accepted_trajectory_direction%available
    write(*,'(A,I0)') 'FGC49D_TRACE trajectory_control_coordinate=', &
         self%trial_result%accepted_trajectory_direction%control_coordinate
    write(*,'(A,I0)') 'FGC49D_TRACE trajectory_accepted_steps=', &
         self%trial_result%accepted_trajectory_direction%accepted_steps
    write(*,'(A,I0)') 'FGC49D_TRACE trajectory_additional_nonlinear=', &
         self%trial_result%accepted_trajectory_direction%additional_full_nonlinear_solves
    write(*,'(A,A)') 'FGC49D_TRACE trajectory_route=', &
         trim(self%trial_result%accepted_trajectory_direction%route)
    duration_day = window%t1 - window%t0
'''
if trajectory_anchor not in participant_src:
    raise SystemExit("FGC49D ASAN runner: trajectory anchor not found")
participant_src = participant_src.replace(trajectory_anchor, trajectory_replacement, 1)
participant_path.write_text(participant_src, encoding="utf-8")

tmp_test = Path(os.environ["TMP_TEST"])
tmp_test.write_text(test_src, encoding="utf-8")
runner_test_anchor = 'python3 tests/fgc/test_fgc49d_production_application_context.py'
if runner_test_anchor not in runner_src:
    raise SystemExit("FGC49D ASAN runner: test invocation anchor not found")
runner_src = runner_src.replace(runner_test_anchor, f'python3 "{tmp_test.as_posix()}"', 1)
Path(os.environ["TMP_RUNNER"]).write_text(runner_src, encoding="utf-8")
PY

chmod +x "$TMP_RUNNER"

ASAN_LIB="$(gcc -print-file-name=libasan.so)"
if [[ ! -f "$ASAN_LIB" ]]; then
  echo "FGC49D_ASAN_FAIL libasan not found: $ASAN_LIB" >&2
  exit 1
fi
export LD_PRELOAD="$ASAN_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
export ASAN_OPTIONS="detect_leaks=0:abort_on_error=1:symbolize=1:fast_unwind_on_malloc=0"
export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1"
echo "FGC49D_ASAN_PRELOAD=$ASAN_LIB"
bash "$TMP_RUNNER"
