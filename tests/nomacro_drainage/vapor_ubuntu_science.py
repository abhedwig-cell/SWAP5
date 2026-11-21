"""Re-read original Ubuntu vapor artifacts, including their retained first failure."""
import argparse
from contextlib import ExitStack
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from analytical_hydraulic_archives import Archive
from analytical_hydraulic_science import controllers
from vapor_hydraulic_forensics import audit
from vapor_hydraulic_portable import CASES
from vapor_hydraulic_resume import read_initial,INITIAL
from vapor_mixed_component_forensics import audit as mixed

ROOT=Path(__file__).resolve().parents[2]
RUNTIME='daba94800'
PRODUCER='afac661b04e0224f89b6d54060fdc9993f413eec'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def source(store,expected):
    q=json.loads(store.get('source/RESULT.json'));raw=store.get('source/actual-producer-source.zip')
    assert q['producer_head']==expected and len(raw)==q['bytes'] and SHA(raw)==q['sha256']
    entries=subprocess.check_output(['git','ls-tree','-r',expected,'--',*q['surfaces']],cwd=ROOT,text=True).splitlines()
    blobs={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in entries}
    assert set(blobs)==set(q['members'])
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        assert len(archive.namelist())==len(set(archive.namelist()))
        assert set(archive.namelist())=={name for name,item in q['members'].items() if item.get('checkout')!='ABSENT'}
        for name in archive.namelist():
            value=archive.read(name);item=q['members'][name]
            assert SHA(value)==item['sha256'] and len(value)==item['bytes'] and item['git_blob']==blobs[name]
            blob=lambda data:hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
            assert blobs[name] in (blob(value),blob(value.replace(b'\r\n',b'\n')))
    owner=controllers(store);assert owner['producer']==expected
    return dict(source=expected,actual_source_bytes_sha256=q['sha256'],controller_bytes_sha256=json.loads(store.get('controller-source.json'))['sha256'])


def controls(store,prefix,expected_source=PRODUCER):
    q=json.loads(store.get(prefix+'/RESULT.json'))
    assert q['status']=='ACTUAL_COMPILED_VAPOR_NATIVE3_REFUSALS_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    if expected_source is not None:assert q['source']==expected_source
    assert q['positive_compiled_startup'] and q['accepted_model_days']==0
    assert len(q['refusals'])==57 and len(q['inherited_output_native_refusals']) in (24,29)
    for row in q['refusals']+q['inherited_output_native_refusals']:
        middle='' if row in q['refusals'] else '/inherited-native'
        start=prefix+middle+'/'+row['attack']+'/'
        errors=[name for name in store.names if name.startswith(start) and name.endswith('/donor.stderr')]
        assert len(errors)==1
        actual=store.get(errors[0]).decode(errors='replace').replace('\r\n','\n')
        assert actual==row['diagnostic'].replace('\r\n','\n') and 'ERROR STOP' in actual
        output=store.get(errors[0][:-len('stderr')]+'stdout')
        assert b'HYBRID_READY' not in output and b'HYBRID_DAY_RETURN' not in output
    assert all(value is True for value in q['transactions'].values())
    return dict(compiled_refusals=len(q['refusals'])+len(q['inherited_output_native_refusals']),transactions=q['transactions'])


def read(proof,optimizations=('O0','O2')):
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    from cde_native_receipt import decode
    observations=[];sources={};native=[];stocks=0
    with ExitStack() as stack:
        for opt in optimizations:
            old=Archive(proof,'HYDRAULIC_VAPOR_UBUNTU_INITIAL_'+opt+'_RAW_V1',stack)
            current=Archive(proof,'HYDRAULIC_VAPOR_UBUNTU_CONTINUATION_'+opt+'_RAW_V1',stack)
            sources[opt]=dict(initial=source(old,INITIAL),continuation=source(current,PRODUCER))
            assert not subprocess.check_output(['git','diff',RUNTIME,PRODUCER,'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT)
            workflow='.github/workflows/nomacro-water-snow-groundwater.yml'
            assert current.get('actual-workflow.yml').replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',PRODUCER+':'+workflow],cwd=ROOT)
            assert current.get('actual-workflow-git-blob.txt').decode().strip()==subprocess.check_output(['git','rev-parse',PRODUCER+':'+workflow],cwd=ROOT,text=True).strip()
            top=json.loads(current.get('vapor-hydraulic-family/RESULT.json'))
            assert top['status']=='ACTUAL_VAPOR_PORTABLE_16FULL_112COLD_MIXED_COMPONENTS_COMPILED_NATIVE_TRANSACTIONS_INDEPENDENT_PASS_NOT_ADMITTED'
            assert top['producer']==PRODUCER and top['optimization']==opt and len(top['steps'])==30 and all(s['status']=='PASS' for s in top['steps'])
            reused=read_initial(old.view('.'),opt)
            assert reused==top['reused_initial']
            components=mixed(old.view('vapor-hydraulic-family'),(opt,))
            assert components==json.loads(current.get('vapor-hydraulic-family/MIXED_COMPONENT_INDEPENDENT.json'))
            for label,models,flags in CASES:
                store=old if label=='8' else current
                projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
                class Reference:
                    def __truediv__(self,name):
                        assert name.startswith('build/')
                        return store.view('original-provider-build/'+name[6:])
                for kind in ('water','cde'):
                    prefix='vapor-hydraulic-family/'+label+'-'+kind+'-full';profile=store.view(prefix)
                    q=json.loads((profile/'RESULT.json').read_text())
                    assert q['source']==(INITIAL if label=='8' else PRODUCER) and q['optimization']==opt and q['kind']==kind
                    assert q['layer_models']==models and q['vapor_flags']==flags
                    item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                    result=audit(profile,Reference(),locations=dict(build=build,inputs=profile/'input'))
                    assert result['days']==1096 and result['cold_windows']==7
                    observations.append(dict(case=label,kind=kind,optimization=opt,independent=result))
                    if kind=='cde':
                        meta=json.loads((build/'BUILD.json').read_text());nodes=meta['project']['nodes']
                        rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
                        checkpoints=(profile/'trajectory').glob('accepted-column-1-day-*.zip');assert len(checkpoints)==14
                        for path in checkpoints:
                            day=int(path.name[:-4].rsplit('-',1)[1])
                            with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as archive:raw=archive.read('macro.bin')
                            assert raw[:8]==b'S5HVC003' and decode(raw,nodes)==rows[day-1]['solute_end_mg_cm2'];stocks+=1
                    if label=='mixed-7-8':native.append(controls(current,'vapor-hydraulic-family/'+label+'-'+kind+'-controls'))
    assert len(observations)==16*len(optimizations) and stocks==112*len(optimizations)
    return dict(status='ACTUAL_UBUNTU_VAPOR_RAW_FULL_NATIVE_COMPONENTS_AND_PRIVATE_TRANSACTIONS_INDEPENDENT_PASS_NOT_ADMITTED',
        sources=sources,observations=observations,full1096_contexts=len(observations),exact_cold_windows=7*len(observations),
        exact_CDE_native_checkpoint_stock_checks=stocks,new_descriptor_native_controls=native,
        original_failed_CDE_public_receipt_roles_preserved=True,initial_full_periods_reused=2*len(optimizations),
        compiler_executions=0,model_executions=0,public_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'));a=p.parse_args();result=read(a.proof,(a.optimization,) if a.optimization else ('O0','O2'))
    a.output.open('x',encoding='utf8').write(json.dumps(result,indent=2)+'\n');print(result['status'],result['full1096_contexts'],result['exact_cold_windows'])
