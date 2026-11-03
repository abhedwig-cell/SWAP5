"""Exact numerical successor plus current EB runtime evidence; no broad energy claim."""
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

from verify_stock_projection_production import verify as verify_stock

ROOT=Path(__file__).resolve().parents[2]
BASE='7a7f994d8b7fd0327f761a0db791726ab7a98e75'
MODULE='src/process/mod_whole_column_sensible_energy_accounting.f90'


def verify():
    verify_stock()
    changed=subprocess.check_output(['git','diff','--name-only',BASE,'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines()
    # Separately qualified original-input adapter; no energy/runtime dependency.
    # Bind both postimages exactly rather than ignoring the application subtree.
    rain='app/solute_project/prepare_rain_duration.f90'
    allowed={MODULE}
    if rain in changed:
        for ref,pin in ((BASE,'18dc5b61d5f31563cfdd20208e9368c68378743d'),
                        ('HEAD','4de070ccb16a654989322a3cc42b08bf13a89c7f')):
            assert subprocess.check_output(['git','rev-parse',ref+':'+rain],cwd=ROOT,text=True).strip()==pin, rain
        allowed.add(rain)
    inspect='app/solute_project/inspect_historical.f90'
    if inspect in changed:
        for ref,pin in ((BASE,'0855b4014e18b32475d1d4a18c18d477413c0b7c'),
                        ('HEAD','85933351e9a2bb1e3830485a0e3eb345a4369141')):
            assert subprocess.check_output(['git','rev-parse',ref+':'+inspect],cwd=ROOT,text=True).strip()==pin, inspect
        allowed.add(inspect)
    assert set(changed)==allowed, 'unreviewed physical production delta'
    assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT)
    assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
    record=json.loads((ROOT/'integration/dataqual15/STOCK_RUNTIME_PRODUCTION_20261103.json').read_text(encoding='utf-8'))
    assert record['base']==BASE and not record['full_energy_balance_complete']
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    path=ROOT/record['archive'];assert sha(path.read_bytes())==record['archive_sha256']
    with tarfile.open(path) as t:
        members=t.getmembers()
        assert len({m.name for m in members})==len(members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        files={m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b) for n,b in files.items()}
    report=json.loads(files['RESULT.json'])
    assert report['status']=='CURRENT_EB_I23_I24_I25_RUNTIME_O0_O2_PASS'
    assert not report['full_energy_balance_complete']
    for path,blob in report['source_git_blob'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
        assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=ROOT),path
        raw=files['sources/'+path]
        assert sha(raw)==report['source_sha256'][path],path
        raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==blob,path
    for path,blob in record['inherited_assets'].items():
        assert subprocess.check_output(['git','rev-parse',BASE+':'+path],cwd=ROOT,text=True).strip()==blob,path
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
    for path,blob in record['revised_assets'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
        raw=files['sources/'+path].replace(b'\r\n',b'\n')
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==blob,path
    contract=files['sources/tests/eb/EB-I25_CONTRACT.md'].decode()
    assert 'does not qualify accepted external-full/half top liquid outflow sensible transport' in contract
    markers=['EB_I23_ACCEPTED_SINGLE_SUBSTEP_PARTIAL_MATERIALIZATION=PASS',
             'EB_I24_ACCEPTED_INFLOW_COMPLETE_I22_BOUNDARY=PASS',
             'EB_I25_ACCEPTED_OUTFLOW_NO_ADVECTIVE_AUTHORITY=PASS']
    for opt in ('O0','O2'):
        build=report['builds'][opt]
        assert len(build['events'])==report['provider_count']
        for i,(test,entry) in enumerate(build['tests'].items()):
            raw=files[opt+'/'+str(i)+'.stdout'].decode().replace('\r\n','\n')
            assert raw==entry['stdout'] and sha(raw.encode())==entry['stdout_sha256']
            assert markers[i] in raw
            assert sha(files[opt+'/'+str(i)+'.exe'])==entry['executable_sha256']
            assert entry['stdout']==report['builds']['O0']['tests'][test]['stdout']
    print('CURRENT STOCK OWNER AND EB-I23/I24/I25 RUNTIME PRESERVED; OUTFLOW ENERGY UNAVAILABLE; FULL ENERGY OPEN')


if __name__=='__main__':verify()
