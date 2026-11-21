"""Read actual Windows full vapor trajectories and immutable cold continuations."""
import argparse
from contextlib import ExitStack
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile
from analytical_hydraulic_archives import Archive,SHA
from vapor_cold_continuation import Profile
from vapor_hydraulic_forensics import audit
from vapor_hydraulic_portable import CASES
from vapor_ubuntu_science import controls,INITIAL,RUNTIME

ROOT=Path(__file__).resolve().parents[2]


def source_epoch(source):
    changed=subprocess.check_output(['git','diff','--name-only',RUNTIME,source,'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT,text=True).splitlines()
    if changed:
        assert changed==['app/hybrid_water/cde_native_receipt.py']
        assert not subprocess.check_output(['git','diff',INITIAL,source,'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT)
    return dict(actual_original_source=source,compiled_vapor_source_epoch_exact=True,Python_receipt_decoder_transition=bool(changed))


def mapped(store,path):return store.view('profiles/'+path.replace('\\','/').split('/evidence/',1)[1])


def read(proof,kinds=('water','cde')):
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    from cde_native_receipt import decode
    observations=[];native=[];stocks=0
    with ExitStack() as stack:
        water=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
        class Reference:
            def __truediv__(self,name):
                assert name.startswith('build/')
                return water.view('original-provider-build/'+name[6:])
        for kind in kinds:
            current=water if kind=='water' else Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_CDE_RAW_V1',stack)
            assert len(current.record['roles'])==16
            projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'));seen=set()
            for role in current.record['roles']:
                label,opt=role['case'],role['optimization'];assert (label,opt) not in seen;seen.add((label,opt))
                models,flags=next((m,f) for name,m,f in CASES if name==label)
                original=current.view(role['profile']);original_q=json.loads((original/'RESULT.json').read_text())
                assert original_q['kind']==kind and original_q['optimization']==opt and original_q['layer_models']==models and original_q['vapor_flags']==flags
                epoch=source_epoch(original_q['source']);profile=original
                if 'continuation' in role:
                    continued=current.view(role['continuation']);q=json.loads((continued/'RESULT.json').read_text())
                    assert kind=='cde' and label=='mixed-11-8' and original_q['status']=='FAILED'
                    assert q['retained_original_RESULT_sha256']==SHA((original/'RESULT.json').read_bytes())
                    source_epoch(q['continuation_producer']);profile=Profile(original,continued)
                q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=current.view(item['archive_prefix'])
                assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                result=audit(profile,Reference(),locations=dict(build=build,inputs=mapped(current,q['input_root'])))
                assert result['days']==1096 and result['cold_windows']==7
                meta=json.loads((build/'BUILD.json').read_text());nodes=meta['project']['nodes'];policy=meta['identity']['hydraulic_vapor']
                expanded=models*2 if len(models)==1 else models;layers=len(expanded)
                expected=[3,nodes,layers,0,int(kind=='cde'),0,0,0,0,0,1,2,1,6]+expanded+[f if m>=8 else 0 for m,f in zip(expanded,flags)]
                header=struct.pack('<'+str(len(expected))+'i',*expected)
                checkpoints=(original/'trajectory').glob('accepted-column-1-day-*.zip');assert len(checkpoints)==14
                rows=[json.loads(line) for line in (original/'trajectory/daily.jsonl').read_text().splitlines()]
                for path in checkpoints:
                    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as archive:raw=archive.read('macro.bin')
                    assert raw[48:48+2*len(header)]==header+header
                    if kind=='cde':
                        day=int(path.name[:-4].rsplit('-',1)[1]);assert decode(raw,nodes)==rows[day-1]['solute_end_mg_cm2'];stocks+=1
                observations.append(dict(case=label,kind=kind,optimization=opt,source_epoch=epoch,independent=result,split_cold_continuation='continuation' in role))
                if 'controls' in role:
                    c=json.loads(current.get(role['controls']+'/RESULT.json'));source_epoch(c['source'])
                    observed=controls(current,role['controls'],None)
                    assert observed['compiled_refusals']==(86 if kind=='cde' else 81)
                    native.append(dict(case=label,kind=kind,optimization=opt,**observed))
            assert seen=={(name,opt) for name,_,_ in CASES for opt in ('O0','O2')}
    assert len(observations)==16*len(kinds)
    return dict(status='ACTUAL_WINDOWS_VAPOR_RAW_FULL_NATIVE_AND_TRANSACTIONS_INDEPENDENT_PASS_NOT_ADMITTED',
        observations=observations,full1096_contexts=len(observations),exact_cold_windows=7*len(observations),
        exact_CDE_native_checkpoint_stock_checks=stocks,compiled_native_refusals=sum(c['compiled_refusals'] for c in native),
        active_transaction_contexts=len(native),controls=native,compiler_executions=0,model_executions=0,public_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--kind',choices=('water','cde'));a=p.parse_args();result=read(a.proof,(a.kind,) if a.kind else ('water','cde'))
    a.output.open('x',encoding='utf8').write(json.dumps(result,indent=2)+'\n');print(result['status'],result['full1096_contexts'],result['exact_cold_windows'],result['compiled_native_refusals'])
