"""Finish independent checks after retained native failures; never rerun full O0."""
import importlib.util, json, struct, subprocess, sys, time, zipfile
from pathlib import Path
spec=importlib.util.spec_from_file_location('mixtures',Path(__file__).with_name('run.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def inspect_window(full,cold,start,end):
    a,b=m.rows(full),m.rows(cold)
    result=dict(start=start,end=end,exact_physical=m.physical(a[start:end])==m.physical(b),
                exact_csv=m.csvlines(cold/'original/result_output.csv')[-(end-start):]==m.csvlines(full/'original/result_output.csv')[start+2:end+2])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(cold/f'accepted-column-1-day-{end}.zip') as y:
        result['exact_native_result_end']=x.read('result.end')==y.read('result.end')
        left,right=x.read('macro.bin'),y.read('macro.bin')
    result['exact_native_auxiliary']=left==right
    if left!=right:
        differences=[i for i,(a,b) in enumerate(zip(left,right)) if a!=b]
        result['auxiliary_bytes']=[len(left),len(right)]
        result['differing_byte_offsets']=differences
        micro=struct.unpack_from('=i',left,len(left)-4)[0];top=len(left)-micro-72
        assert struct.unpack_from('=i',left,top+68)[0]==72
        result['original_top_context']={name:dict(warm=struct.unpack_from('=d',left,top+12+8*i)[0],cold=struct.unpack_from('=d',right,top+12+8*i)[0]) for i,name in enumerate(('theatm','katm','h0max','k1max','q0','hsurf'))}
    result['status']='EXACT_OWN_PASS' if all(result[k] for k in ('exact_physical','exact_csv','exact_native_result_end','exact_native_auxiliary')) else 'EXACT_OWN_FAIL_RETAINED'
    return result


def main():
    root=Path(sys.argv[1]);ref=Path(sys.argv[2])
    original=json.loads((root/'RESULT.json').read_text());report=dict(original_source_commit=original['source_commit'],verification_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=m.ROOT,text=True).strip(),completed_O0_physics_reexecuted=False,cases={})
    def save(): (root/'COMPLETION.json').write_text(json.dumps(report,indent=2))
    for key in m.KEYS:
        case=root/key;project=m.e.load(case);item=report['cases'][key]={}
        for opt in ('O0','O2'):
            build=root/(key+'-'+opt+'-build');full=root/(key+'-'+opt+'-full')
            if not full.exists():
                command=[sys.executable,'-B',str(m.ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(case),'--reference-work',str(ref),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
                t=time.perf_counter();r=subprocess.run(command,cwd=m.ROOT,capture_output=True,text=True,timeout=180)
                (root/(key+'-'+opt+'-build.stdout')).write_text(r.stdout);(root/(key+'-'+opt+'-build.stderr')).write_text(r.stderr);assert r.returncode==0,r.stderr
                item['new_build']=dict(command=command,seconds=time.perf_counter()-t)
                item[opt],data=m.trajectory(build,ref,project,full,1096,{2,4,199,201,365,367,530,532,1096},60)
            else:
                data=m.rows(full);assert len(data)==1096
                item[opt]=dict(status='FULL_PASS_RECONSUMED',days=1096,budgets=m.check(data))
            item[opt]['windows']=[]
            for start,end in ((2,4),(199,201),(365,367),(530,532)):
                cold=root/(key+'-'+opt+f'-own{start}')
                if not cold.exists():
                    try:m.own(build,ref,project,full,data,start,end,cold)
                    except AssertionError as error:
                        # Retain the actual native/physical mismatch; continue
                        # independent windows instead of weakening equality.
                        item.setdefault('retained_refusals',[]).append(dict(opt=opt,start=start,error=repr(error)))
                item[opt]['windows'].append(inspect_window(full,cold,start,end));save()
            print(key,opt,'FULL_AND_ALL_OWN_WINDOWS_CHECKED',flush=True)
        if 'reference' in original['cases'][key]:item['reference']=original['cases'][key]['reference']
        else:item['reference']=m.reference_run(case,ref,root/(key+'-original431'),root/(key+'-O2-full'),20)
        item['status']='FULL_AND_EXACT_OWN_PASS' if all(w['status']=='EXACT_OWN_PASS' for opt in ('O0','O2') for w in item[opt]['windows']) else 'FULL_PERIOD_PASS_EXACT_OWN_FAIL'
        save();print(key,item['status'],flush=True)


if __name__=='__main__':main()
