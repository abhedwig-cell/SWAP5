"""Cold current production source; bounded new-owner and real writer qualification."""
import argparse, hashlib, json, subprocess, sys, tarfile
from pathlib import Path
from production_diagnostic_admission import ROOT, SCOPE, current_guard

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir();scope=json.loads((ROOT/SCOPE).read_text());current_guard(scope)
manifest=json.loads((ROOT/'integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())
archive=ROOT/'integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104.tar.xz'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==manifest['archive_sha256']
inputs=out/'inputs';inputs.mkdir()
with tarfile.open(archive)as t:
    assert sorted(t.getnames())==sorted(manifest['files_sha256']);t.extractall(inputs,filter='data')
for opt in ('O0','O2'):
    bundle=out/('build-'+opt)
    subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/build_and_run.py'),
                    '--compiler',str(a.compiler.resolve()),'--optimization',opt,'--output',str(bundle)],cwd=ROOT,check=True)
    subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/production_diagnostic_native.py'),
                    '--bundle',str(bundle),'--compiler',str(a.compiler.resolve()),'--inputs',str(inputs),
                    '--output',str(out/('native-'+opt))],cwd=ROOT,check=True)
current_guard(scope)
print('COLD_CURRENT_S5HR4_O0_O2_PUBLIC_WRITER_OWNER_AND_APP_CONTROLS_PASS')
