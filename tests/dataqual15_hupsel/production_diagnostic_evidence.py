"""Actual public writer/owner evidence for the single registered app postimage."""
import hashlib, json, struct, tarfile, tempfile, zlib
from pathlib import Path, PurePosixPath, PureWindowsPath

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def audit(root,scope):
    for opt in ('O0','O2'):
        leg=root/opt
        b=json.loads((leg/'writer-build/BUILD.json').read_text())
        assert b['current_app_source_sha256']==scope['compiled_app_postimage_sha256']
        assert sha(leg/'writer-build/writer-probe.exe')==b['executable_sha256']
        assert sha(leg/'writer-build/main_writer_probe.f90')==b['instrumented_main_sha256']
        from production_diagnostic_native import instrument
        assert b['instrumented_main_sha256']==hashlib.sha256(instrument((ROOT/'app/solute_project/main.f90').read_text()).encode()).hexdigest()
        ordinary=leg/'ordinary-bundle';build=json.loads((ordinary/'BUILD.json').read_text())
        assert sha(ordinary/'swap5_hupsel_germination.exe')==build['executable_sha256']
        r=json.loads((leg/'publication/RESULT.json').read_text())
        assert r['status']=='CURRENT_S5HR4_TWO_DAY_OWN_RESTART_AND_SIX_PUBLIC_WRITER_REFUSALS_PASS'
        assert r['executable_sha256']==build['executable_sha256'] and r['probe_executable_sha256']==b['executable_sha256']
        assert r['finite_writer_refusals']==6 and r['each_failed_write_preserves_prior_target_bytes'] and r['strict_restart_exact']
        assert len(r['events'])==4 and all(e['returncode']==0 for e in r['events'])
        cases=[leg/'publication'/n for n in ('continuous2','restart2','writer2')]
        endpoints=[(p/'checkpoint.bin').read_bytes()for p in cases]
        assert endpoints[0]==endpoints[1]==endpoints[2]
        for raw in endpoints:
            assert raw[:8]==b'S5HR0004' and struct.unpack_from('=d',raw,8)[0]==2
            assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
        assert (cases[0]/'budget.csv').read_bytes()==(cases[2]/'budget.csv').read_bytes()
        assert (cases[0]/'crop.csv').read_bytes()==(cases[2]/'crop.csv').read_bytes()
        assert [' '.join(line.split())for line in (cases[2]/'writer_probe.dat').read_text().splitlines()]==[
            '1 1 1','1 2 1','1 3 1','2 1 1','2 2 1','2 3 1']
        guards=json.loads((leg/'nested-mature/S5HR4_RESULT.json').read_text())
        assert guards['schema']=='S5HR0004' and guards['legacy_schema_coercion'] is False
        assert guards['clock']==525 and guards['executable_sha256']==build['executable_sha256']
        assert len(guards['events'])==37 and all(e['status']=='PASS' and e['returncode']==1 for e in guards['events'])
        for e in guards['events']:
            folder=leg/'nested-mature'/e['case']
            output=(folder/'stdout').read_bytes()+(folder/'stderr').read_bytes()
            assert (b'no requested windows remain'in output)==(e['case']=='valid_nonadvancing')
            assert not any((folder/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin','restart.bin'))
        app=json.loads((leg/'app-refusals/RESULT.json').read_text())
        assert len(app['events'])==11 and all(e['returncode']==1 for e in app['events'])
        assert 'legacy3'in[e['case']for e in app['events']]
        for e in app['events']:
            folder=leg/'app-refusals'/e['case']
            assert b'source rotation envelope rejected before publication'in(folder/'stdout').read_bytes()
            assert not any((folder/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin'))
    return dict(status='ACTUAL_CURRENT_APP_PUBLICATION_OWN_RESTART_74_OWNER_CONTROLS_12_WRITER_22_APP_REFUSALS_PASS',
                optimizations=['O0','O2'],owner_controls=74,nonfinite_writer_refusals=12,app_refusals=22,
                whole_scientific_admission=False)


def verify(scope):
    manifest=json.loads((BASE/'PRODUCTION_DIAGNOSTIC_WINDOWS_20261104.json').read_text())
    archive=BASE/'PRODUCTION_DIAGNOSTIC_WINDOWS_20261104.tar.xz';assert sha(archive)==manifest['archive_sha256']
    assert manifest['app_postimage_sha256']==scope['compiled_app_postimage_sha256']
    # Tie the adopted source to the previous actual full default runtime,
    # independently of this new boundary dossier's declarations.
    parent=json.loads((BASE/'DEFAULT_DIAGNOSTIC_EVIDENCE_20261104.json').read_text())
    old=BASE/'DEFAULT_DIAGNOSTIC_EVIDENCE_20261104.tar.xz';assert sha(old)==parent['archive_sha256']
    with tarfile.open(old)as t:
        for opt in ('O0','O2'):
            raw=t.extractfile(opt+'/hupsel_rotation_restart.f90').read()
            assert hashlib.sha256(raw).hexdigest()==scope['compiled_app_postimage_sha256']
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp)
        with tarfile.open(archive)as t:
            members=t.getmembers();assert len({m.name for m in members})==len(members)
            assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive
                       and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
            assert sorted(t.getnames())==sorted(manifest['files_sha256'])
            t.extractall(root,filter='data')
        for name,pin in manifest['files_sha256'].items():assert sha(root/name)==pin
        return audit(root,scope)


if __name__=='__main__':
    scope=json.loads((BASE/'PRODUCTION_DIAGNOSTIC_SCOPE_20261104.json').read_text())
    print(verify(scope)['status'])
