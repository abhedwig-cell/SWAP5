"""Independent public build-bundle warm and cold groundwater CDE commands."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import zipfile
import groundwater_chemical_runtime as runtime

m=runtime.m


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','matrix-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir();cohort=json.loads((args.matrix_root/'RESULT.json').read_text())
    record=dict(status='RUNNING',profiles={})
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for name in ('crossing-csv3','crossing-bbc','crossing-default'):
            item=cohort['cases'][name];build=Path(item['build_root']);inputs=Path(item['input_root'])
            project=m.e.load(inputs,original_output=name!='crossing-default');m.validate_bundle(build,args.reference_work,project)
            out=args.output/name;out.mkdir()
            command=[sys.executable,'-B',str(runtime.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                '--experimental-project',inputs,'--reference-work',args.reference_work,'--build-bundle',build]
            if project.original_output:command+=['--original-output']
            def call(label,*extra):
                start=time.perf_counter();result=subprocess.run(list(map(str,[*command,*extra])),cwd=runtime.ROOT,capture_output=True,text=True,timeout=90)
                (out/(label+'.stdout')).write_text(result.stdout,encoding='utf8');(out/(label+'.stderr')).write_text(result.stderr,encoding='utf8')
                result.check_returncode()
                return dict(command=list(map(str,[*command,*extra])),returncode=result.returncode,seconds=time.perf_counter()-start)
            warm=call('warm','--days',10,'--checkpoint-at',7,'--output',out/'warm')
            source=out/'warm/accepted-column-1-day-7.zip';digest=m.sha(source)
            cold=call('cold','--days',9,'--checkpoint-at',9,'--restart',source,'--restart-day',7,'--output',out/'cold')
            left=m.rows(out/'warm');right=m.rows(out/'cold');m.check(left);m.check(right)
            assert m.physical(right)==m.physical(left[7:9])
            assert m.physical(left)==m.physical(m.rows(Path(item['short_root'])/'trajectory'))
            with zipfile.ZipFile(Path(item['short_root'])/'trajectory/accepted-column-1-day-9.zip') as a,zipfile.ZipFile(out/'cold/accepted-column-1-day-9.zip') as b:
                for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
            from original_output import selection
            from original_output_files import compare
            files=compare(out/'warm/original',out/'cold/original',selection(project) or dict(flprintdt=False,nprintday=1),7,9,project.start_date)
            assert m.sha(source)==digest
            record['profiles'][name]=dict(warm=warm,cold=cold,physical_exact=True,complete_native_exact=True,user_output_exact=files,origin_unchanged=True)
            save();print(name,'PUBLIC_GROUNDWATER_CDE_COMPLETE_NATIVE_PASS',flush=True)
        record['status']='THREE_PUBLIC_GROUNDWATER_CDE_SELF_CONTAINED_RESTART_CONTEXTS_PASS'
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
