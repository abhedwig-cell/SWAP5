#!/usr/bin/env python3
"""Fail-closed original full B19 low-air matrix validation; not admission."""
import argparse, gzip, hashlib, json, math, pathlib, re, subprocess
from run_low_air_complete import ROOT, MATRIX, candidate_recipe

BASE = 'c591205c5e03f1c96c6488eb53c562265f749556'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def verify_complete(folder, check_binaries=False):
    folder = pathlib.Path(folder)
    report = json.loads((folder / 'RESULTS.json').read_text())
    if report['scope'] != 'FULL_ORIGINAL_48_LOW_AIR_WARM_PROVIDERS' or report['matrix'] != MATRIX or not report['complete']:
        raise ValueError('incomplete/changed owning scope')
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip()
    if report['source_tree'] != source:
        raise ValueError('foreign numerical source')
    policy = report['policy']
    if policy not in ['baseline', 'candidate'] or report['workers'] not in range(1, 5):
        raise ValueError('foreign policy/scheduling')
    expected = {(opt, name, family) for opt in [0, 2] for name, count in MATRIX.items()
                for family in (range(1, count + 1) if count else [None])}
    seen = set()
    scientific = {}
    accepted = rejected = 0
    max_head = max_temperature = 0.
    old = json.loads(gzip.decompress((ROOT / 'docs/audits/evidence/PPA_WU05B15_LOCAL_REPLAY.json.gz').read_bytes()))
    historical_matches = historical_differences = 0
    if policy == 'baseline':
        import sys
        sys.path.insert(0, str(ROOT / 'tests/performance'))
        from low_air_successor_authority import verify_source
        verify_source()
    original_sources = {}
    for name in MATRIX:
        path = f'tests/frost/test_{name}.f90'
        original = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT)
        if (ROOT / path).read_bytes() != original:
            raise ValueError('owning original assertion/input drift')
        original_sources[name] = original
    for run in report['runs']:
        key = run['optimization'], run['program'], run['family']
        if key not in expected or key in seen:
            raise ValueError('foreign/duplicate case')
        seen.add(key)
        opt, name, family = key
        if run['exit'] != 0 or not run['complete']:
            raise ValueError('failed/nonterminal original program')
        original = original_sources[name]
        recipe = candidate_recipe(original.decode()).encode() if policy == 'candidate' else original
        driver = folder / f'o{opt}/{name}.f90'
        if driver.read_bytes() != recipe or run['recipe_sha256'] != digest(recipe) or run['original_sha256'] != digest(original):
            raise ValueError('changed physical recipe/period/assertion')
        if check_binaries and digest((folder / f'o{opt}/{name}').read_bytes()) != run['binary_sha256']:
            raise ValueError('executable drift')
        stdout = (folder / f'o{opt}-{name}-family-{family}.stdout').read_bytes()
        if digest(stdout) != run['stdout_sha256']:
            raise ValueError('executed output drift')
        text = stdout.decode()
        if text.count('_RUNTIME=PASS') != 1 or text.count('FINE_COMPARISON') != 6 or run['fine_comparisons'] != 6:
            raise ValueError('missing original 65536-step comparisons')
        fine = re.findall(r'FINE_COMPARISON head_cm=\s*(\S+) temperature_c=\s*(\S+)', text)
        if len(fine) != 6:
            raise ValueError('incomplete fine results')
        for head, temperature in fine:
            head, temperature = float(head), float(temperature)
            if not 0 <= head <= 1.e-6 or not 0 <= temperature <= 1.e-4:
                raise ValueError('unchanged original fine budgets failed')
            max_head, max_temperature = max(max_head, head), max(max_temperature, temperature)
        counters = [list(map(int, row)) for row in re.findall(r'substeps=\s*(\d+)\s+rejections=\s*(\d+)', text)]
        if counters != run['counters'] or len(counters) != 6:
            raise ValueError('foreign physical-interval counters')
        accepted += sum(row[0] for row in counters)
        rejected += sum(row[1] for row in counters)
        for field in ['cpu', 'wall']:
            if not math.isfinite(run[field]) or run[field] <= 0:
                raise ValueError('invalid child timing')
        scientific[key] = stdout
        if policy == 'baseline':
            oldkey = f'frost-b15-preserve-low_air-{name}-o{opt}' + (f'-family-{family}' if family else '') + '.log'
            # Historical B15 source is distinct from pinned current canonical.
            # Preserve it as an oracle within its own authority, never rewrite it.
            expected_old = old['logs'].get(oldkey)
            if expected_old is None and name == 'ppa_wu05b15_low_air_runtime':
                snapshot = old['runtime_output_snapshots']['low_air_O' + str(opt)]
                pieces = re.split(r'(?=PPA_WU05B15_SOIL_FAMILY=)', snapshot)
                expected_old = next((piece for piece in pieces if piece.startswith('PPA_WU05B15_SOIL_FAMILY=' + str(family) + '\n')), None)
            if expected_old == text: historical_matches += 1
            else: historical_differences += 1
    if seen != expected or len(seen) != 48:
        raise ValueError('partial full owning matrix')
    for opt, name, family in expected:
        if scientific[0, name, family] != scientific[2, name, family]:
            raise ValueError('O0/O2 identity failure')
    if not math.isclose(report['native_cpu'], sum(run['cpu'] for run in report['runs']), rel_tol=1.e-12):
        raise ValueError('overlapping/foreign CPU total')
    if not math.isclose(report['build_link_cpu'], sum(event['cpu'] for event in report['events']), rel_tol=1.e-12):
        raise ValueError('foreign build CPU total')
    if report.get('interrupted_wall'):
        if report['policy'] != 'baseline' or report['whole_wall'] is not None or report.get('recovery', {}).get('continuous_whole_wall') != 'UNKNOWN':
            raise ValueError('interrupted baseline cannot claim continuous wall')
    timing_fields = ['parent_cpu', 'native_cpu', 'build_link_cpu'] + ([] if report.get('interrupted_wall') else ['whole_wall'])
    for field in timing_fields:
        if not math.isfinite(report[field]) or report[field] <= 0:
            raise ValueError('invalid enclosing timing')
    if report['tenfold_proved'] or report['canonical_admission']:
        raise ValueError('single receipt cannot confer performance/admission')
    return {'original_programs': 48, 'original_fine_comparisons': 288, 'policy': policy,
            'whole_wall': report['whole_wall'], 'native_cpu': report['native_cpu'],
            'build_link_cpu': report['build_link_cpu'], 'parent_cpu': report['parent_cpu'],
            'accepted_substeps_reported': accepted, 'reported_physical_intervals': 288, 'temporal_rejections_reported': rejected,
            'max_head_error_cm': max_head, 'max_temperature_error_c': max_temperature,
            'immutable_original_stdout': 'DISTINCT_SOURCE_BOUND_HISTORICAL_AUTHORITY' if policy == 'baseline' else 'DISTINCT_NUMERICAL_POLICY_ALL_ORIGINAL_ASSERTIONS',
            'historical_source_tree': old['production_source_tree'],
            'historical_matching_programs': historical_matches, 'historical_different_or_missing_programs': historical_differences,
            'provider_compilation': report['cold_provider_build'], 'tenfold_proved': False,
            'canonical_admission': False}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=pathlib.Path)
    parser.add_argument('--check-binaries', action='store_true')
    args = parser.parse_args()
    print(json.dumps(verify_complete(args.folder, args.check_binaries), indent=2))
