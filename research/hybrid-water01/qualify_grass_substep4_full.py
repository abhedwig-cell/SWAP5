"""Read-only full original Grassgrowth four-step qualification.

Reuses the existing published water/uptake/conductive assertions unchanged.
Model execution and fresh-process restarts use run_original.py separately.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/dataqual15'))
from checkpoint_layout import layout

module_path = Path(__file__).with_name('audit_grass_current.py')
loader = importlib.util.spec_from_file_location('unchanged_grass_balance_audit', module_path)
audit_module = importlib.util.module_from_spec(loader)
loader.loader.exec_module(audit_module)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--full', type=Path, required=True)
    p.add_argument('--restarts', type=Path, required=True)
    p.add_argument('--spec', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--file-index', type=Path, help='Retained original absolute build path to extracted member map')
    a = p.parse_args()
    spec = json.loads(a.spec.read_text())
    release = spec['release']
    build = json.loads((a.bundle/'BUILD.json').read_text())
    index = json.loads(a.file_index.read_text()) if a.file_index else None

    def bound(original):
        if index is None:
            return Path(original)
        path = (a.file_index.parent/index[original]).resolve()
        assert path.is_relative_to(a.file_index.parent.resolve())
        return path

    assert sha(a.bundle/'BUILD.json') == release['build_sha256']
    assert build['grass_numerical_profile'] == 'thermal-subcycle4-1e-5C'
    assert build['profile'] == 'production'
    assert sha(a.bundle/build['executable']) == release['executable_sha256'] == build['executable_sha256']
    assert sha(bound(release['input_library'])) == release['input_library_sha256']
    for name in ['source_sha256', 'object_sha256']:
        assert build[name] == release[name]
        for path, expected in build[name].items():
            assert sha(bound(path)) == expected, path
    original = ROOT/'reference/swap-4.3.1/projects/2.grassgrowth'
    original_names = {'input.swp':'swap.swp', 'input.met':'260.met', 'grass.crp':'grass.crp',
                      'swap.bbc':'swap.bbc', 'swap.dra':'swap.dra'}
    assert build['original_inputs_sha256'] == release['original_inputs_sha256']
    for name, h in build['original_inputs_sha256'].items():
        assert sha(a.full/name) == sha(original/original_names[name]) == h
    assert sha(a.full/'application.binding') == release['application_binding_sha256']
    binding = json.loads((a.full/'application.binding').read_text())
    assert binding['grass_numerical_profile'] == build['grass_numerical_profile']
    assert binding['executable_sha256'] == build['executable_sha256']
    full = json.loads((a.full/'RESULT.json').read_text())
    assert full['returncode'] == 0 and not full['censored']
    assert full['requested_days'] == full['completed_days'] == 1827
    assert full['executable_sha256'] == build['executable_sha256']
    assert full['source_sha256'] == build['source_sha256']
    for name, expected in full['files'].items():
        assert sha(a.full/name) == expected, name
    assert full['command'][4] == '' and full['command'][-1] == 'thermal-control-4'
    launch = json.loads((a.full/'LAUNCH.json').read_text())
    assert launch['restart_sha256'] is None
    assert layout((a.full/'checkpoint.bin').read_bytes())['clock'] == 1827
    proof = audit_module.audit(a.full, 1, 1827)
    assert abs(proof['cumulative_water_residual_cm']) <= 1e-10
    cuts = {}
    for first, last in spec['cuts']['fresh_own_restarts']:
        folder = a.restarts/f'{first}-{last}'
        r = json.loads((folder/'RESULT.json').read_text())
        assert r['returncode'] == 0 and not r['censored']
        assert r['requested_days'] == r['completed_days'] == last
        assert r['executable_sha256'] == build['executable_sha256']
        assert r['source_sha256'] == build['source_sha256']
        for name, expected in r['files'].items():
            assert sha(folder/name) == expected, name
        assert r['command'][-1] == 'thermal-control-4'
        origin = a.full/f'checkpoint-{first}.bin'
        assert layout(origin.read_bytes())['clock'] == first
        l = json.loads((folder/'LAUNCH.json').read_text())
        assert l['restart_sha256'] == sha(origin)
        assert (folder/'restart-origin.bin').read_bytes() == origin.read_bytes()
        audit_module.restart(a.full, folder, first+1, last, terminal=(last == 1827))
        if last != 1827:
            assert (folder/'checkpoint.bin').read_bytes() == (a.full/f'checkpoint-{last}.bin').read_bytes()
        suffix = audit_module.audit(folder, first+1, last)
        assert abs(suffix['cumulative_water_residual_cm']) <= 1e-10
        cuts[f'{first}-{last}'] = dict(status='EXACT_OWN_PROCESS_SUFFIX_AND_CHECKPOINT_PASS',
            origin_sha256=sha(origin), final_sha256=sha(folder/'checkpoint.bin'),
            elapsed_seconds=r['seconds'], audit=suffix)
    historical = audit_module.historical_comparison(a.full,
        ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz')
    timing_path = a.full/'native-process-times.json'
    native_timing = json.loads(timing_path.read_text(encoding='utf-8-sig')) if timing_path.exists() else {
        'status': 'UNKNOWN', 'reason': 'No retained native process-handle observation'}
    result = dict(status='FULL_ORIGINAL_GRASS_SUBSTEP4_AND_OWN_RESTARTS_PASS',
        canonical_source=spec['canonical_source'], executable_sha256=release['executable_sha256'],
        compiler=build['compiler'], flags=build['flags'],
        profile=build['grass_numerical_profile'], original_inputs_sha256=build['original_inputs_sha256'],
        elapsed_seconds=full['seconds'], native_process_timing=native_timing,
        full_audit=proof, exact_own_restarts=cuts,
        historical_comparison=historical,
        balance_auditor_sha256=sha(module_path), qualification_script_sha256=sha(__file__),
        full_launch_sha256=sha(a.full/'LAUNCH.json'),
        full_run_result_sha256=sha(a.full/'RESULT.json'),
        scope='One complete original-input1827-day production O2 trajectory and four own process cuts. '
              'Original failed B0/day188 comparison remains visible. Conductive heat is not complete surface energy. '
              'Whole scientific equivalence and portable/full-project runtime parity are not granted.')
    a.output.write_text(json.dumps(result, indent=2)+'\n', newline='\n')
    print(json.dumps({k:result[k] for k in ['status','elapsed_seconds','full_audit']}))


if __name__ == '__main__':
    main()
