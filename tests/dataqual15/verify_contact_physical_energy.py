"""Verify sealed research observations, exact sources and independent physical budgets."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

from qualify_contact_physical_energy import ROOT, MACRO, contact_input, check_contact, check_heat

RECORD='integration/dataqual15/CONTACT_PHYSICAL_ENERGY_RESEARCH_20261103.json'
BASE='2924fefaca25fa260147e7c16cd9493c27f57cd7'


def verify():
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    record=json.loads((ROOT/RECORD).read_text(encoding='utf-8'))
    assert record['base']==BASE
    for flag in ('production_changed','nonlinear_contact_repair','full_energy_balance_complete','canonical_admitted'):
        assert record[flag] is False, flag
    changed=subprocess.check_output(['git','diff','--name-only',BASE,'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines()
    # PR1488 independently admitted this input-publication adapter while PR1489
    # was merging. It is outside the research compile closure. Bind its exact
    # two postimages and canonical admission; never ignore the app subtree.
    rain='app/solute_project/prepare_rain_duration.f90'
    if changed:
        assert changed==[rain], 'unreviewed production delta'
        subprocess.run(['git','merge-base','--is-ancestor','d37a9ba2f09e8ea65168b0f87cd6691ad372536f','HEAD'],cwd=ROOT,check=True)
        for ref,blob in ((BASE,'18dc5b61d5f31563cfdd20208e9368c68378743d'),
                         ('HEAD','4de070ccb16a654989322a3cc42b08bf13a89c7f')):
            assert subprocess.check_output(['git','rev-parse',ref+':'+rain],cwd=ROOT,text=True).strip()==blob
    assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT)
    archive=ROOT/record['archive'];assert sha(archive.read_bytes())==record['archive_sha256']
    with tarfile.open(archive) as t:
        members=t.getmembers()
        assert len({m.name for m in members})==len(members)
        assert all(m.isfile() and not PurePosixPath(m.name).is_absolute() and
                   '..' not in PurePosixPath(m.name).parts and '\\' not in m.name for m in members)
        files={m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b) for n,b in files.items()}
    result=json.loads(files['RESULT.json'])
    assert result['status']=='BOUNDED_CONTACT_AND_CONSERVATIVE_HEAT_RESEARCH_PASS'
    assert not result['full_energy_balance_complete'] and not result['nonlinear_contact_repair']
    assert result['measurement_commit']==record['measurement_commit']
    for path,blob in result['source_git_blob'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
        assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=ROOT),path
        raw=files['sources/'+path].replace(b'\r\n',b'\n')
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==blob,path
    raw,rows,jump=contact_input();assert files['contact.dat']==raw
    candidate=files['macro-candidate/'+MACRO].replace(b'\r\n',b'\n')
    assert hashlib.sha1(b'blob '+str(len(candidate)).encode()+b'\0'+candidate).hexdigest()==record['macro_candidate_git_blob']
    for opt in ('O0','O2'):
        build=result['builds'][opt]
        contact=check_contact(files[opt+'/contact.stdout'].decode(),rows,jump)
        assert all(build['contact'][k]==v for k,v in contact.items())
        heat=check_heat(files[opt+'/heat.csv'])
        assert all(build['heat'][k]==v for k,v in heat.items())
        for name in ('contact','heat'):
            assert sha(files[opt+'/'+name+'.exe'])==build[name]['executable_sha256']
        for refusal in ('fraction_above_one','negative_fraction'):
            assert b'no bounded contact witness' in files[opt+'/'+refusal+'.stderr']
            assert b'CONTACT,' not in files[opt+'/'+refusal+'.stdout']
            assert refusal in build['contact']['bounded_fraction_refusals']
        transfer=contact['exchange_amount_cm']
        for variant in ('production','candidate'):
            folder=opt+'/macro-'+variant+'/'
            values=list(map(float,files[folder+'stdout'].decode().strip().split(',')[1:]))
            entry=build['macro_exchange'][variant]
            assert values==[entry[k] for k in ('transfer_cm','stock_before_view_cm','stock_after_view_cm',
                                              'combined_matrix_macro_water_residual_cm')]
            assert values[0]==transfer and abs(values[1]-(.1-transfer))<1e-18
            assert abs(values[3]-(values[2]-.1+transfer))<1e-30
            if variant=='production':assert values[2]==.1 and values[3]>transfer/2
            else:assert values[2]==values[1] and abs(values[3])<64*2.220446049250313e-16*.1
            assert sha(files[folder+'exchange.exe'])==entry['executable_sha256']
        for path in ('contact.stdout','heat.csv','macro-production/stdout','macro-candidate/stdout'):
            assert files[opt+'/'+path]==files['O0/'+path]
    print('SEALED O0/O2 CONTACT, MACRO CONSERVATION CONTROL AND WARM SENSIBLE BUDGET PASS; NONLINEAR AND FULL ENERGY OPEN')


if __name__=='__main__':verify()
