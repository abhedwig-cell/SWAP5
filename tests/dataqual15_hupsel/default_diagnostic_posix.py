"""Cold default-runtime builds; no research numerical source or checkpoint."""
import argparse, hashlib, json, subprocess, sys, tarfile
from pathlib import Path
from pressure_diagnostic_candidate import ROOT, REL, candidate
from qualify_pressure_diagnostic_candidate import qualify
from default_diagnostic_candidate import check_refusals

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True); p.add_argument('--compiler', type=Path, required=True)
a = p.parse_args(); out = a.output.resolve(); out.mkdir(); checkout = out/'default-checkout'
subprocess.run(['git', 'worktree', 'add', '--detach', str(checkout), 'HEAD'], cwd=ROOT, check=True)
path = checkout/REL; path.write_text(candidate(path.read_text()))
manifest = json.loads((ROOT/'integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())
archive = ROOT/'integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104.tar.xz'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == manifest['archive_sha256']
inputs = out/'inputs'; inputs.mkdir()
with tarfile.open(archive) as tar:
    assert sorted(tar.getnames()) == sorted(manifest['files_sha256'])
    tar.extractall(inputs, filter='data')
for opt in ('O0', 'O2'):
    bundle = out/('build-'+opt)
    subprocess.run([sys.executable, '-B', str(checkout/'tests/dataqual15_hupsel/build_and_run.py'),
                    '--compiler', str(a.compiler.resolve()), '--optimization', opt, '--output', str(bundle)],
                   cwd=checkout, check=True)
    r = json.loads((bundle/'BUILD.json').read_text())
    assert len(r['source_sha256']) == 236
    for name, digest in r['source_sha256'].items():
        assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest
    # The sole changed production path is the app-owned envelope.
    changed = subprocess.check_output(['git', 'diff', '--name-only', '--', 'src', 'app', 'reference'], cwd=checkout, text=True).splitlines()
    assert changed == [REL], changed
    qualify(bundle/'swap5_hupsel_germination', inputs, out/('measurement-'+opt))
    check_refusals(out/('measurement-'+opt))
print('COLD_DEFAULT_RUNTIME_O0_O2_DIAGNOSTIC_PASS')
