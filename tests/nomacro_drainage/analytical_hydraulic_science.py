"""Independently read analytical cohorts; original paths remain immutable receipts."""
import argparse
from contextlib import ExitStack
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import zipfile
from analytical_hydraulic_archives import Archive
from analytical_hydraulic_forensics import audit
from hydraulic_mixed_analytical_read import audit as mixed_audit
from model7_search_science import Store
from analytical_interface_reuse import compare as interface_compare

ROOT=Path(__file__).resolve().parents[2]
RUNTIME='75d04a1245dde4388d011ad7d47a16c304377a21'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
CASES=(('3-feddes',[3],'feddes1'),('4',[4],'original'),('5',[5],'original'),('6',[6],'original'),
    ('8',[8],'original'),('9',[9],'original'),('10',[10],'original'),('11',[11],'original'),
    ('mixed-1-7',[1,7],'feddes1'),('mixed-7-3',[7,3],'feddes1'))


def mapped(store,path):return store.view('profiles/'+path.replace('\\','/').split('/evidence/',1)[1])


def source(store,prefix):
    q=json.loads(store.get(prefix+'/RESULT.json'));raw=store.get(prefix+'/actual-producer-source.zip')
    assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
    changed=subprocess.check_output(['git','diff','--name-only',RUNTIME,q['producer_head'],'--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT,text=True).splitlines()
    if changed:
        bridge=json.loads((ROOT/'tests/nomacro_drainage/analytical_frontend_guard_bridge.json').read_text())
        assert changed==[bridge['path']] and bridge['parent']==RUNTIME
        actual=subprocess.check_output(['git','show',q['producer_head']+':'+bridge['path']],cwd=ROOT)
        assert SHA(actual)==bridge['guard_sha256']
        inverse=actual.decode()
        for line in bridge['remove_exact_once']:
            assert inverse.count(line)==1;inverse=inverse.replace(line,'',1)
        parent=subprocess.check_output(['git','show',RUNTIME+':'+bridge['path']],cwd=ROOT)
        assert inverse.encode()==parent and SHA(parent)==bridge['parent_sha256']
    entries=subprocess.check_output(['git','ls-tree','-r',q['producer_head']],cwd=ROOT,text=True)
    blobs={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in entries.splitlines()}
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        for name in z.namelist():
            value=z.read(name);item=q['members'][name];assert SHA(value)==item['sha256'] and item['git_blob']==blobs[name]
            blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
            assert blobs[name] in (blob(value),blob(value.replace(b'\r\n',b'\n')))
    return q['producer_head']


def windows_cde(proof):
    observations=[];components={};failures=[]
    with ExitStack() as stack:
        store=Archive(proof,'HYDRAULIC_ANALYTICAL_WINDOWS_CDE_RAW_V1',stack)
        assert store.record['status']=='ACTUAL_ANALYTICAL_WINDOWS_CDE_RAW_ORIGINAL_REFUSALS_COMPONENTS_PRESERVED_NO_ADMISSION'
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));provider=Store(proof,'FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE',stack)
        class Reference:
            def __truediv__(self,name):
                assert name=='build' or name.startswith('build/')
                return provider.view('original-provider-build') if name=='build' else provider.view('original-provider-build/'+name[6:])
        admitted=Store(proof,'HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1',stack);old_projection=json.loads(admitted.get('COMPILED_PROJECTION_V1.json'))
        sources={version:source(store,'profiles/analytical-trial-actual-source-'+version) for version in ('v1','v2')}
        for opt in ('O0','O2'):
            components[opt]=mixed_audit(store.view('profiles/hydraulic-mixed-layers-original-'+opt+'-v1'),store.view('profiles/hydraulic-mixed-layers-corrected-'+opt+'-v1'))
            prior=json.loads(admitted.get(f'profiles/model7-search-daily-cde-short-{opt}-v1/RESULT.json'));baseline=admitted.view(old_projection[prior['build_root']]['archive_prefix'])
            for label,models,oxygen in CASES:
                version='v2' if label in ('8','9') else 'v1'
                for phase in ('short','full'):
                    profile=store.view(f'profiles/analytical-{label}-daily-cde-{phase}-{opt}-{version}');q=json.loads((profile/'RESULT.json').read_text())
                    assert q['kind']=='cde' and q['optimization']==opt and q.get('layer_models',[q['hydraulic_model']])==models and q.get('oxygen_policy','original')==oxygen
                    item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                    inputs=mapped(store,q['input_root']);control=(inputs/'swap.swp').read_text(encoding='cp1252')
                    selector=re.findall(r'(?mi)^[ \t]*IHWCKMODEL\s*=\s*([^!\r\n]+)',control);assert len(selector)==1 and list(map(int,selector[0].split()))==models
                    for key in ('SWKIMPL','SWHYST','SWFROST','SWSNOW','SWMACRO'):
                        assert re.findall(r'(?mi)^[ \t]*'+key+r'\s*=\s*(\d+)',control)==['0']
                    if max(models)>=8:assert re.findall(r'(?mi)^[ \t]*SWVAPOR\s*=\s*([^!\r\n]+)',control)[0].split()==['0','0']
                    result=audit(profile,Reference(),locations=dict(build=build,inputs=inputs));result['compiled_interface_reuse']=interface_compare(build,baseline,models)
                    assert result['days']==(35 if phase=='short' else 1096) and result['status']=='INDEPENDENT_ANALYTICAL_HYDRAULIC_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS'
                    observations.append(dict(case=label,phase=phase,**result))
            # Original model3 + oxygen2 is an explicit original nonimplementation.
            profile=store.view(f'profiles/analytical-3-daily-cde-full-{opt}-v1');q=json.loads((profile/'RESULT.json').read_text())
            rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
            diagnostic=(profile/'trajectory/original/swap.err').read_text(encoding='cp1252')
            assert q['status']=='FAILED' and len(rows)==523 and all(row['committed'] for row in rows)
            assert 'Combination of OXYGENSTRESS and bi-modal MvG (iHWCKmodel=3) is not (yet) possible!' in diagnostic
            assert not (profile/'trajectory/accepted-column-1-day-524.zip').is_file()
            failures.append(dict(model=3,optimization=opt,status='ORIGINAL_EXPLICIT_UNIMPLEMENTED_OXYGEN2_RETAINED_NO_QUALIFICATION',accepted_prefix=523,stop_day=524,error=q['error']))
            for model in (8,9):
                profile=store.view(f'profiles/analytical-{model}-daily-cde-short-{opt}-v1');q=json.loads((profile/'RESULT.json').read_text())
                diagnostic=(profile/'trajectory/original/swap.err').read_text(encoding='cp1252')
                assert q['status']=='FAILED' and 'DOUBLE PRECISION array HA' in diagnostic and 'On data file this variable is INTEGER' in diagnostic
                failures.append(dict(model=model,optimization=opt,status='ORIGINAL_READER_INTEGER_HA_INPUT_REFUSAL_RETAINED',accepted_days=0))
        witness=json.loads(store.get('observations/ANALYTICAL_11_ORIGINAL_PHASE_ASSERTION_FAILURE_V1.json'))
        assert witness['status']=='RETAINED_RAW_READER_PHASE_CORRESPONDENCE_ASSERTION_NOT_MODEL_FAILURE' and witness['day']==637 and witness['new_model_periods_needed']==0
    assert len(observations)==40 and sum(item['days']==1096 for item in observations)==20
    return dict(status='ACTUAL_WINDOWS_ANALYTICAL_CDE_RAW_COMPONENTS_FULL_NATIVE_INDEPENDENT_PASS_NO_ADMISSION',observations=observations,
        mixed_components=components,sources=sources,full1096_contexts=20,short35_contexts=20,exact_cold_windows=sum(item['cold_windows'] for item in observations),
        original_failed_roles=failures,phase_transfer_original_double_operations_exact=True,compiler_executions=0,model_executions=0,
        public_admission=False,whole_historical_family_closed=False,water_only_and_Ubuntu_still_pending=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
    result=windows_cde(a.proof);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['full1096_contexts'],result['exact_cold_windows'])
