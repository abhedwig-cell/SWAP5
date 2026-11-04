"""Cold coherent POSIX builds in a disposable detached research worktree."""
import argparse, hashlib, json, shutil, subprocess, sys, tarfile
from pathlib import Path
from pressure_diagnostic_candidate import ROOT, REL, candidate
from micro_pressure_probe import OLD, NEW, PROCESS
from qualify_pressure_diagnostic_candidate import qualify

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--compiler', type=Path, required=True)
a = p.parse_args(); out = a.output.resolve(); out.mkdir()
checkout = out/'research-checkout'
subprocess.run(['git', 'worktree', 'add', '--detach', str(checkout), 'HEAD'], cwd=ROOT, check=True)
original = (checkout/REL).read_text()
(checkout/REL).write_text(candidate(original))
source = (checkout/PROCESS).read_text(); assert source.count(OLD) == 1
(checkout/PROCESS).write_text(source.replace(OLD, NEW))
manifest = json.loads((ROOT/'integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())
archive = ROOT/'integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104.tar.xz'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == manifest['archive_sha256']
inputs = out/'inputs'; inputs.mkdir()
with tarfile.open(archive) as tar:
    assert sorted(tar.getnames()) == sorted(manifest['files_sha256'])
    tar.extractall(inputs, filter='data')
for name, digest in manifest['files_sha256'].items():
    assert hashlib.sha256((inputs/name).read_bytes()).hexdigest() == digest
for opt in ('O0', 'O2'):
    bundle = out/('build-'+opt)
    subprocess.run([sys.executable, '-B', str(checkout/'tests/dataqual15_hupsel/build_and_run.py'),
                    '--compiler', str(a.compiler.resolve()), '--optimization', opt, '--output', str(bundle)],
                   cwd=checkout, check=True)
    record = json.loads((bundle/'BUILD.json').read_text())
    for name, digest in record['source_sha256'].items():
        assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest
    qualify(bundle/'swap5_hupsel_germination', inputs, out/('measurement-'+opt))
print('COLD_POSIX_O0_O2_COPIED_APP_DIAGNOSTIC_PASS')
