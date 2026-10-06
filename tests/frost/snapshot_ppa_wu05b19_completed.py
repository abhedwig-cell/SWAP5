#!/usr/bin/env python3
"""Snapshot complete source-bound cases only, never qualify running/partial work."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = '636e782080abdd2c0366f96317c4f59e8170dc53'
ap = argparse.ArgumentParser()
ap.add_argument('--output', required=True)
args = ap.parse_args()
assert subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip() == SOURCE
status = json.loads((ROOT / 'integration/audits/PPA_WU05B19_STATUS.json').read_text())
inherited = ROOT / status['partial_evidence']['path']
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(inherited) == status['partial_evidence']['sha256']
previous = json.loads(gzip.decompress(inherited.read_bytes()))
assert previous['production_source'] == SOURCE and not previous['qualification']
manifest = dict(previous['manifest'])
completed = {}
def add(path):
    path = Path(path)
    content = path.read_bytes()
    manifest[str(path)] = {'sha256': hashlib.sha256(content).hexdigest(), 'content': content.decode()}


upstream_replay = None
upstream_record = Path('/tmp/frost-b19-upstream-micro-preservation.json')
if upstream_record.exists():
    upstream_replay = json.loads(upstream_record.read_text())
    reconciliation = json.loads((ROOT / 'integration/audits/PPA_WU05B19_UPSTREAM_RECONCILIATION.json').read_text())
    upstream = reconciliation['observed_canonical']
    replay_receipt = reconciliation['fresh_standalone_component_replay']
    assert sha(upstream_record) == replay_receipt['record_sha256']
    assert upstream_replay['tested_postimage'] == upstream
    assert upstream_replay['runs']['O0'] == upstream_replay['runs']['O2']
    assert upstream_replay['runs']['O0'].count('MICRO01_CORRECTED_LITERAL_CASES=2600') == 1
    for relative, expected in upstream_replay['source_sha256'].items():
        content = subprocess.check_output(['git', 'show', f'{upstream}:{relative}'], cwd=ROOT)
        assert hashlib.sha256(content).hexdigest() == expected
        manifest[f'upstream@{upstream}/{relative}'] = {'sha256': expected, 'content': content.decode()}
    add(upstream_record)
    upstream_log = Path('/tmp/frost-b19-upstream-micro-preservation.log')
    assert sha(upstream_log) == replay_receipt['stdout_sha256']
    assert upstream_log.read_text() == upstream_replay['runs']['O0'] + upstream_replay['runs']['O2'] + 'MICRO01_CORRECTED_TABLE_O0_O2_IDENTICAL=PASS\n'
    add(upstream_log)
def add_record(path):
    path = Path(path)
    if not path.exists():
        return
    record = json.loads(path.read_text())
    assert record.get('production_source', record.get('production_source_tree', SOURCE)) == SOURCE
    add(path)
    completed[path.name] = record
    if 'build' in record:
        build = Path(record['build'])
        for name in ('output.txt', 'error.txt', 'cases.txt'):
            for output in build.rglob(name):
                add(output)
    for relative, expected in record.get('source_sha256', {}).items():
        source = Path(relative) if Path(relative).is_absolute() else ROOT / relative
        assert sha(source) == expected, source
        add(source)
for name in ('compile', 'source', 'component-preservation', 'additional', 'positive-preservation', 'incumbent-normal', 'incumbent-low_air', 'external-preservation', 'scientific', 'exact', 'jarvis', 'jarvis-dispersion', 'walsum', 'walsum-dispersion', 'remaining', 'normal-runtime', 'low-runtime'):
    add_record(f'/tmp/frost-b19-{name}.json')
case_receipts = {}
for receipt in Path('/tmp').glob('ppa-wu05b19-runtime-*/o*/family-*.receipt.json'):
    record = json.loads(receipt.read_text())
    assert record['production_source'] == SOURCE
    if not record['complete_case'] or record['exit_code'] != 0:
        continue
    output = receipt.with_name(receipt.name.replace('.receipt.json', '.txt'))
    error = receipt.with_name(receipt.name.replace('.receipt.json', '.err'))
    assert sha(output) == record['stdout_sha256'] and sha(error) == record['stderr_sha256']
    assert output.read_text().count('B19_RUNTIME_PASS ') == 1
    trajectories = 2 if record['route'] == 'normal' else 6
    assert output.read_text().count('B19_PRIMARY ') == trajectories
    assert output.read_text().count('B19_FINE ') == trajectories
    for path in (receipt, output, error):
        add(path)
    case_receipts[str(receipt)] = record
for receipt in Path('/tmp').glob('frost-b19-*.log.receipt.json'):
    record = json.loads(receipt.read_text())
    complete = record.get('complete', record.get('complete_case', False))
    exit_code = record.get('exit_code', record.get('process_exit_code', -1))
    if not complete or exit_code != 0:
        continue
    assert record.get('production_source', record.get('production_source_tree')) == SOURCE
    output = receipt.with_name(receipt.name.removesuffix('.receipt.json'))
    assert sha(output) == record['stdout_sha256']
    add(receipt)
    add(output)
    case_receipts[str(receipt)] = record
for path in ROOT.joinpath('tests/frost').glob('*wu05b19*'):
    if path.is_file():
        add(path)
add(ROOT / 'integration/audits/PPA_WU05B19_ENVIRONMENT_RECOVERY.json')
record = {'work_unit': 'PPA-WU05B19', 'status': 'RECOVERED_COMPLETE_CASE_CHECKPOINT_NOT_QUALIFICATION', 'production_source': SOURCE,
          'qualification': False, 'admitted': False, 'inherited_replay_sha256': sha(inherited), 'manifest': manifest,
          'completed_records': completed, 'completed_case_receipts': case_receipts,
          'upstream_component_preservation': upstream_replay,
          'pending': 'All remaining complete low-air runtime/incumbent families, full O0/O2 identity and final qualification/admission. Running physical outputs are excluded.'}
output = Path(args.output)
output.write_bytes(gzip.compress(json.dumps(record, sort_keys=True).encode(), mtime=0))
print(json.dumps({'path': str(output), 'sha256': sha(output), 'bytes': output.stat().st_size, 'manifest_files': len(manifest), 'completed_case_receipts': len(case_receipts), 'qualification': False}, indent=2))
