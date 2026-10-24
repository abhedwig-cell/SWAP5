"""Seal current source repair proof and preserve earlier failed observations."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'benchmarks/performance'
STATUS = ROOT / 'integration/performance/PERF01_PICARD_CORNER_STATUS.json'
sha = lambda b: hashlib.sha256(b).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--runs', type=Path, required=True)
    a = ap.parse_args()
    run = a.runs.resolve()
    names = ['corner-parent-owner', 'corner-small-v1', 'corner-small-v2', 'corner-small-v3',
             'corner-dt-discriminator', 'corner-capture1x', 'corner-capture4x',
             'corner-capture1x-v2', 'corner-capture4x-v2', 'picard-newton-1x-prefix',
             'picard-newton-4x-prefix', 'picard-newton-full1x', 'picard-newton-full4x',
             'corner-current-O0', 'corner-current-O2', 'corner-incumbent-O0',
             'corner-incumbent-O2', 'corner-incumbent-v2-O0', 'corner-incumbent-v2-O2',
             'corner-full1x-O0', 'corner-full4x-O0', 'corner-full1x-O2', 'corner-full4x-O2',
             'corner-restart1x', 'corner-restart4x', 'corner-bbc-O0', 'corner-bbc-O2',
             'corner-oldflux-O0', 'corner-oldflux-O2', 'corner-nut-joint', 'corner-nut-nonjuvenile']
    files, inputs = {}, {}

    def bind(mapping):
        for p, h in mapping.items():
            assert sha((ROOT / p).read_bytes()) == h, ('source drift', p)
            if p in inputs:
                assert inputs[p] == h
            inputs[p] = h

    for opt in ['O0', 'O2']:
        for sub in ['shared', 'column']:
            bind(json.loads((run / ('corner-current-' + opt) / sub / 'build-complete.json').read_text())['input_sha256'])
    bind(json.loads((run / 'corner-small-v3/RESULT.json').read_text())['input_sha256'])
    for name in ['corner-nut-joint', 'corner-nut-nonjuvenile']:
        bind(json.loads((run / name / 'result.json').read_text())['input_sha256'])
    for name in names:
        for p in (run / name).rglob('*'):
            if not p.is_file() or p.suffix in ['.o', '.a', '.mod', '.pyc']:
                continue
            b = p.read_bytes()
            if b.startswith(b'\x7fELF'):
                continue
            files['raw/' + name + '/' + str(p.relative_to(run / name))] = b
    for opt in ['O0', 'O2']:
        generated = Path('/tmp/perf01-historical-corner-current-v2-' + opt)
        for name in ['main.f90', 'mod_fmr_serialized_reference_backend.f90', 'mod_fmr_b111_pond_joint_application.f90', 'RESULT.json']:
            files['generated-base/' + opt + '/' + name] = (generated / name).read_bytes()
    for rain in [1, 4]:
        files['old-prefix/' + str(rain) + 'x/budget.csv'] = (run / ('full' + str(rain) + 'x-cap001-O2') / 'head/budget.csv').read_bytes()
    e = json.loads((ROOT / 'integration/mc-sol01/drainage/CAUCHY3_RECOVERY_QUALIFICATION.json').read_text())['fresh_evidence']
    raw = base64.b64decode((ROOT / e['path']).read_bytes(), validate=True)
    assert sha(raw) == e['sha256']
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        for opt in ['O0', 'O2']:
            for name in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
                files['old-bbc/' + opt + '/' + name] = t.extractfile('native-' + opt + '/full/' + name).read()
                files['old-flux/' + opt + '/' + name] = t.extractfile('oldflux-' + opt + '/' + name).read()
    raw = base64.b64decode((ROOT / 'integration/mc-nut01/competing_sinks/NONJUVENILE_RUNTIME.tar.xz.b64').read_bytes(), validate=True)
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        for opt in ['O0', 'O2']:
            for case in ['crop_nh4', 'crop_both']:
                for suffix in ['', '.ledger']:
                    name = opt + '/' + case + '.endpoint' + suffix
                    files['old-nonjuvenile/' + name] = t.extractfile('current/' + name).read()
    for name in ['probe_perf01_picard_corner.py', 'capture_perf01_corner_fixture.py',
                 'qualify_perf01_picard_corner.py', 'seal_perf01_picard_corner.py',
                 'screen_perf01_geometry.py', 'study_perf01_exchange_guard.py',
                 'study_perf01_segment_refinement.py', 'PERF01_PICARD_CORNER_20261024_CONTRACT.md']:
        files['reproduce/' + name] = (HERE / name).read_bytes()
    result = dict(status='CURRENT_BOUNDED_PICARD_CORNER_SOURCE_PROOF',
                  current_executed_inputs=inputs, wider_research_policy_admitted=False)
    files['RESULT.json'] = (json.dumps(result, indent=2) + '\n').encode()
    files['MANIFEST.json'] = (json.dumps({p: sha(b) for p, b in sorted(files.items())}, indent=2) + '\n').encode()
    target = HERE / 'PERF01_PICARD_CORNER_20261024_EVIDENCE.tar.xz'
    with tarfile.open(target, 'w:xz') as t:
        for p, b in sorted(files.items()):
            m = tarfile.TarInfo(p)
            m.size = len(b)
            t.addfile(m, io.BytesIO(b))
    with tarfile.open(target) as t:
        for p, h in json.load(t.extractfile('MANIFEST.json')).items():
            assert sha(t.extractfile(p).read()) == h
    git = lambda *args: subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()
    delta = {s.split('\t')[1]: s.split('\t')[0] for s in git('diff', '--name-status',
        '367c11e394e3f166f861d9f1502aaeeda01215d7', 'HEAD', '--', 'src', 'app', 'tools', 'tests',
        'examples', 'reference', '.github', 'integration/audits').splitlines()}
    record = dict(baseline='367c11e394e3f166f861d9f1502aaeeda01215d7', candidate=git('rev-parse', 'HEAD'),
                  implemented=True, persisted=True, tested=True, qualified=False, canonically_admitted=False,
                  scientific_delta=delta, postimages={p: sha((ROOT / p).read_bytes()) for p in delta},
                  evidence=dict(path=str(target.relative_to(ROOT)), sha256=sha(target.read_bytes()),
                                bytes=target.stat().st_size, members=len(files)),
                  next_safe_step='Run owning source/evidence/corruption and moving FSI35 gates; reconcile live canonical and verify actual merge',
                  scope='Only same-residual failed near-zero Picard solver restart; no broader endpoint/amount/cap policy admission')
    STATUS.write_text(json.dumps(record, indent=2) + '\n')
    (HERE / 'PERF01_PICARD_CORNER_20261024_RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(record['evidence']))


if __name__ == '__main__':
    main()
