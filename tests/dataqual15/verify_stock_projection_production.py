"""Current-source proof of the numerical comparison owner; not full energy admission."""
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

from qualify_energy_boundary import inputs, observe

ROOT=Path(__file__).resolve().parents[2]


def verify():
    record=json.loads((ROOT/'integration/dataqual15/STOCK_PROJECTION_PRODUCTION_20261102.json').read_text(encoding='utf-8'))
    assert record['scope']=='NUMERICAL_STOCK_REPRESENTATION_ONLY'
    assert not record['full_energy_balance_complete']
    sha=lambda b:hashlib.sha256(b).hexdigest()
    path=ROOT/record['archive']
    assert sha(path.read_bytes())==record['archive_sha256']
    with tarfile.open(path) as t:
        members=t.getmembers()
        assert len({m.name for m in members})==len(members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        files={m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b) for n,b in files.items()}
    report=json.loads(files['RESULT.json'])
    assert report['status']=='PRODUCTION_STOCK_COMPARISON_PASS_PHYSICAL_ENERGY_OPEN'
    assert not report['full_energy_balance_complete']
    assert report['missing_boundary_still_rejected'] and report['raw_theta_domain_still_rejected']
    for path,blob in record['source_git_blob'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
        assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=ROOT),path
        raw=files['sources/'+path].replace(b'\r\n',b'\n')
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==blob,path
    assert all(record['source_git_blob'][p]==b for p,b in report['source_git_blob'].items())
    prior=json.loads((ROOT/'integration/dataqual15/STOCK_PROJECTION_CANDIDATE_RESULT_20261102.json').read_text(encoding='utf-8'))
    for opt in ('O0','O2'):
        build=report['current']['builds'][opt]
        raw=files['current/'+opt+'/stdout']
        assert sha(raw.replace(b'\r\n',b'\n'))==build['stdout_sha256']==prior['builds'][opt+'-candidate']['stdout_sha256']
        assert sha(files['current/'+opt+'/driver.exe'])==build['executable_sha256']
        observed=observe(raw.decode(),inputs())
        assert all(build[k]==v for k,v in observed.items())
        assert observed['projected_stock_roundoff_rejections']==0
        assert observed['raw_storage_domain_rejections']==observed['missing_boundary_rejections']==864
        assert observed['counterfactual_max_residual_j_cm2']['kind1_gauge0']>1.45
        fault=report['fault'][opt]
        raw=files['fault-'+opt+'/stdout']
        assert sha(raw.replace(b'\r\n',b'\n'))==fault['stdout_sha256']==prior['builds'][opt+'-fault']['stdout_sha256']
        observed=observe(raw.decode(),inputs())
        assert all(fault[k]==v for k,v in observed.items())
        assert observed['projected_stock_roundoff_rejections']==864
        assert sha(files['fault-'+opt+'/driver.exe'])==fault['executable_sha256']
    for test,entry in report['contracts'].items():
        assert files[test+'/stdout'].decode().replace('\r\n','\n')==entry['stdout']
        assert 'PASS' in entry['stdout']
        assert all(record['source_git_blob'][p]==b for p,b in entry['source_git_blob'].items())
    assert files['current/O0/stdout']==files['current/O2/stdout']
    assert files['fault-O0/stdout']==files['fault-O2/stdout']
    print('CURRENT PRODUCTION STOCK REPRESENTATION VERIFIED; MISSING TERMS REJECTED; FULL ENERGY OPEN')


if __name__=='__main__':
    verify()
