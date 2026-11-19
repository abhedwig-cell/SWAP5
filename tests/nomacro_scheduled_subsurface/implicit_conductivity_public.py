"""Actual public implicit conductivity commands with complete cold state."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path
import age_groundwater_runtime as runtime
from age_groundwater_output import metadata as selection
from original_output_files import compare

m=runtime.m

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();matrix=json.loads((a.matrix_root/'RESULT.json').read_text(encoding='utf8'));q=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for name in ('water-head','water-air-history','water-groundwater','water-groundwater-history','cde-head','cde-groundwater-history'):
            item=matrix['cases'][name];inputs=Path(item['input_root']);build=Path(item['build_root']);project=m.e.load(inputs,original_output=True)
            m.validate_bundle(build,a.reference_work,project);out=a.output/name;out.mkdir()
            command=[sys.executable,'-B',str(runtime.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,
                '--original-output','--reference-work',a.reference_work,'--build-bundle',build]
            def call(label,*extra):
                start=time.perf_counter();r=subprocess.run(list(map(str,[*command,*extra])),cwd=runtime.ROOT,capture_output=True,text=True,timeout=90)
                (out/(label+'.stdout')).write_text(r.stdout,encoding='utf8');(out/(label+'.stderr')).write_text(r.stderr,encoding='utf8');r.check_returncode()
                return dict(command=list(map(str,[*command,*extra])),returncode=r.returncode,seconds=time.perf_counter()-start)
            warm=call('warm','--days',35,'--checkpoint-at',30,'--output',out/'warm');source=out/'warm/accepted-column-1-day-30.zip';digest=m.sha(source)
            cold=call('cold','--days',34,'--checkpoint-at',34,'--restart',source,'--restart-day',30,'--output',out/'cold')
            left=m.rows(out/'warm');right=m.rows(out/'cold');m.check(left);m.check(right)
            assert m.physical(right)==m.physical(left[30:34]) and m.physical(left)==m.physical(m.rows(Path(item['short_root'])/'trajectory'))
            with zipfile.ZipFile(Path(item['short_root'])/'trajectory/accepted-column-1-day-34.zip') as x,zipfile.ZipFile(out/'cold/accepted-column-1-day-34.zip') as y:
                for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),member
            files=compare(out/'warm/original',out/'cold/original',selection(project),30,34,project.start_date);assert m.sha(source)==digest
            q['profiles'][name]=dict(warm=warm,cold=cold,physical_exact=True,complete_native_exact=True,user_output_exact=files,origin_unchanged=True)
            save();print(name,'PUBLIC_IMPLICIT_CONDUCTIVITY_NATIVE_OUTPUT_PASS',flush=True)
        q['status']='SIX_PUBLIC_IMPLICIT_WATER_CDE_COMPLETE_NATIVE_RESTART_CONTEXTS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
