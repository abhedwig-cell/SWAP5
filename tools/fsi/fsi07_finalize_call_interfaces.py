#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"F-SI07 interface finalizer: {path}: expected 1 match, got {count}")
    p.write_text(text.replace(old, new, 1))


def git_blob_sha(path):
    data = (ROOT / path).read_bytes()
    return hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()

soil_old = '''         subroutine headcalc(worker, fsi_workspace, history, state_binding)\n            use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n            use mod_reference_richards_workspace, only: reference_richards_workspace_t\n            use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n            type(a23bu_worker_context_t), intent(inout), optional :: worker\n            type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n            type(a23bu_solver_history_t), target, intent(inout), optional :: history\n            type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n         end subroutine headcalc\n'''
soil_new = '''         subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)\n            use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n            use mod_reference_richards_workspace, only: reference_richards_workspace_t\n            use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n            use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t\n            type(a23bu_worker_context_t), intent(inout), optional :: worker\n            type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n            type(a23bu_solver_history_t), target, intent(inout), optional :: history\n            type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n            type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context\n            type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions\n         end subroutine headcalc\n'''
replace_once('src/legacy/b1_10_port/soilwater.f90', soil_old, soil_new)

test_old = '''    subroutine headcalc(worker, fsi_workspace, history, state_binding)\n      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n      use mod_reference_richards_workspace, only: reference_richards_workspace_t\n      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n      type(a23bu_worker_context_t), target, intent(inout), optional :: worker\n      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n      type(a23bu_solver_history_t), target, intent(inout), optional :: history\n      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n    end subroutine headcalc\n'''
test_new = '''    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)\n      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n      use mod_reference_richards_workspace, only: reference_richards_workspace_t\n      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t\n      type(a23bu_worker_context_t), target, intent(inout), optional :: worker\n      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n      type(a23bu_solver_history_t), target, intent(inout), optional :: history\n      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context\n      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions\n    end subroutine headcalc\n'''
replace_once('tests/fsi/test_fsi07_state_binding.F90', test_old, test_new)

gate_path = ROOT / 'tests/fsi/run_fsi07_gate.sh'
gate = gate_path.read_text()
gate = gate.replace('ADAPTER_TEST="$ROOT/tests/fsi/test_fsi07_adapter_binding.f90"\n',
                    'ADAPTER_TEST="$ROOT/tests/fsi/test_fsi07_adapter_binding.f90"\nTOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"\n', 1)
# Update all four source pins to exact postimage blobs.
pins = {
    'src/legacy/b1_10_port/headcalc.f90': git_blob_sha('src/legacy/b1_10_port/headcalc.f90'),
    'src/legacy/b1_10_port/soilwater.f90': git_blob_sha('src/legacy/b1_10_port/soilwater.f90'),
    'src/adapter/mod_reference_richards_legacy_binding.f90': git_blob_sha('src/adapter/mod_reference_richards_legacy_binding.f90'),
    'src/solver/mod_reference_richards_state_binding.f90': git_blob_sha('src/solver/mod_reference_richards_state_binding.f90'),
}
labels = {
    'src/legacy/b1_10_port/headcalc.f90': 'HeadCalc',
    'src/legacy/b1_10_port/soilwater.f90': 'SoilWater',
    'src/adapter/mod_reference_richards_legacy_binding.f90': 'adapter',
    'src/solver/mod_reference_richards_state_binding.f90': 'state binding',
}
for path, sha in pins.items():
    pattern = re.compile(r'\[\[ "\$\(git rev-parse HEAD:' + re.escape(path) + r'\)" == "[0-9a-f]{40}" \]\] \|\| \{ echo \'F-SI07_PIN FAIL ' + re.escape(labels[path]) + r"' >&2; exit 1; \}")
    repl = f'[[ "$(git rev-parse HEAD:{path})" == "{sha}" ]] || {{ echo \'F-SI07_PIN FAIL {labels[path]}\' >&2; exit 1; }}'
    gate, n = pattern.subn(repl, gate, count=1)
    if n != 1:
        raise SystemExit(f'F-SI07 interface finalizer: pin replacement failed for {path}')

gate = gate.replace("grep -Fq 'call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding)' \"$ADAPTER\"\n",
                    "grep -Fq 'request%evaluation, request%boundary)' \"$ADAPTER\"\n", 1)
old_python = """assert 'result%candidate_state%pressure_head = state_binding%h' in solve\nassert 'result%top_flux = state_binding%qtop' in solve\nprint('F-SI07_ADAPTER_NO_WHOLE_SOLVE_GLOBAL_OVERLAY PASS')\n"""
new_python = """assert 'result%candidate_state%pressure_head = state_binding%h' in solve\nassert 'result%top_flux = state_binding%qtop' in solve\nassert 'request%evaluation, request%boundary' in solve\nassert 'call initialize_reference_state_binding(state_binding, request)' in solve\nfor name in ['gwlinp','dtold','itnumb','kmean','dimoca','fllowgwl','q0','hsurf','runots','flrunoff','ftoph']:\n    assert re.search(r'\\b'+name+r'\\b', solve, re.I) is None, name\nassert "explicit-top-provider-required" in text\nprint('F-SI07_ADAPTER_EXPLICIT_PHYSICAL_STATE_ONLY PASS')\n"""
if old_python not in gate:
    raise SystemExit('F-SI07 interface finalizer: static adapter block not found')
gate = gate.replace(old_python, new_python, 1)
old_compile = '''  gfortran "${FLAGS[@]}" -c "$STATE" -o "$out/state.o"\n  gfortran "${FLAGS[@]}" -c "$ADAPTER_STUBS" -o "$out/stubs.o"\n  gfortran "${FLAGS[@]}" -c "$ADAPTER" -o "$out/adapter.o"\n'''
new_compile = '''  gfortran "${FLAGS[@]}" -c "$STATE" -o "$out/state.o"\n  gfortran "${FLAGS[@]}" -c "$TOP_PROVIDER" -o "$out/top_provider.o"\n  gfortran "${FLAGS[@]}" -c "$ADAPTER_STUBS" -o "$out/stubs.o"\n  gfortran "${FLAGS[@]}" -c "$ADAPTER" -o "$out/adapter.o"\n'''
if old_compile not in gate:
    raise SystemExit('F-SI07 interface finalizer: adapter compile block not found')
gate = gate.replace(old_compile, new_compile, 1)
gate = gate.replace('"$out/contract.o" "$out/worker.o" -o "$out/test"\n',
                    '"$out/top_provider.o" "$out/contract.o" "$out/worker.o" -o "$out/test"\n', 1)
gate_path.write_text(gate)

print('F-SI07_CALL_INTERFACES_MATERIALIZED')
for path, sha in pins.items():
    print(f'{path} {sha}')
