"""Verify exact sealed observations; never execute archived native binaries."""
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

from qualify_energy_boundary import inputs, observe

ROOT = Path(__file__).resolve().parents[2]


def verify():
    metadata = json.loads((ROOT/'integration/dataqual15/CONTACT_ENERGY_RESULT_20261102.json').read_text(encoding='utf-8'))
    assert not metadata['full_energy_balance_complete']
    assert not metadata['andelst_repair_implemented']
    assert not metadata['whole_application_qualified']
    archive = ROOT/metadata['archive']
    sha = lambda b: hashlib.sha256(b).hexdigest()
    assert sha(archive.read_bytes()) == metadata['archive_sha256']
    with tarfile.open(archive) as t:
        members = t.getmembers()
        assert len({m.name for m in members}) == len(members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        files = {m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json')) == {n:sha(b) for n,b in files.items()}
    for path, blob in metadata['dependency_git_blob'].items():
        current = subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()
        assert current == blob, ('dependency changed',path)
        assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=ROOT)
    for scope in ('contact','energy'):
        report = json.loads(files[scope+'/RESULT.json'])
        for path, blob in report['source_git_blob'].items():
            assert metadata['dependency_git_blob'][path] == blob
            raw = files['sources/'+path]
            assert sha(raw) == report['source_sha256'][path]
            canonical = raw.replace(b'\r\n',b'\n')
            assert hashlib.sha1(b'blob '+str(len(canonical)).encode()+b'\0'+canonical).hexdigest() == blob
        assert report['O0_O2_stdout_exact']
        assert files[scope+'/O0/stdout'] == files[scope+'/O2/stdout']
        for opt in ('O0','O2'):
            build = report['builds'][opt]
            raw = files[scope+'/'+opt+'/stdout']
            assert sha(raw.replace(b'\r\n',b'\n')) == build['stdout_sha256']
            executable = 'contact.exe' if scope=='contact' else 'driver.exe'
            assert sha(files[scope+'/'+opt+'/'+executable]) == build['executable_sha256']
            if scope=='energy':
                assert not report['full_energy_balance_complete'] and not report['whole_application_qualified']
                observed = observe(raw.decode(),inputs())
                assert all(build[k] == v for k,v in observed.items())
                assert build['raw_storage_domain_rejections'] == 864
                assert build['projected_stock_roundoff_rejections'] == 632
            else:
                assert not report['repair_implemented'] and not report['full_original_complete']
                rows = [list(map(float,l.split(',')[1:])) for l in raw.decode().splitlines() if l.startswith('CONTACT,')]
                assert len(rows) == build['rows'] == 36
                assert {r[0] for r in rows} == {1e-3,1e-8,1e-13}
                assert {r[1] for r in rows} == {1e-4,1e-6,1e-8,1e-10}
                assert {r[2] for r in rows} == {0.,1.,2.}
                assert len({tuple(r[:3]) for r in rows}) == 36
                assert all(.118 < r[3] < .119 and abs(2*r[1]*r[4]-r[3])<1e-14 for r in rows)
    print('SEALED CURRENT-OWNER DIAGNOSTICS VERIFIED; CONTACT REPAIR AND FULL ENERGY OPEN')


if __name__=='__main__':
    verify()
