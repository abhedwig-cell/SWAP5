"""Independent literal native provider inverse, real raw roundtrips and refusals."""
import hashlib
import itertools
import json
import struct
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
PARENT='617c85df35a799ad400278d59d51f89941c9d6ef4f57193c7f124c40817ea0e2'


def audit(read,prefix,opt,prepared):
    q=json.loads(read(prefix+'/RESULT.json'))
    assert q['status']=='ACTUAL_TWO_RATE_FROST_NATIVE_PROVIDER_ROUNDTRIPS_AND_14_REFUSALS_PASS_NOT_ADMITTED'
    assert q['optimization']==opt and q['parent_provider_sha256']==PARENT
    assert all(item['returncode']==0 for item in q['compiler'])
    driver=read(prefix+'/implicit_frost_root_driver.f90')
    assert SHA(driver)==q['driver_sha256']
    original=subprocess.check_output(['git','show',q['source']+':tests/nomacro_drainage/implicit_frost_root_driver.f90'],cwd=ROOT)
    assert driver.replace(b'\r\n',b'\n')==original
    for kind in (0,1):
        text=read(prefix+'/root-kind'+str(kind)+'.f90').decode('cp1252').replace('\r\n','\n')
        inverse=[('hybrid_implicit_frost_root_state','hybrid_implicit_snow_root_state'),
          ('implicit_frost_root_checkpoint','implicit_snow_root_checkpoint'),
          ('use MOD_swap_base, only: swsolu,swsnow,swhyst,swfrost,swdra','use MOD_swap_base, only: swsolu,swsnow,swhyst'),
          ('(swbotb/=6.or.swfrost/=1.or.swdra/=1.or.swhyst/=2)','(swbotb/=5.and.swbotb/=8)'),
          ('expected=[4,numnod','expected=[1,numnod'),('HYBRID_FROST_ROOT_NATIVE','HYBRID_SNOW_ROOT_NATIVE')]
        if kind:inverse.append(('swsolu/=1','swsolu/=0'))
        for before,after in inverse:assert before in text;text=text.replace(before,after)
        assert SHA(text.encode('cp1252'))==PARENT
        objects=q['actual_object_closures'][str(kind)];assert len(objects)==40
        for item in objects:assert item['sha256']==prepared['provider_files']['build/swap-obj/'+item['name']]
    expected=set(itertools.product((0,1),('roundtrip','header','witness','value-witness','nonfinite','truncated','bad-frost','bad-bottom')))
    assert len(q['native'])==16 and {(item['kind'],item['attack']) for item in q['native']}==expected
    for item in q['native']:
        raw=read(prefix+'/'+str(item['kind'])+'-'+item['attack']+'/root-native.bin')
        assert len(raw)==item['bytes'] and SHA(raw)==item['input_sha256']
        if item['attack']=='roundtrip':
            assert item['returncode']==0 and not item['stderr'] and item['status']=='ROUNDTRIP_PASS'
            assert raw==struct.pack('<16i4d',*([4,3,item['kind'],1,2,6,1,0]*2),.25,.875,.25,.875)
            assert 'ACTUAL_FROST_ROOT_NATIVE_ROUNDTRIP_PASS' in item['stdout']
        else:
            assert item['returncode']!=0 and item['status']=='REFUSED'
            assert 'ERROR STOP' in item['stderr'] and 'implicit Snow root diagnostic' in item['stderr']
            assert 'Invalid native input accepted by actual provider' not in item['stderr']
    return dict(status='INDEPENDENT_COMPLETE_LITERAL_ROOT_PROVIDER_NATIVE_ROUNDTRIPS_REFUSALS_PASS',
        optimization=opt,producer=q['source'],parent_provider_sha256=PARENT,whole_provider_inverse=True,
        roundtrips=2,compiled_refusals=14,model_executions=0,compiler_executions=0,canonical_admission=False)
