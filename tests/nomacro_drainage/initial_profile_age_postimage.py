"""Build only the actual initial2 AGE counterpart and compare its full ABI."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from initial_profile_age_source_inverse import CORE,complete_inverse,git
from initial_profile_calendar_postimage import compare
from analytical_hydraulic_archives import SHA
from original_output_baseline import assignment
import original_output_matrix as original


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();complete_inverse();a.output.mkdir();prior=json.loads((a.profile/'RESULT.json').read_text());assert prior['status']=='ACTUAL_ORIGINAL_PRESSURE_AGE_EXISTING_NATIVE_EXACT_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
 source=git('rev-parse','HEAD').decode().strip()
 for sha in (source,prior['source']):assert not git('diff',CORE,sha,'--','app','src','tools/solute','tools/vq','reference')
 old=Path(prior['input_root']);assert assignment((a.input/'swap.swp').read_bytes().decode('cp1252'),'SWINCO',1).encode('cp1252')==(old/'swap.swp').read_bytes(),'Actual original2-to1 input generation is not byte-exact'
 for name,digest in prior['input_inventory']:
  if name!='swap.swp':assert (old/name).read_bytes()==(a.input/name).read_bytes()
 project=original.m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert original.m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))['SWINCO']==2 and original.m.e.auxiliary_magic(project)==b'S5IOA001'
 q=dict(status='RUNNING',source=source,case=prior['case'],optimization=prior['optimization'],initial1_profile=str(a.profile),initial1_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),initial1_build_root=prior['build_root'],input_root=str(a.input),input_inventory=original.m.e.inventory(a.input),build_root=str(a.build_root/'bundle'),model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  build=a.build_root/'bundle';opt=prior['optimization'];command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
  started=time.perf_counter();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240);(a.output/'build.stdout').write_text(result.stdout);(a.output/'build.stderr').write_text(result.stderr);q['build']=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-started);save();result.check_returncode()
  original.m.validate_bundle(build,a.reference_work,project);q['postimage']=compare(build,Path(prior['build_root']));q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());q['status']='ACTUAL_ORIGINAL_PRESSURE_AGE_INITIAL2_WHOLE_COMPILED_POSTIMAGE_NATIVE_ABI_PASS_NO_MODEL_REPLAY'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],q['case'],opt,flush=True)


if __name__=='__main__':main()
