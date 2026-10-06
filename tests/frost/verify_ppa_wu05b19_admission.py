#!/usr/bin/env python3
"""Verify complete immutable B19 evidence; never relabel an incomplete run."""
import argparse
import gzip
import hashlib
import json
import math
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = '24fda78fd9a38964c16c89d5505b0056185ac410'
EVIDENCE_SHA = 'd74b5df08b04bb7f720d49921e233bc0975105e0fbcb8fbb510afd7f3c4dcfb6'
GATES = {'signed_runtime', 'normal_full_module_preservation',
         'low_air_full_module_preservation', 'component', 'literal_root',
         'extended_science', 'analytic_science', 'adjacent', 'moving_canonical',
         'docs', 'mkdocs'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, label):
    if not condition:
        raise ValueError(label)


def file_hash(path, expected):
    if path == 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh':
        original = subprocess.check_output(['git', 'show',
            'a0630beff3b7b329ede3e57a10620116e5b1f456:' + path], cwd=ROOT)
        require(digest(original) == expected, 'original sealed moving-guard identity')
        old = b'if git merge-base --is-ancestor a8b142871 HEAD; then'
        new = b'if git merge-base --is-ancestor a0630beff3b7b329ede3e57a10620116e5b1f456 HEAD; then'
        require(original.count(old) == 1, 'unique lineage recovery seam')
        require((ROOT / path).read_bytes() == original.replace(old, new),
                'exact navigation-only moving-guard successor')
        return
    require(digest((ROOT / path).read_bytes()) == expected, 'dependency drift: ' + path)


