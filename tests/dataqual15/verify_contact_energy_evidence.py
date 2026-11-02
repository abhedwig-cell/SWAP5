"""Verify exact sealed observations; never execute archived native binaries."""
import argparse
import hashlib
import difflib
import json
from pathlib import Path
import subprocess
import tarfile

from qualify_energy_boundary import inputs, observe

ROOT = Path(__file__).resolve().parents[2]


def verify(historical=False):
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
        # Immutable historical observations do not qualify changed current sources.
        # Require the original Git object in either mode; current-source identity
        # remains a separate explicitly selectable stronger claim.
        subprocess.run(['git','cat-file','-e',blob+'^{blob}'],cwd=ROOT,check=True)
        if not historical:
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
    verify_stock_candidate(files,historical)
    if historical:
        print('HISTORICAL_EVIDENCE_ONLY; CURRENT_SOURCE_QUALIFICATION_NOT_INHERITED')
    label='PREDECESSOR' if historical else 'CURRENT-OWNER'
    print('SEALED '+label+' DIAGNOSTICS AND ISOLATED STOCK CANDIDATE VERIFIED; CONTACT REPAIR AND FULL ENERGY OPEN')


def verify_stock_candidate(original_files,historical=False):
    report = json.loads((ROOT/'integration/dataqual15/STOCK_PROJECTION_CANDIDATE_RESULT_20261102.json').read_text(encoding='utf-8'))
    assert not report['production_modified'] and not report['production_admitted']
    assert not report['full_energy_balance_complete']
    sha = lambda raw:hashlib.sha256(raw).hexdigest()
    archive = ROOT/report['archive']
    assert sha(archive.read_bytes()) == report['archive_sha256']
    with tarfile.open(archive) as t:
        members=t.getmembers()
        assert len({m.name for m in members})==len(members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        files={m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json'))=={n:sha(raw) for n,raw in files.items()}
    archived_report=json.loads(files['RESULT.json'])
    assert all(report[k]==v for k,v in archived_report.items())
    for path,blob in report['experiment_git_blob'].items():
        subprocess.run(['git','cat-file','-e',blob+'^{blob}'],cwd=ROOT,check=True)
        if not historical:
            assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob
            assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=ROOT)
    module='src/process/mod_whole_column_sensible_energy_accounting.f90'
    if not historical:
        assert subprocess.check_output(['git','rev-parse','HEAD:'+module],cwd=ROOT,text=True).strip()==report['original_module_git_blob']
    original=original_files['sources/'+module].decode().replace('\r\n','\n')
    candidate=files['candidate/'+module].decode().replace('\r\n','\n')
    patch=''.join(difflib.unified_diff(original.splitlines(True),candidate.splitlines(True),fromfile='a/'+module,tofile='b/'+module))
    assert patch==files['candidate.patch'].decode().replace('\r\n','\n')
    assert patch==(ROOT/'integration/dataqual15/STOCK_PROJECTION_NUMERICAL_CANDIDATE.patch').read_text(encoding='utf-8')
    assert sha(files['candidate/'+module])==report['patched_source_sha256']
    injection='    roundoff_factor = (4.0_real64'
    expected_fault=candidate.replace(injection,'    result%exact_storage_change_j_m2 = result%exact_storage_change_j_m2 + 1.0_real64\n'+injection)
    assert files['faulty_stock.f90'].decode().replace('\r\n','\n')==expected_fault
    for variant in ('candidate','fault'):
        assert files['O0-'+variant+'/stdout']==files['O2-'+variant+'/stdout']
        for opt in ('O0','O2'):
            key=opt+'-'+variant
            build=report['builds'][key]
            raw=files[key+'/stdout']
            assert sha(raw.replace(b'\r\n',b'\n'))==build['stdout_sha256']
            assert sha(files[key+'/driver.exe'])==build['executable_sha256']
            measured=observe(raw.decode(),inputs())
            assert all(build[k]==v for k,v in measured.items())
            assert measured['raw_storage_domain_rejections']==864
            assert measured['projected_stock_roundoff_rejections']==(0 if variant=='candidate' else 864)
            assert measured['counterfactual_max_residual_j_cm2']['kind1_gauge0']>1.45


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--historical',action='store_true',help='Verify immutable predecessor observations without claiming current source equivalence')
    verify(parser.parse_args().historical)
