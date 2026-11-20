"""Run only missing Ubuntu controls/CDE; retain original successful water bytes."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import time
import urllib.request
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ARTIFACTS = {
    'O0': (14661250798, 11853844, '7b8e0631a29e9d53d3ceb7b6dddf409ecbd209c6f4423b872897fc91bba3bb64'),
    'O2': (14659689431, 11788974, 'c28ea2d301858edfadb3138282ecc574a0ed035c5051f733d0e1fca9564befb0'),
}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'scratch', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args(); a.output.mkdir(); a.build_root.mkdir()
    proof = a.output.parent
    artifact, size, digest = ARTIFACTS[a.optimization]
    request = urllib.request.Request(f'https://api.github.com/repos/abhedwig-cell/SWAP5/actions/artifacts/{artifact}/zip',
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json'})
    raw = urllib.request.urlopen(request, timeout=90).read()
    assert len(raw) == size and hashlib.sha256(raw).hexdigest() == digest
    retained = a.output / 'RETAINED_ORIGINAL_ARTIFACT_V1.json'
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        original_run=44799554543, original_source='5534a17df5ecc382cd4b8415c5bbd7d3954a0ea6',
        original_artifact=artifact, original_bytes=size, original_sha256=digest,
        optimization=a.optimization, steps=[], water_model_periods_replayed=0, canonical_admission=False)
    retained.write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        # Bind unchanged complete production source to the original successful
        # water producer before restoring executable/native evidence. Only the
        # control harness and campaign selection changed.
        cap = archive.read('source/actual-producer-source.zip')
        with zipfile.ZipFile(io.BytesIO(cap)) as source:
            production = [name for name in source.namelist() if name.startswith(('app/', 'src/'))]
            assert production
            for name in production:
                assert (ROOT / name).read_bytes().replace(b'\r\n', b'\n') == source.read(name).replace(b'\r\n', b'\n'), name
        for item in archive.infolist():
            path = PurePosixPath(item.filename)
            assert not path.is_absolute() and '..' not in path.parts and (item.external_attr >> 16) & 0o170000 != 0o120000
            if item.is_dir(): continue
            if item.filename.startswith('frost-cde-drainage/'):
                target = proof / Path(*path.parts)
            elif item.filename.startswith('compiled/builds/'):
                target = a.build_root / Path(*path.parts[2:])
            else: continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream: stream.write(archive.read(item))
            if target.name in ('day_donor', 'day_kernel'): target.chmod(0o755)
    old = proof / 'frost-cde-drainage'
    for name in ('overlap', 'rates', 'cde', 'water-short', 'water-full'):
        record = json.loads((old / name / 'RESULT.json').read_text())
        assert 'PASS' in record['status'] and record['source'] == q['original_source'], name
    logs = a.output / 'commands'; logs.mkdir()
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    def run(label, script, arguments, cap):
        command = [sys.executable, '-B', str(HERE / script), *map(str, arguments)]
        step = dict(label=label, command=command, status='RUNNING'); q['steps'].append(step); save()
        start = time.perf_counter()
        try:
            with (logs / (label + '.stdout')).open('x') as out, (logs / (label + '.stderr')).open('x') as err:
                result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=cap)
            step['returncode'] = result.returncode; result.check_returncode(); step['status'] = 'PASS'
        except Exception as error:
            step.update(status='FAILED_OR_CENSORED', error=repr(error)); raise
        finally: step['seconds'] = time.perf_counter()-start; save()
    common = ['--reference-work', a.reference_work]
    save()
    try:
        for phase in ('short', 'full'):
            run('retained-water-' + phase + '-independent', 'frost_cde_drainage_model_forensics.py',
                [*common, '--profile', old / ('water-' + phase), '--output', a.output / ('water-' + phase + '-INDEPENDENT_V1.json')], 60)
        run('retained-water-controls', 'frost_cde_drainage_controls.py', [*common, '--profile', old / 'water-short',
            '--scratch', a.scratch / 'water', '--output', a.output / 'water-controls'], 300)
        build = a.build_root / 'cde'; short = a.output / 'cde-short'; full = a.output / 'cde-full'
        run('missing-cde-short', 'frost_cde_drainage_runtime.py', [*common, '--kind', 'cde', '--optimization', a.optimization,
            '--build-root', build, '--output', short], 300)
        run('missing-cde-full', 'frost_cde_drainage_runtime.py', [*common, '--kind', 'cde', '--optimization', a.optimization,
            '--build-root', build, '--reuse-build', build / 'bundle', '--existing-input', short / 'input',
            '--phase', 'full', '--output', full], 300)
        for phase, profile in [('short', short), ('full', full)]:
            run('cde-' + phase + '-independent', 'frost_cde_drainage_model_forensics.py',
                [*common, '--profile', profile, '--output', a.output / ('cde-' + phase + '-INDEPENDENT_V1.json')], 60)
        run('missing-cde-controls', 'frost_cde_drainage_controls.py', [*common, '--profile', short,
            '--scratch', a.scratch / 'cde', '--output', a.output / 'cde-controls'], 300)
        q['status'] = 'ACTUAL_PORTABLE_RETAINED_FROST_WATER_AND_MISSING_CDE_CONTROLS_PASS_NOT_ADMITTED'
        print(q['status'], flush=True)
    except Exception as error:
        q.update(status='FAILED_OR_CENSORED', error=repr(error)); raise
    finally: save()


if __name__ == '__main__': main()
