"""Real current build, unchanged physical postimage and targeted transactions."""
import argparse,json,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from ria12_water_polish_source import complete_inverse,git,SHA
from ria12_water_polish import POLICY,TIME_POLICY
from explicit_bottom9_runtime import m,own
from snow58_compiled_postimage import compare
from daily_coupling import CoupledDailyColumn
from original_output_controls import physical

def main():
    p=argparse.ArgumentParser()
    for name in ('profile','reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();complete_inverse();head=git('rev-parse','HEAD').decode().strip()
    prior_raw=(a.profile/'RESULT.json').read_bytes();prior=json.loads(prior_raw)
    assert prior['status']=='ACTUAL_RIA_ADDITIONAL_WATER_POLISH35_GLOBAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    old=Path(prior['build_root']);assert SHA((old/'BUILD.json').read_bytes())==prior['actual_BUILD_sha256']
    project=m.e.load(prior['input_root'],original_output=True,time_step_policy=TIME_POLICY,water_polish_policy=POLICY)
    a.output.mkdir();build=a.build_root/'bundle'
    q=dict(status='RUNNING_CURRENT_POLISH_POSTIMAGE_NOT_ADMITTED',actual_source=head,original_full35_source=prior['source'],original_compiler_source=prior['actual_compiler_source'],original_profile=str(a.profile),original_RESULT_sha256=SHA(prior_raw),kind=prior['kind'],optimization=prior['optimization'],full35_periods_replayed=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',prior['input_root'],'--original-output','--experimental-time-step-policy',TIME_POLICY,'--experimental-water-polish-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',prior['optimization'],'--kernel-opt',prior['optimization'],'--output',str(build)]
        with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
        q['build']=dict(command=command,returncode=r.returncode);save();r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project)
        assert meta['identity']['ria12_water_polish_source']==SHA((R/'app/hybrid_water/ria12_water_polish.py').read_bytes())
        sources=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')}
        left,right=sources(old),sources(build);assert left and left.keys()==right.keys();q['generated']=[]
        for name,path in sorted(left.items()):
            before,after=path.read_bytes(),right[name].read_bytes();assert before.replace(b'\r\n',b'\n')==after.replace(b'\r\n',b'\n')
            q['generated'].append(dict(file=name,original_sha256=SHA(before),current_sha256=SHA(after)))
        q['compiled']=compare(old,build);q['actual_build_root']=str(build);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());save()
        trajectory,data=m.trajectory(build,a.reference_work,project,a.output/'prefix6',6,{2,4,6},120)
        original=m.rows(a.profile/'trajectory');assert m.physical(data)==m.physical(original[:6])
        for day in (2,4):
            with zipfile.ZipFile(a.profile/f'trajectory/accepted-column-1-day-{day}.zip') as oldzip,zipfile.ZipFile(a.output/f'prefix6/accepted-column-1-day-{day}.zip') as newzip:
                assert all(oldzip.read(name)==newzip.read(name) for name in ('macro.bin','result.end'))
        q['current_prefix']=dict(trajectory=trajectory,days=6,physical_and_complete_native_exact=True)
        q['cold']=own(build,a.reference_work,project,a.output/'prefix6',data,2,4,a.output/'own-2');save()
        source=a.output/'prefix6/accepted-column-1-day-4.zip';digest=SHA(source.read_bytes())
        column=CoupledDailyColumn(build,a.reference_work,a.output/'external',project,'original-output',origin=source,day=4,adopt_native=True)
        trial=column.prepare();assert physical(trial)==m.physical([original[4]])
        column.discard(trial);assert column.day==4
        replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
        recovered=CoupledDailyColumn(build,a.reference_work,a.output/'recovered',project,'original-output',origin=column.checkpoint,day=5)
        endpoint=recovered.prepare();assert physical(endpoint)==m.physical([original[5]]);recovered.discard(endpoint)
        assert SHA(source.read_bytes())==digest
        q['transactions']=dict(prepares=3,commits=1,discard_no_day_advance=True,replay_exact=True,recovered_next_day_exact=True,origin_unchanged=True)
        complete_inverse();assert git('rev-parse','HEAD').decode().strip()==head
        q['status']='CURRENT_RIA_POLISH_ALL_GENERATED_COMPILED_NATIVE_PREFIX_COLD_EXTERNAL_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_CURRENT_RIA_POLISH_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(q['status'],q['kind'],q['optimization'])
if __name__=='__main__':main()
