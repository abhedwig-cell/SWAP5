#!/usr/bin/env python3
"""Seal source-bound B19 local qualification or a clearly partial recovery."""
import argparse, gzip, hashlib, json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser()
ap.add_argument('--scratch', type=pathlib.Path, required=True)
ap.add_argument('--partial', action='store_true')
ap.add_argument('--verify-docs', action='store_true')
args = ap.parse_args()
scratch = args.scratch.resolve()
source = subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip()
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
prereg = json.loads((ROOT/'integration/audits/PPA_WU05B19_PREREGISTRATION.json').read_text())
assert source == prereg['candidate_source']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

for rel, digest in prereg['source_sha256'].items():
    assert sha(ROOT/rel) == digest, rel

doc_files = ['docs/audits/PPA_WU05B19_DIVDRA_RUNTIME_CONTRACT.md',
             'docs/audits/PPA_WU05B19_DIVDRA_RUNTIME_QUALIFICATION.md',
             'tools/docs/check_docs.py', 'mkdocs.yml']
doc_hashes = {p: sha(ROOT/p) for p in doc_files}
doc_receipt = scratch/'b19-boundary-docs-receipt.json'
if args.verify_docs:
    for label, command in [('docs', [sys.executable, 'tools/docs/check_docs.py']),
                           ('mkdocs', [sys.executable, '-m', 'mkdocs', 'build', '--strict',
                                       '--site-dir', str(scratch/'b19-boundary-docs-site')])]:
        with (scratch/f'b19-boundary-{label}.log').open('w') as output:
            subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, check=True)
    doc_receipt.write_text(json.dumps({'source_sha256': doc_hashes, 'exit_codes': [0, 0]}, indent=2)+'\n')
docs_current = doc_receipt.exists() and json.loads(doc_receipt.read_text()) == {
    'source_sha256': doc_hashes, 'exit_codes': [0, 0]}

low = scratch/'ppa-wu05b19-low-air-runtime-boundary-qualified'
normal = scratch/'ppa-wu05b19-normal-runtime-boundary-preservation'
record = {'work_unit': 'PPA-WU05B19', 'tested_commit': commit,
          'production_source_tree': source, 'source_sha256': {}, 'logs': {},
          'receipts': {}, 'generated_oracles': {}, 'builds': {}, 'gates': {},
          'remote_persisted': False, 'admitted': False, 'runtime_admitted': False,
          'failed_processes': {}, 'negative_observations': {}}

for build in [low, normal]:
    files = (build/'sources').read_text().splitlines()
    record['builds'][build.name] = {
        'sources': files, 'source_sha256': {p: sha(pathlib.Path(p)) for p in files},
        'objects': {str(p.relative_to(build)): sha(p) for p in sorted(build.glob('o*/*.o'))},
        'compiler': subprocess.check_output(['gfortran', '--version'], text=True).splitlines()[0],
        'flags': ['-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp',
                  '-fcheck=all', '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-O0/-O2']}
    for p in sorted(build.rglob('*')):
        if not p.is_file():
            continue
        key = str(p.relative_to(scratch))
        if p.suffix in ['.log', '.err']:
            record['logs'][key] = p.read_text()
        elif p.name.endswith('receipt.json'):
            record['receipts'][key] = json.loads(p.read_text())
        elif p.name.endswith('.failure.json'):
            record['failed_processes'][key] = json.loads(p.read_text())
        elif p.name.startswith('immutable-') and p.suffix == '.f90' or p.suffix == '.inc':
            record['generated_oracles'][key] = {'sha256': sha(p), 'source': p.read_text()}

for p in sorted(scratch.glob('b19*.log')):
    record['logs'][p.name] = p.read_text()
for p in sorted(scratch.glob('b19*negative.json')):
    record['negative_observations'][p.name] = json.loads(p.read_text())
for p in sorted(scratch.glob('frost-b19-preserve-*.log')):
    record['logs']['superseded-source/'+p.name] = p.read_text()

runtime = []
for opt in [0, 2]:
    for fine, cases in [(8192, range(1, 25)), (16384, [1, 9, 13, 23])]:
        for case in cases:
            stem = low/f'o{opt}/case-{case}-fine-{fine}'
            r = json.loads(stem.with_suffix('.receipt.json').read_text())
            assert r['production_source'] == source and r['exit_code'] == 0
            assert r['stdout_sha256'] == sha(stem.with_suffix('.log'))
            assert r['stderr_sha256'] == sha(stem.with_suffix('.err'))
            assert r['test_sha256'] == sha(ROOT/'tests/frost/test_ppa_wu05b19_divdra_runtime.f90')
            assert r['executable_sha256'] == sha(low/f'o{opt}/test')
            assert f'B19_CASE_{case}_RUNTIME=PASS' in stem.with_suffix('.log').read_text()
            runtime.append(r)
            if opt == 2:
                assert stem.with_suffix('.log').read_bytes() == (low/f'o0/case-{case}-fine-{fine}.log').read_bytes()
    assert 'B19_INVALID_OWNER_DOMAIN_CASES=28' in (low/f'o{opt}/case-1-fine-8192.log').read_text()
record['gates']['signed_runtime'] = {'passed': True, 'trajectories': runtime, 'O0_O2_byte_identity': True,
                                  'invalid_owner_domain_cases_per_opt': 28}

