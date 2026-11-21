"""Capture the new monthly compiled postimage beside its exact original evidence."""
import argparse,json,subprocess,sys,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as original
from calendar_evidence import differences
m=original.m


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','original-profile','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();prior=json.loads((a.original_profile/'RESULT.json').read_text())
 assert prior['status']=='ACTUAL_EXISTING_NOSNOW_VAPOR_MONTHLY_35DAY_TWO_EXACT_COLD_POSTIMAGE_PASS_NOT_ADMITTED' and prior['optimization']=='O2' and len(prior['cold'])==2
 inputs=Path(prior['input_root']);project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert m.e.inventory(inputs)==tuple(map(tuple,prior['input_inventory']))
 build=a.build_root/'bundle';q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),original_source=prior['source'],original_profile=str(a.original_profile),original_RESULT_sha256=m.sha(a.original_profile/'RESULT.json'),input_root=str(inputs),build_root=str(build),original_build_root=prior['build_root'],model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt','O2','--kernel-opt','O2','--output',str(build)]
  start=time.perf_counter();run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
  (a.output/'build.stdout').write_text(run.stdout);(a.output/'build.stderr').write_text(run.stderr);q['build']=dict(command=command,returncode=run.returncode,seconds=time.perf_counter()-start);save();run.check_returncode()
  meta,_=m.validate_bundle(build,a.reference_work,project);old=Path(prior['build_root']);oldmeta=json.loads((old/'BUILD.json').read_text())
  before={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in old.glob('*.f90')};after={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in build.glob('*.f90')}
  assert before==after;assert meta['identity']['donor_objects']==oldmeta['identity']['donor_objects']
  for field in ('donor_flags','kernel_flags'):assert meta['identity'][field]==oldmeta['identity'][field]
  q['identity_changes']=differences(oldmeta['identity'],meta['identity']);q['actual_BUILD_sha256']=m.sha(build/'BUILD.json')
  q['complete_Fortran']={name:m.hashlib.sha256(raw).hexdigest() for name,raw in after.items()}
  q['status']='ACTUAL_MONTHLY_COMPILED_FORTRAN_PROVIDER_FLAGS_POSTIMAGE_EXACT_PENDING_DESCRIPTOR_AND_ORIGINAL_EVIDENCE_AUDIT'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],q.get('identity_changes'),flush=True)


if __name__=='__main__':main()
