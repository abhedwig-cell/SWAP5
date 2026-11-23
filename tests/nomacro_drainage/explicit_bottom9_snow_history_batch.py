"""One coherent existing Snow/history/calendar qualification with optional reuse."""
import argparse,json,subprocess,sys,time
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_history_source_v2 import ROOT,complete_inverse,git
from explicit_bottom9_snow_history_science_v2 import native_controls


def main():
    p=argparse.ArgumentParser()
    for name in ('reference-work','proof','build-root'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--reuse-map',type=Path);a=p.parse_args()
    complete_inverse();a.proof.mkdir(parents=True,exist_ok=True);a.build_root.mkdir(parents=True,exist_ok=True)
    head=git('rev-parse','HEAD').decode().strip();reuse=json.loads(a.reuse_map.read_text()) if a.reuse_map else {};cases=[]
    with ExitStack() as stack:
        for name in ('EXPLICIT_BOTTOM9_SNOW_HISTORY_INPUTS_V1','EXPLICIT_BOTTOM9_SNOW_HISTORY_CALENDAR_INPUTS_V3'):
            store=Archive(ROOT/'integration/f-ci/nomacro-complete01',name,stack)
            for suffix in ('.zip','.json'):(a.proof/(name+suffix)).write_bytes((ROOT/'integration/f-ci/nomacro-complete01'/(name+suffix)).read_bytes())
            for role in store.record['roles']:
                for member in store.names:
                    if not member.startswith(role+'/'):continue
                    path=a.proof/'inputs'/role/Path(member).name;path.parent.mkdir(parents=True,exist_ok=True)
                    with path.open('xb') as f:f.write(store.get(member))
                if '-initial1-' not in role:continue
                label=role.replace('-initial1-','-')+('-daily' if name.endswith('INPUTS_V1') else '')
                cases.append(dict(label=label,initial1=role,initial2=role.replace('-initial1-','-initial2-')))
    assert len(cases)==14 and len({q['label'] for q in cases})==14
    record=dict(status='RUNNING',source=head,optimization=a.optimization,contexts=[],completed_model_periods_replayed=0,canonical_admission=False);start=time.monotonic()
    save=lambda:(a.proof/'BATCH.json').write_text(json.dumps(record,indent=2)+'\n')
    def run(command,label):
        assert git('rev-parse','HEAD').decode().strip()==head
        with (a.proof/(label+'.stdout')).open('xb') as out,(a.proof/(label+'.stderr')).open('xb') as err:done=subprocess.run([sys.executable,'-B',*map(str,command)],cwd=ROOT,stdout=out,stderr=err,timeout=1200)
        assert done.returncode==0,dict(label=label,returncode=done.returncode)
    save()
    try:
        for case in cases:
            label=case['label']+'-'+a.optimization;record['active']=label;save();inputs=a.proof/'inputs'/case['initial1']
            if label in reuse:
                profile=Path(reuse[label]['profile']);science=Path(reuse[label]['independent']);q=json.loads((profile/'RESULT.json').read_text());s=json.loads(science.read_text())
                assert 'PASS' in q['status'] and s['producer']==q['source'] and s['actual_days']==35
                assert {n:SHA((inputs/n).read_bytes()) for n,_ in q['input_inventory']}==dict(q['input_inventory'])
                reused=True
            else:
                profile=a.proof/label;science=a.proof/(label+'-INDEPENDENT.json');reused=False
                run(['tests/nomacro_drainage/explicit_bottom9_snow_history_runtime_v2.py','--input',inputs,'--reference-work',a.reference_work,'--build-root',a.build_root/label,'--output',profile,'--optimization',a.optimization],label+'-runtime')
                run(['tests/nomacro_drainage/explicit_bottom9_snow_history_science_v2.py','--profile',profile,'--output',science],label+'-reader')
                q=json.loads((profile/'RESULT.json').read_text());s=json.loads(science.read_text())
            post=a.proof/(label+'-initial2')
            run(['tests/nomacro_drainage/explicit_bottom9_snow_history_postimage.py','--profile',profile,'--input',a.proof/'inputs'/case['initial2'],'--reference-work',a.reference_work,'--build-root',a.build_root/(label+'-initial2'),'--output',post],label+'-postimage')
            controls=None;transactions=None
            if case['label'] in ('water-hys1-step-reset','water-hys2-monthly','cde-hys1-subdaily','cde-hys2-step-reset'):
                controls=a.proof/(label+'-native-controls')
                run(['tests/nomacro_drainage/explicit_bottom9_snow_history_native_controls.py','--profile',profile,'--reference-work',a.reference_work,'--output',controls],label+'-native')
                independent=native_controls(controls,profile)
                (a.proof/(label+'-NATIVE-INDEPENDENT.json')).write_text(json.dumps(independent,indent=2)+'\n')
            if case['label'] in ('water-hys1-step-reset','cde-hys2-step-reset'):
                transactions=a.proof/(label+'-transactions')
                run(['tests/nomacro_drainage/explicit_bottom9_snow_history_transactions.py','--profile',profile,'--reference-work',a.reference_work,'--output',transactions],label+'-transactions')
            record['contexts'].append(dict(**case,optimization=a.optimization,profile=str(profile),profile_producer=q['source'],independent=str(science),independent_sha256=SHA(science.read_bytes()),current_initial2_postimage=str(post),native_controls=str(controls) if controls else None,transactions=str(transactions) if transactions else None,completed_period_reused=reused,status=s['status']));save()
            print('ACTUAL_SNOW_HISTORY_CALENDAR_SOURCE_NATIVE_COLD_INITIAL2_PASS',label,flush=True)
        complete_inverse();assert len(record['contexts'])==14
        record.update(status='ALL14_SNOW_HISTORY_CALENDAR_CONTEXTS_INDEPENDENT_NATIVE_COLD_AND_INITIAL2_PASS_NOT_ADMITTED',seconds=time.monotonic()-start);record.pop('active',None)
    except Exception as error:record.update(status='FAILED_SNOW_HISTORY_CALENDAR_BATCH_NOT_QUALIFIED',error=repr(error));raise
    finally:record['actual_completion_head']=git('rev-parse','HEAD').decode().strip();save()
    assert record['actual_completion_head']==head
    print(record['status'],a.optimization,record['seconds'],flush=True)


if __name__=='__main__':main()
