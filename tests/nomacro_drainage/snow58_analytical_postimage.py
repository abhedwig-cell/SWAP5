"""Actual opposite initial-state compiled counterpart, without a model period."""
import argparse,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from snow58_analytical_source import complete_inverse,git,CORE
from explicit_bottom9_compiled_postimage import compare
from analytical_hydraulic_archives import SHA
import experimental_project


def main():
 p=argparse.ArgumentParser()
 for name in ('profile','reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();complete_inverse();head=git('rev-parse','HEAD').decode().strip();a.output.mkdir()
 q=json.loads((a.profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_SNOW58_ANALYTICAL_PHYSICAL_NATIVE_COLD_PREFLIGHT_PASS_NOT_ADMITTED' and q['days']==35
 assert not git('diff',q['source'],head,'--','app','src','tools','reference')
 original=Path(q['input_root']);inputs=a.output/'input';inputs.mkdir();inventory={};old_initial=None;new_initial=None
 for path in sorted(original.iterdir()):
  if not path.is_file():continue
  raw=path.read_bytes()
  if path.name=='swap.swp':
   values=re.findall(rb'(?mi)^[ \t]*SWINCO[ \t]*=[ \t]*([12])\b',raw);assert len(values)==1;old_initial=int(values[0]);new_initial=3-old_initial
   raw,count=re.subn(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)[12]\b',lambda m:m[1]+str(new_initial).encode(),raw);assert count==1
  (inputs/path.name).write_bytes(raw);inventory[path.name]=SHA(raw)
 assert len(inventory)==10 and old_initial in (1,2)
 project=experimental_project.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');bundle=a.build_root/'bundle'
 command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',q['optimization'],'--kernel-opt',q['optimization'],'--output',str(bundle)]
 with (a.output/'build.stdout').open('x') as out,(a.output/'build.stderr').open('x') as err:r=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300)
 r.check_returncode();assert git('rev-parse','HEAD').decode().strip()==head
 files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')}
 old=Path(q['build_root']);left,right=files(old),files(bundle);assert left.keys()==right.keys();sources=[]
 for name,path in sorted(left.items()):
  a_raw,b_raw=path.read_bytes(),right[name].read_bytes();assert a_raw.replace(b'\r\n',b'\n')==b_raw.replace(b'\r\n',b'\n'),'Changed complete generated source '+name;sources.append(dict(file=name,original_sha256=SHA(a_raw),counterpart_sha256=SHA(b_raw)))
 compiled=compare(old,bundle)
 result=dict(status='ACTUAL_SNOW58_OPPOSITE_INITIALIZATION_WHOLE_GENERATED_COMPILED_POSTIMAGE_PASS_NO_MODEL_PERIOD',source=head,actual_compiler_start_HEAD=head,actual_compiler_end_HEAD=git('rev-parse','HEAD').decode().strip(),original_producer=q['source'],original_initialization=old_initial,counterpart_initialization=new_initial,profile=str(a.profile),profile_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),input_root=str(inputs),input_inventory=inventory,build_root=str(bundle),actual_original_BUILD_sha256=SHA((old/'BUILD.json').read_bytes()),actual_counterpart_BUILD_sha256=SHA((bundle/'BUILD.json').read_bytes()),generated_sources=sources,compiled=compiled,model_executions=0,canonical_admission=False)
 (a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],old_initial,new_initial)


if __name__=='__main__':main()
