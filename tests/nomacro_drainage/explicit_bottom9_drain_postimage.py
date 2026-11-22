"""Build only an initial1 counterpart; preserve the actual initial2 model identity."""
import argparse,json,subprocess,sys,time
from pathlib import Path
from explicit_bottom9_source_inverse import ROOT,CORE,complete_inverse,git
from initial_profile_calendar_postimage import compare
from explicit_bottom9_compiled_postimage import compare as binary
from original_output_baseline import assignment
from analytical_hydraulic_archives import SHA
import original_output_matrix as original

def main():
 p=argparse.ArgumentParser()
 for key in ('profile','input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();complete_inverse();prior=json.loads((a.profile/'RESULT.json').read_text());assert prior['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED';source=git('rev-parse','HEAD').decode().strip()
 for sha in (source,prior['source']):assert not git('diff',CORE,sha,'--','app','src','tools/solute','tools/vq','reference')
 primary=Path(prior['input_root']);flags=original.m.e.switches((primary/'swap.swp').read_text(encoding='cp1252'));assert flags['SWINCO']==2 and flags['SWDRA']==1 and flags['SWBOTB']==9
 assert assignment((a.input/'swap.swp').read_bytes().decode('cp1252'),'SWINCO',2).encode('cp1252')==(primary/'swap.swp').read_bytes()
 for name,digest in prior['input_inventory']:
  if name!='swap.swp':assert (a.input/name).read_bytes()==(primary/name).read_bytes()
 project=original.m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert original.m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'))['SWINCO']==1
 a.output.mkdir();opt=prior['optimization'];build=a.build_root/'bundle';command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
 started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);r.check_returncode();original.m.validate_bundle(build,a.reference_work,project)
 q=dict(status='ACTUAL_INITIAL1_BUILD_ONLY_COUNTERPART_OF_INITIAL2_DISTRIBUTED_DRAIN_REFERENCE_COMPILED_POSTIMAGE_PASS',source=source,physical_reference_producer=prior['source'],case=prior['case'],kind=prior['kind'],optimization=opt,reference_profile=str(a.profile),reference_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),reference_initial_selector=2,counterpart_initial_selector=1,input_root=str(a.input),input_inventory=original.m.e.inventory(a.input),build_root=str(build),reference_build_root=prior['build_root'],existing_compiled_Fortran_provider_ABI_observer=compare(build,Path(prior['build_root'])),actual_complete_compiled_bytes=binary(build,Path(prior['build_root'])),seconds=time.perf_counter()-started,model_executions=0,physical_initial1_period_equivalence_claimed=False,canonical_admission=False)
 (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],prior['kind'],opt,flush=True)

if __name__=='__main__':main()
