"""Compare live four-day policy runs with the source-bound admitted short proofs."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--default', type=Path, required=True)
p.add_argument('--four', type=Path, required=True)
p.add_argument('--platform', choices=['windows', 'ubuntu'], required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
prior = json.loads((ROOT/'integration/f-ci/THERMAL_SUBCYCLE_RESEARCH_20261111.json').read_text())
if a.platform == 'windows':
    archive = ROOT/prior['archive']['path']
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == prior['archive']['sha256']
    handle = tarfile.open(archive, 'r:xz')
    read = lambda n: handle.extractfile('s5-thermal4-abba/'+n).read()
else:
    archive = ROOT/prior['hosted_qualification']['retained_archive']
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == prior['hosted_qualification']['artifact_zip_sha256']
    handle = zipfile.ZipFile(archive)
    read = lambda n: handle.read('heat-abba/'+n)
result = dict(status='DEFAULT_EXACT_INCUMBENT_AND_FOUR_EXACT_PRIVATE_PASS',
              platform=a.platform, prior_archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), runs={})
for arm, folder, previous, count in [('default', a.default, 'A1', 6882), ('four', a.four, 'B1', 3585)]:
    run = json.loads((folder/'RESULT.json').read_text())
    assert run['returncode'] == 0 and not run['censored'] and run['completed_days'] == 4
    hashes = {}
    for name in ['budget.csv', 'conductive_budget.csv', 'crop.csv', 'state.csv', 'endpoint.csv']:
        data = (folder/name).read_bytes()
        assert data == read(previous+'/'+name), (arm, name)
        hashes[name] = hashlib.sha256(data).hexdigest()
    rows = list(csv.DictReader((folder/'budget.csv').open()))
    assert len(rows) == 4 and sum(int(r['accepted_steps']) for r in rows) == count
    result['runs'][arm] = dict(accepted_steps=count, physical_sha256=hashes,
                              executable_sha256=run['executable_sha256'], source_sha256=run['source_sha256'])
handle.close()
a.output.write_text(json.dumps(result, indent=2)+'\n')
print(result['status'])
