"""Actual opposite initialization code images and targeted short native state."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

R = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(R / 'tests/nomacro_drainage'), str(R / 'tests/nomacro_scheduled_subsurface'), str(R / 'app/hybrid_water')]
from ria12_boundary_source import complete_inverse, git
from explicit_bottom9_runtime import m, own
from snow58_compiled_postimage import compare
from analytical_hydraulic_archives import SHA


def main():
    parser = argparse.ArgumentParser()
    for key in ('profile', 'reference-work', 'build-root', 'output'):
        parser.add_argument('--' + key, type=Path, required=True)
    parser.add_argument('--short-native', action='store_true')
    args = parser.parse_args()
    complete_inverse()
    head = git('rev-parse', 'HEAD').decode().strip()
    original = json.loads((args.profile / 'RESULT.json').read_text())
    assert original['status'] == 'ACTUAL_RIA12_BOUNDARY_FULL35_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    args.output.mkdir()
    inputs = args.output / 'input'
    inputs.mkdir()
    previous = Path(original['input_root'])
    for path in previous.iterdir():
        if not path.is_file():
            continue
        raw = path.read_bytes()
        if path.name == 'swap.swp':
            raw, count = re.subn(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)2\b', lambda match: match[1] + b'1', raw)
            assert count == 1
        (inputs / path.name).write_bytes(raw)
    project = m.e.load(inputs, original_output=True, time_step_policy='original-adaptive-day-seed-v1')
    bundle = args.build_root / 'bundle'
    command = [sys.executable, '-B', 'tools/solute/run_water.py', '--model', project.model, '--experimental-project', str(inputs),
               '--original-output', '--experimental-time-step-policy', project.time_step_policy, '--reference-work', str(args.reference_work),
               '--build-only', '--donor-opt', original['optimization'], '--kernel-opt', original['optimization'], '--output', str(bundle)]
    with (args.output / 'build.stdout').open('xb') as out, (args.output / 'build.stderr').open('xb') as err:
        result = subprocess.run(command, cwd=R, stdout=out, stderr=err, timeout=240)
    result.check_returncode()
    assert git('rev-parse', 'HEAD').decode().strip() == head
    m.validate_bundle(bundle, args.reference_work, project)
    baseline = Path(original['build_root'])
    sources = lambda root: {p.relative_to(root).as_posix(): p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90', '.f', '.for', '.inc')}
    left, right = sources(baseline), sources(bundle)
    assert left and left.keys() == right.keys()
    generated = []
    for name, path in sorted(left.items()):
        a, b = path.read_bytes(), right[name].read_bytes()
        assert a.replace(b'\r\n', b'\n') == b.replace(b'\r\n', b'\n')
        generated.append(dict(file=name, actual_original_sha256=SHA(a), actual_current_sha256=SHA(b)))
    compiled = compare(baseline, bundle)
    record = dict(status='ACTUAL_RIA12_BOUNDARY_OPPOSITE_INITIALIZATION_ALL_GENERATED_COMPILED_POSTIMAGES_PASS_NOT_ADMITTED', actual_compiler_source=head,
                  original_compiler_source=original['source'], profile=str(args.profile), profile_RESULT_sha256=SHA((args.profile / 'RESULT.json').read_bytes()),
                  actual_original_BUILD_sha256=original['actual_BUILD_sha256'], actual_current_BUILD_sha256=SHA((bundle / 'BUILD.json').read_bytes()),
                  actual_current_build_root=str(bundle), actual_input_root=str(inputs), input_inventory=m.e.inventory(inputs),
                  kind=original['kind'], optimization=original['optimization'], generated_sources=generated, compiled=compiled,
                  original_initialization=2, current_initialization=1, completed_full35_periods_replayed=False, short_native=None, canonical_admission=False)
    (args.output / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n')
    if args.short_native:
        trajectory, data = m.trajectory(bundle, args.reference_work, project, args.output / 'short-trajectory', 2, {1, 2}, 120)
        cold = own(bundle, args.reference_work, project, args.output / 'short-trajectory', data, 1, 2, args.output / 'short-own-1')
        old_data = m.rows(args.profile / 'trajectory')
        with zipfile.ZipFile(args.output / 'short-trajectory/accepted-column-1-day-2.zip') as a, zipfile.ZipFile(args.profile / 'trajectory/accepted-column-1-day-2.zip') as b:
            equal_native = all(a.read(name) == b.read(name) for name in ('macro.bin', 'result.end'))
        record['short_native'] = dict(days=2, trajectory=trajectory, cold=cold,
                                      actual_initial2_physical_prefix_exact=m.physical(data) == m.physical(old_data[:2]),
                                      actual_initial2_complete_day2_native_exact=equal_native)
        (args.output / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n')
    complete_inverse()
    assert git('rev-parse', 'HEAD').decode().strip() == head
    print(record['status'], original['kind'], original['optimization'], 'short-native', bool(record['short_native']))


if __name__ == '__main__':
    main()
