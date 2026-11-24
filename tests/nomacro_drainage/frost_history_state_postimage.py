"""Actual selected explicit source/compiled/native preservation, no full replay."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from frost_history_state_batch import source
from snow58_compiled_postimage import compare
from explicit_bottom9_runtime import m
import output_thermal_runtime as thermal
import output_thermal_controls as controls
from original_output_files import compare as outputs
from original_output_thermal import metadata


def main():
    p=argparse.ArgumentParser()
    for name in ('profile','reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();head=source();a.output.mkdir();old=json.loads((a.profile/'RESULT.json').read_text());assert old['status'].endswith('PASS_NOT_ADMITTED');left=Path(old['build_root']);right=a.build_root/'bundle';project=m.e.load(old['input_root'],original_output=True,time_step_policy='original-adaptive-event-closure-v1')
    q=dict(status='RUNNING_CURRENT_EXPLICIT_POSTIMAGE_NOT_ADMITTED',actual_source=head,original_compiler=old['source'],original_profile=str(a.profile),actual_build_root=str(right),kind=old['kind'],optimization=old['optimization'],compiler_executions=1,full35_periods_replayed=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        opt=old['optimization'];command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(old['input_root']),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(right)]
        with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
        q['build']=dict(command=command,returncode=r.returncode);save();r.check_returncode();assert source()==head
        files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')}
        a_files,b_files=files(left),files(right);assert a_files and a_files.keys()==b_files.keys();q['generated']=[]
        for name,path in a_files.items():
            raw,actual=path.read_bytes(),b_files[name].read_bytes();assert raw.replace(b'\r\n',b'\n')==actual.replace(b'\r\n',b'\n');q['generated'].append(dict(file=name,original_raw_sha256=hashlib.sha256(raw).hexdigest(),actual_raw_sha256=hashlib.sha256(actual).hexdigest()))
        q['compiled']=compare(left,right);m.validate_bundle(right,a.reference_work,project);save()
        q['prefix'],data=m.trajectory(right,a.reference_work,project,a.output/'prefix6',6,{2,4,6},90);assert m.physical(data)==m.physical(m.rows(a.profile/'trajectory')[:6]);q['exact_original_physical_prefix']=True
        for day in (2,4):
            with zipfile.ZipFile(a.output/'prefix6'/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(a.profile/'trajectory'/f'accepted-column-1-day-{day}.zip') as y:assert all(x.read(name)==y.read(name) for name in ('macro.bin','result.end'))
        q['exact_original_native_prefix_days']=[2,4];q['own']=thermal.own(right,a.reference_work,project,a.output/'prefix6',data,2,4,a.output/'own2')
        q['original_user_outputs']=outputs(a.profile/'trajectory/original',a.output/'prefix6/original',metadata(project),0,6,project.start_date)
        q['transactions']=controls.transactions(right,a.reference_work,project,a.output/'prefix6',a.output/'transactions');assert source()==head
        q['status']='ACTUAL_CURRENT_EXPLICIT_COMPLETE_GENERATED_COMPILED_PREFIX_NATIVE_COLD_OUTPUT_TRANSACTIONS_PASS_NO_FULL_REPLAY'
    except Exception as error:q.update(status='FAILED_CURRENT_EXPLICIT_POSTIMAGE_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
