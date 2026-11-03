"""Source-bound actual thermal observations; never a full physical-energy PASS."""
import hashlib
import json
from pathlib import Path,PurePosixPath,PureWindowsPath
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
RECORD='integration/dataqual15/THERMAL_ACCEPTED_RECEIPTS_20261103.json'


def verify():
    sha=lambda b:hashlib.sha256(b).hexdigest()
    record=json.loads((ROOT/RECORD).read_text(encoding='utf-8'))
    assert record['baseline']=='538fb025e8702d4dd609bc30cc347743a0587145'
    assert record['status']=='ACTUAL_THERMAL_RECEIPTS_O0_O2_AND_EXISTING_EB_RUNTIME_PASS'
    assert record['full_energy_balance_complete'] is False
    assert set(record['production_delta'])=={
        'src/runtime/mod_fmr_thermal_substep_receipt.f90',
        'src/runtime/mod_fmr_water_flux_trace_contract.f90',
        'src/runtime/mod_fmr_serialized_reference_backend.f90'}
    assert set(record.get('independent_adapters',{}))<= {'app/solute_project/inspect_historical.f90'}
    allowed=set(record['production_delta'])
    for path,adapter in record.get('independent_adapters',{}).items():
        assert (adapter['before'],adapter['after'],adapter['admitted_merge'])==(
            '0855b4014e18b32475d1d4a18c18d477413c0b7c','85933351e9a2bb1e3830485a0e3eb345a4369141',
            'cbb4352702f576a244431655a2f89cfc02875709')
        subprocess.run(['git','merge-base','--is-ancestor',adapter['admitted_merge'],'HEAD'],cwd=ROOT,check=True)
        for ref,pin in ((record['baseline'],adapter['before']),('HEAD',adapter['after'])):
            assert subprocess.check_output(['git','rev-parse',ref+':'+path],cwd=ROOT,text=True).strip()==pin,path
        allowed.add(path)
    assert set(subprocess.check_output(['git','diff','--name-only',record['baseline'],'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines())==allowed
    for path,pins in record['production_delta'].items():
        old=subprocess.run(['git','rev-parse',record['baseline']+':'+path],cwd=ROOT,capture_output=True,text=True)
        assert (old.stdout.strip() if old.returncode==0 else None)==pins['before'],path
    archive=ROOT/record['archive'];assert sha(archive.read_bytes())==record['archive_sha256']
    with tarfile.open(archive) as t:
        members=t.getmembers();assert len({m.name for m in members})==len(members)
        assert all(m.isfile() and not PurePosixPath(m.name).is_absolute() and not PureWindowsPath(m.name).drive
                   and '..' not in PurePosixPath(m.name).parts and '\\' not in m.name for m in members)
        files={m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b) for n,b in files.items()}
    r=json.loads(files['RESULT.json']);assert r['status']==record['status']
    assert not r['full_energy_balance_complete'] and r['measurement_commit']==record['measurement_commit']
    for path,blob in r['source_git_blob'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
        raw=files['sources/'+path].replace(b'\r\n',b'\n')
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==blob,path
    assert not subprocess.check_output(['git','diff','HEAD','--',*r['source_git_blob']],cwd=ROOT)
    assert sha(files['runtime.f90'])==r['generated_driver_sha256']
    for path,pins in record['production_delta'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==pins['after'],path
    dz=[50.,50.,100.,100.]
    for opt in ('O0','O2'):
        assert b'THERMAL_RECEIPT_COMPONENT_PASS' in files[opt+'/component.stdout']
        for i,e in r['builds'][opt]['tests'].items():
            assert sha(files[opt+'/test'+i+'.exe'])==e['executable_sha256']
            assert sha(files[opt+'/test-'+i+'.stdout'])==e['stdout_sha256']
            assert b'PASS' in files[opt+'/test-'+i+'.stdout']
        assert b'ACCEPTED_THERMAL_RECEIPTS_SINGLE_TWO_HALF_REJECTION_OFF_ON_PASS_FULL_ENERGY_OPEN' in files[opt+'/test-3.stdout']
        rows=[l.split(',') for l in files[opt+'/receipts.csv'].decode().splitlines()]
        accepted=[row for row in rows if row[0]=='ACCEPTED'];nodes=[row for row in rows if row[0]=='NODE']
        assert [int(row[1]) for row in accepted]==[1,2] and len(nodes)==12
        for row in nodes:
            mode,interval,node=map(int,row[1:4]);a,b,w0,w1,stored,flux=map(float,row[4:])
            theta=.5*(w0+w1)
            capacity=(.4*2660*800+.4*2650*900+.1*1300*1920+theta*1000*4180+max(0.,.423-theta)*1.2*1010)*1e-6
            independent=dz[node-1]*capacity*(b-a)
            assert abs(independent-stored)<1e-16
            assert abs(independent-flux)<1e-10
        assert files[opt+'/receipts.csv']==files['O0/receipts.csv']
    print('SOURCE-BOUND THERMAL SINGLE/TWO-HALF/REJECTION/OFF-ON AND EXISTING EB RUNTIME PASS; ORIGINAL INPUT AND FULL ENERGY NOT QUALIFIED')
    return record


if __name__=='__main__':verify()