def validate_record(record):
    require(record['production_source_tree'] == SOURCE, 'production tree')
    require(record['qualified'] is True, 'qualified flag')
    require(set(record['gates']) == GATES, 'declared gate set')
    require(all(v['passed'] is True for v in record['gates'].values()), 'failed gate')
    for path, expected in {**record['source_sha256'],
                           **record['documentation_source_sha256']}.items():
        file_hash(path, expected)
    for build in record['builds'].values():
        require(len(build['sources']) >= 178, 'whole module closure')
        for path, expected in build['source_sha256'].items():
            if '/SWAP5/' in path:
                file_hash(path.split('/SWAP5/', 1)[1], expected)
            else:
                require(path.endswith('/consistent_grid_stubs.f90'), 'unknown generated source')
                original = (ROOT / 'tests/fsi/fsi04_real_headcalc_stubs.f90').read_bytes()
                old = b'  real(8), parameter :: disnod(numnod+1) = 1.0d0'
                new = b'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'
                require(original.count(old) == 1 and digest(original.replace(old, new)) == expected,
                        'consistent-grid generated source')
    logs = record['logs']
    runtime = record['gates']['signed_runtime']
    expected_matrix = {(o, c, 8192) for o in (0, 2) for c in range(1, 25)}
    expected_matrix |= {(o, c, 16384) for o in (0, 2) for c in (1, 9, 13, 23)}
    require(len(runtime['trajectories']) == 56, 'runtime trajectory count')
    require({(r['optimization'], r['case'], r['fine_steps'])
             for r in runtime['trajectories']} == expected_matrix, 'runtime matrix')
    require(runtime['invalid_owner_domain_cases_per_opt'] == 28, 'domain guards')
    driver_hash = digest((ROOT / 'tests/frost/test_ppa_wu05b19_divdra_runtime.f90').read_bytes())
    actual_runtime = [r for k, r in record['receipts'].items() if '/case-' in k]
    require(len(actual_runtime) == 56 and {(r['optimization'], r['case'], r['fine_steps'])
            for r in actual_runtime} == expected_matrix, 'actual runtime receipt matrix')
    for key, receipt in record['receipts'].items():
        if '/case-' in key:
            require(receipt['exit_code'] == 0 and receipt['production_source'] == SOURCE,
                    'runtime receipt exit/source')
            require(receipt['test_sha256'] == driver_hash, 'runtime driver identity')
            log_key = key.removesuffix('.receipt.json') + '.log'
            text = logs[log_key]
            require(digest(text.encode()) == receipt['stdout_sha256'], 'runtime stdout hash')
            require(digest(logs[log_key.removesuffix('.log') + '.err'].encode()) ==
                    receipt['stderr_sha256'], 'runtime stderr hash')
            require(f"B19_CASE_{receipt['case']}_RUNTIME=PASS" in text and
                    'B19_APPLICATION=PASS' in text and text.count('B19_FINE_COMPARISON') == 1,
                    'runtime complete markers')
            mass = re.findall(r'B19_HARD_MASS.*residual=\s*([\d.E+\-]+)', text)
            head = re.findall(r'B19_FINE_COMPARISON.*head=\s*([\d.E+\-]+)', text)
            temp = re.findall(r'B19_FINE_COMPARISON.*temperature=\s*([\d.E+\-]+)', text)
            for values, limit in ((mass, 1e-12), (head, 1e-6), (temp, 1e-4)):
                require(len(values) == 1 and math.isfinite(float(values[0])) and
                        abs(float(values[0])) <= limit, 'runtime unchanged budget')
            if receipt['optimization'] == 2:
                require(text == logs[log_key.replace('/o2/', '/o0/')], 'runtime O0/O2 identity')
    original = json.loads(gzip.decompress((ROOT /
        'docs/audits/evidence/PPA_WU05B15_LOCAL_REPLAY.json.gz').read_bytes()))
    for route, count in (('normal', 32), ('low_air', 48)):
        receipts = [(k, v) for k, v in record['receipts'].items()
                    if '/preservation/' in k and v['route'] == route]
        gate = record['gates'][route + '_full_module_preservation']
        require(len(receipts) == gate['complete_fresh_processes'] ==
                gate['required_fresh_processes'] == count, 'preservation count: ' + route)
        require(len({(v['optimization'], v['program'], v['family'])
                     for _, v in receipts}) == count, 'duplicate preservation receipt')
        require(all(sum(v['optimization'] == o for _, v in receipts) == count // 2
                    for o in (0, 2)), 'preservation optimization count')
        for key, receipt in receipts:
            require(receipt['complete_case'] is True and receipt['process_exit_code'] == 0 and
                    receipt['production_source_tree'] == SOURCE, 'preservation completion/source')
            file_hash('tests/frost/test_' + receipt['program'] + '.f90', receipt['source_sha256'])
            text = logs[key.removesuffix('.receipt.json')]
            require(digest(text.encode()) == receipt['stdout_sha256'], 'preservation stdout hash')
            marker = ('FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'
                      if receipt['program'] == 'ppa_wu05b_frost_runtime' else 'RUNTIME=PASS')
            require(marker in text, 'preservation PASS marker')
            old_key = 'frost-b15-preserve-' + route + '-' + receipt['program'] + '-o' + str(receipt['optimization'])
            if receipt['family'] is not None:
                old_key += '-family-' + str(receipt['family'])
            old_key += '.log'
            if old_key in original['logs']:
                require(text == original['logs'][old_key], 'immutable original stdout identity')
            if receipt['family'] is not None:
                require(text.count('FINE_COMPARISON') == 6, 'full original family continuation')
            if receipt['optimization'] == 2:
                require(text == logs[key.removesuffix('.receipt.json').replace('-o2', '-o0')],
                        'preservation O0/O2 identity')
        for optimization in (0, 2):
            selected = next(k for k, v in receipts if v['program'] == 'ppa_wu05b15_' +
                            ('normal_runtime' if route == 'normal' else 'low_air_runtime')
                            and v['optimization'] == optimization)
            combined = re.sub(r'-family-\d+\.log\.receipt\.json$', '.log', selected)
            require(logs[combined] == original['runtime_output_snapshots'][route + '_O' + str(optimization)],
                    'complete original B15 family matrix')
    for name in ('component', 'literal_root', 'extended_science', 'analytic_science'):
        for path, expected in record['gates'][name]['receipt']['source_sha256'].items():
            file_hash(path, expected)
    c = record['gates']['component']['receipt']
    require((c['cases'], c['accepted_component_cases'], c['unavailable_original_tiny_scalar_cases'],
             c['invalid_domain_cases'], c['actual_reference_boundary_cases']) ==
            (4536, 3240, 1296, 32, 2), 'component matrix')
    require(c['typed_O0_O2_byte_identity'] and c['reference_O0_O2_byte_identity'] and
            c['actual_B17_corrected_reference_output_identity'], 'component identity')
    require(record['gates']['extended_science']['receipt']['cases_per_opt'] == 1507,
            'extended science matrix')
    a = record['gates']['analytic_science']['receipt']
    require((a['cases'], a['derivative_checks']) == (148, 132), 'analytic science matrix')
    root = record['gates']['literal_root']['receipt']['runs']
    require(root['O0'] == root['O2'] and 'PPA_EXACT01_LITERAL_COMPENSATION_CASES=330' in root['O0']
            and 'PPA_EXACT01_UNCHANGED_DISPATCH_CASES=12' in root['O0'], 'literal root matrix')
    adjacent = record['gates']['adjacent']['receipt']
    require(adjacent['production_source'] == SOURCE, 'adjacent source')
    require(len(adjacent['programs']) == 26, 'adjacent complete matrix')
    for value in adjacent['programs'].values():
        require(value['exit_code'] == 0 and value['source'] == SOURCE, 'adjacent receipt')
    for name, value in adjacent['programs'].items():
        if name.endswith('-O2'):
            require(value['stdout_sha256'] == adjacent['programs'][name[:-3] + '-O0']['stdout_sha256'],
                    'adjacent optimization identity')
    require('FCI_CANONICAL_LINEAGE_AWARE_GATE PASS' in logs['b19-boundary-canonical.log'],
            'moving canonical actual log')
    require(bool(record['negative_observations']), 'negative evidence retained')
    return {'passed': True, 'production_source_tree': SOURCE, 'gates': len(GATES),
            'runtime_trajectories': 56, 'normal_preservation': 32, 'low_air_preservation': 48}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--result', type=pathlib.Path)
    args = ap.parse_args()
    plan = json.loads((ROOT / 'integration/audits/PPA_WU05B19_ADMISSION_PLAN.json').read_text())
    require(plan['candidate_source'] == SOURCE and plan['evidence_sha256'] == EVIDENCE_SHA, 'plan pins')
    require(subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT,
                                    text=True).strip() == SOURCE, 'current production subtree')
    require(not subprocess.check_output(['git', 'diff', '--name-only', 'HEAD', '--', 'src'],
                                        cwd=ROOT, text=True).strip(), 'dirty production source')
    data = (ROOT / 'docs/audits/evidence/PPA_WU05B19_LOCAL_REPLAY.json.gz').read_bytes()
    require(digest(data) == EVIDENCE_SHA, 'immutable replay digest')
    result = validate_record(json.loads(gzip.decompress(data)))
    result['head'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    result['evidence_sha256'] = EVIDENCE_SHA
    if args.result:
        args.result.write_text(json.dumps(result, indent=2) + '\n')
    print('B19_COMPLETE_IMMUTABLE_EVIDENCE_ADMISSION=PASS')
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
