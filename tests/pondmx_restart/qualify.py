"""Selected production full/native qualification after the causal experiment."""
from pathlib import Path
import importlib.util,json,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def main():
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--old-results',type=Path);p.add_argument('--kind',choices=['water','chemical']);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    all_inputs=out/'inputs';all_inputs.mkdir();inventory=m.fixtures(all_inputs)
    reports={};events=[]
    def save(): (out/'RESULT.json').write_text(json.dumps(dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),reports=reports,events=events,water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,science='NOT_QUALIFIED'),indent=2))
    for kind in ([a.kind] if a.kind else ['water','chemical']):
        key=kind+'-surface-history';case=all_inputs/key;project=m.e.load(case);item=reports[key]={}
        for opt in ('O0','O2'):
            build=out/(key+'-'+opt+'-build')
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
            t=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/(key+'-'+opt+'-build.stdout')).write_text(r.stdout);(out/(key+'-'+opt+'-build.stderr')).write_text(r.stderr)
            events.append(dict(command=command,seconds=time.perf_counter()-t,returncode=r.returncode));assert r.returncode==0,r.stderr
            meta,_=m.validate_bundle(build,a.reference_work,project)
            assert meta['identity']['scheduled_pond_history']['policy']=='original-top-scheduled-pond-history-v2'
            short=out/(key+'-'+opt+'-short201')
            item[opt]={'short':m.trajectory(build,a.reference_work,project,short,201,{199,201},30)[0]}
            item[opt]['short']['own']=m.own(build,a.reference_work,project,short,m.rows(short),199,201,out/(key+'-'+opt+'-short-own199'))
            print(key,opt,'SHORT199_TO201_NATIVE_EXACT',flush=True);save()
            full=out/(key+'-'+opt+'-full');item[opt]['full'],data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,199,201,365,367,530,532,1096},60)
            item[opt]['full']['own']=[m.own(build,a.reference_work,project,full,data,start,end,out/(key+'-'+opt+f'-own{start}')) for start,end in ((2,4),(199,201),(365,367),(530,532))]
            if a.old_results:
                previous=a.old_results/(key+'-'+opt+'-full')
                assert m.physical(data)==m.physical(m.rows(previous)),'forward physical trajectory changed'
                assert m.csvlines(full/'original/result_output.csv')==m.csvlines(previous/'original/result_output.csv'),'forward CSV changed'
                item[opt]['full']['prior_failed_source_full_physics_and_csv_exact']=True
                old_origin=previous/'accepted-column-1-day-199.zip'
                try:m.h.verify_checkpoint(old_origin,199,meta['binding'],out/(key+'-'+opt+'-foreign-origin'))
                except ValueError:item[opt]['old_source_checkpoint_refused']=True
                else:raise AssertionError('Old source checkpoint rebound')
            if opt=='O2':
                foreign=out/(key+'-foreign-bundle');shutil.copytree(build,foreign)
                changed=json.loads((foreign/'BUILD.json').read_text());changed['identity'].pop('scheduled_pond_history');(foreign/'BUILD.json').write_text(json.dumps(changed))
                try:m.validate_bundle(foreign,a.reference_work,project)
                except ValueError:item['missing_history_policy_refused']=True
                else:raise AssertionError('Missing history policy accepted')
            print(key,opt,'FULL1096_AND_ALL_NATIVE_WINDOWS_EXACT',flush=True);save()
        from exact_reference import compare
        item['reference']=compare(out/(key+'-O2-full'),a.reference_work,out/(key+'-executed-input-reference'))
        assert item['reference']['status']=='COMPLETE_DIAGNOSTIC_REFERENCE'
        item['status']='SCHEDULED_PONDMX_RESTART_FULL_O0_O2_PASS';save()
    print('SCHEDULED_PONDMX_RESTART_FULL_O0_O2_PASS',flush=True)


if __name__=='__main__':main()