for build, route, expected in [(normal, 'normal', 32), (low, 'low_air', 48)]:
    receipts = list((build/'preservation').glob('*.receipt.json'))
    for p in receipts:
        r = json.loads(p.read_text())
        assert r['production_source_tree'] == source and r['process_exit_code'] == 0
        log = pathlib.Path(str(p).removesuffix('.receipt.json'))
        assert sha(log) == r['stdout_sha256']
        binary = pathlib.Path(str(log).removesuffix('.log'))
        if r['family']:
            binary = pathlib.Path(str(binary).removesuffix('-family-'+str(r['family'])))
        assert sha(binary) == r['program_sha256']
        assert sha(ROOT/f"tests/frost/test_{r['program']}.f90") == r['source_sha256']
    complete = len(receipts) == expected
    if complete:
        programs = sorted({json.loads(p.read_text())['program'] for p in receipts})
        for name in programs:
            first = build/'preservation'/f'frost-b19-preserve-{route}-{name}-o0.log'
            second = build/'preservation'/f'frost-b19-preserve-{route}-{name}-o2.log'
            assert first.read_bytes() == second.read_bytes(), name
    record['gates'][route+'_full_module_preservation'] = {
        'passed': complete, 'complete_fresh_processes': len(receipts), 'required_fresh_processes': expected,
        'immutable_original_programs': True, 'O0_O2_byte_identity': complete}

for label, path in [('component', scratch/'b19-boundary-component.json'),
                    ('literal_root', scratch/'b19-boundary-literal-root.json'),
                    ('extended_science', pathlib.Path('/tmp/frost-b15-scientific.json')),
                    ('analytic_science', pathlib.Path('/tmp/frost-b12-scientific.json')),
                    ('adjacent', normal/'b19-adjacent-receipt.json')]:
    d = json.loads(path.read_text())
    if label == 'adjacent':
        assert d['production_source'] == source
    else:
        for rel, digest in d['source_sha256'].items():
            assert sha(ROOT/rel) == digest, (label, rel)
    record['gates'][label] = {'passed': True, 'receipt': d}
    if 'build' in d:
        for p in sorted(pathlib.Path(d['build']).rglob('*')):
            if p.is_file() and p.suffix in ['.f90', '.inc', '.txt', '.log', '.err']:
                key = label+'/'+str(p.relative_to(d['build']))
                record['generated_oracles'][key] = {'sha256': sha(p), 'content': p.read_text()}

record['gates']['moving_canonical'] = {'passed': 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS' in
                                       (scratch/'b19-boundary-canonical.log').read_text()}
record['gates']['docs'] = {'passed': docs_current and 'Documentation source checks passed.' in
                          (scratch/'b19-boundary-docs.log').read_text()}
record['gates']['mkdocs'] = {'passed': docs_current and 'Documentation built in' in
                            (scratch/'b19-boundary-mkdocs.log').read_text()}
record['documentation_source_sha256'] = doc_hashes
mass = []; head = []; temperature = []
for p in low.glob('o0/case-*-fine-8192.log'):
    text = p.read_text()
    mass += [abs(float(x)) for x in re.findall(r'B19_HARD_MASS.*residual=\s*([\d.E+\-]+)', text)]
    head += [float(x) for x in re.findall(r'B19_FINE_COMPARISON.*head=\s*([\d.E+\-]+)', text)]
    temperature += [float(x) for x in re.findall(r'B19_FINE_COMPARISON.*temperature=\s*([\d.E+\-]+)', text)]
record['runtime_maxima'] = {'mass_residual_cm': max(mass), 'fine_head_error_cm': max(head),
                          'fine_temperature_error_c': max(temperature)}
record['qualified'] = all(g['passed'] for g in record['gates'].values())
assert args.partial or record['qualified'], 'Incomplete declared gates block qualification'
record['status'] = 'LOCAL_QUALIFIED_NOT_ADMITTED' if record['qualified'] else 'PARTIAL_LOCAL_RECOVERY_NOT_QUALIFIED'
changed = subprocess.check_output(['git', 'diff', '--name-only', prereg['baseline'], '--'], cwd=ROOT, text=True).splitlines()
for rel in changed:
    p = ROOT/rel
    if p.is_file() and (rel.startswith('src/') or rel.startswith('tests/') or
                       rel in ['docs/audits/PPA_WU05B19_DIVDRA_RUNTIME_CONTRACT.md',
                               'docs/audits/PPA_WU05B19_DIVDRA_RUNTIME_QUALIFICATION.md']):
        record['source_sha256'][rel] = sha(p)
suffix = 'PARTIAL_RECOVERY' if args.partial else 'LOCAL_REPLAY'
path = ROOT/f'docs/audits/evidence/PPA_WU05B19_{suffix}.json.gz'
path.write_bytes(gzip.compress((json.dumps(record, indent=2)+'\n').encode(), mtime=0))
summary = {k: record[k] for k in ['work_unit', 'status', 'tested_commit', 'production_source_tree',
                                'qualified', 'admitted', 'runtime_admitted', 'remote_persisted', 'runtime_maxima']}
summary['gates'] = {k: {'passed': v['passed']} for k, v in record['gates'].items()}
summary['evidence'] = {'path': str(path.relative_to(ROOT)), 'sha256': sha(path), 'bytes': path.stat().st_size}
if not args.partial:
    (ROOT/'integration/audits/PPA_WU05B19_QUALIFICATION.json').write_text(json.dumps(summary, indent=2)+'\n')
print(json.dumps(summary, indent=2))
