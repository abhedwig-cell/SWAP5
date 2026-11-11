"""Read-only changed-grid comparison; no scientific-equivalence acceptance."""
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import tarfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--full', type=Path, required=True)
p.add_argument('--receipt', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
prior = root/'research/hybrid-water01'
manifest = json.loads((prior/'grass-substep4-full-manifest.json').read_text())
archive_path = prior/'grass-substep4-full-20261111.tar.xz'
digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
assert digest == manifest['archive_sha256']
four = json.loads((prior/'grass-substep4-full-receipt.json').read_text())
sixteen = json.loads(a.receipt.read_text())
assert sixteen['status'] == 'FULL_ORIGINAL_GRASS_SUBSTEP16_AND_OWN_RESTARTS_PASS'
assert four['original_inputs_sha256'] == sixteen['original_inputs_sha256']
changes = {}
with tarfile.open(archive_path) as archive:
    for name in ['budget.csv', 'crop.csv', 'conductive_budget.csv']:
        raw = archive.extractfile('full/'+name).read()
        assert hashlib.sha256(raw).hexdigest() == four['full_audit']['output_sha256'][name]
        old = list(csv.DictReader(io.StringIO(raw.decode())))
        new = list(csv.DictReader((a.full/name).open(newline='')))
        assert len(old) == len(new) == 1827
        assert list(old[0]) == list(new[0])
        result = {}
        for key in old[0]:
            diffs = [float(n[key])-float(o[key]) for o, n in zip(old, new)]
            assert all(math.isfinite(v) for v in diffs)
            i = max(range(1827), key=lambda j: abs(diffs[j]))
            result[key] = {'largest_absolute_daily_difference': abs(diffs[i]),
                           'day': i+1, 'sixteen_minus_four': diffs[i],
                           'day188_four': float(old[187][key]),
                           'day188_sixteen': float(new[187][key])}
        changes[name] = result
result = {
    'status': 'CHANGED_NUMERICAL_GRID_COMPARISON_RECORDED_NOT_SCIENTIFIC_EQUIVALENCE',
    'prior_four_archive_sha256': digest,
    'original_inputs_identical': True,
    'accepted_steps': {'four': four['full_audit']['accepted_steps'],
                       'sixteen': sixteen['full_audit']['accepted_steps']},
    'launcher_seconds': {'four': four['elapsed_seconds'], 'sixteen': sixteen['elapsed_seconds']},
    'cost_scope': 'Separate full executions on the same host, not controlled alternating full-period timing. Short ABBA evidence remains separately scoped.',
    'differences': changes,
    'scientific_scope': 'Retain failed original B0/day188 comparison and prior causal tests in their exact tested scope. No tolerance change, new reference or scientific acceptance.'}
a.output.write_text(json.dumps(result, indent=2)+'\n', newline='\n')
print(json.dumps({k: v for k, v in result.items() if k != 'differences'}))
