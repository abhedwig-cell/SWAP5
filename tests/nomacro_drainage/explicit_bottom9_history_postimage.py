"""Compile initial2 only and compare every paired history generated/binary file."""
import argparse,json,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_runtime import m
from explicit_bottom9_source_inverse import git
from explicit_bottom9_history_runtime import CORE
from initial_profile_calendar_postimage import compare
from explicit_bottom9_compiled_postimage import compare as all_compiled
from analytical_hydraulic_archives import SHA


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();prior=json.loads((a.profile/'RESULT.json').read_text());assert prior['status']=='ACTUAL_EXPLICIT9_HYSTERESIS_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED'
 source=git('rev-parse','HEAD').decode().strip();assert not git('diff',CORE,'--','app','src','tools','reference')
 old=Path(prior['input_root']);left=(old/'swap.swp').read_bytes();right=(a.input/'swap.swp').read_bytes()
 convert=lambda raw:re.sub(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)2(?=[ \t!\r\n])',rb'\g<1>1',raw)
 assert left!=right and convert(right)==left,'Initial2 input differs beyond exact one selector byte'
 for name,digest in prior['input_inventory']:
  assert SHA((old/name).read_bytes())==digest
  if name!='swap.swp':assert (old/name).read_bytes()==(a.input/name).read_bytes()
 project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))['SWINCO']==2
 q=dict(status='RUNNING',source=source,initial1_profile=str(a.profile),initial1_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),initial1_build_root=prior['build_root'],kind=prior['kind'],hysteresis=prior['hysteresis'],optimization=prior['optimization'],input_root=str(a.input),input_inventory=m.e.inventory(a.input),build_root=str(a.build_root/'bundle'),model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  opt=prior['optimization'];build=a.build_root/'bundle';command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
  started=time.perf_counter()
  with (a.output/'build.stdout').open('x') as stdout,(a.output/'build.stderr').open('x') as stderr:result=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
  q['build']=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-started,actual_completion_head=git('rev-parse','HEAD').decode().strip());save();result.check_returncode();assert q['build']['actual_completion_head']==source
  m.validate_bundle(build,a.reference_work,project);q['postimage']=compare(Path(prior['build_root']),build);q['all_compiled']=all_compiled(Path(prior['build_root']),build);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());q['status']='ACTUAL_HISTORY9_INITIAL2_WHOLE_GENERATED_AND_COMPILED_POSTIMAGE_PASS_NO_MODEL_REPLAY'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],q['kind'],q['hysteresis'],opt,flush=True)


if __name__=='__main__':main()
