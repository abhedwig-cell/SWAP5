"""Compile-only actual initial2 counterpart of a completed Snow9 period."""
import argparse,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_snow_source_inverse import complete_inverse,git,CORE
from explicit_bottom9_compiled_postimage import compare
from analytical_hydraulic_archives import SHA


def main():
 p=argparse.ArgumentParser()
 for name in ('profile','input','reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();complete_inverse();producer=git('rev-parse','HEAD').decode().strip();a.output.mkdir();q=json.loads((a.profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_EXPLICIT9_SNOW_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED'
 old=Path(q['build_root']);original=Path(q['input_root']);inventory=lambda root:{p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()}
 before,after=inventory(original),inventory(a.input);assert before.keys()==after.keys()
 for name,value in before.items():
  if name=='swap.swp':
   value,count=re.subn(br'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)1\b',lambda match:match[1]+b'2',value);assert count==1
  assert value==after[name],'Initial2 counterpart changes more than the one original initialization selector: '+name
 command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy','original-adaptive-day-seed-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',q['optimization'],'--kernel-opt',q['optimization'],'--output',str(a.build_root/'bundle')]
 with (a.output/'build.stdout').open('x') as stdout,(a.output/'build.stderr').open('x') as stderr:done=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
 done.check_returncode();assert git('rev-parse','HEAD').decode().strip()==producer,'Actual compile source HEAD moved during counterpart construction';build=a.build_root/'bundle';sources=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')}
 left,right=sources(old),sources(build);assert left.keys()==right.keys();observed=[]
 for name,path in sorted(left.items()):
  raw=path.read_bytes();new=right[name].read_bytes();assert raw.replace(b'\r\n',b'\n')==new.replace(b'\r\n',b'\n'),'Complete generated source differs: '+name
  observed.append(dict(file=name,actual_initial1_sha256=SHA(raw),actual_initial2_sha256=SHA(new)))
 compiled=compare(old,build)
 result=dict(status='ACTUAL_SNOW9_INITIAL2_COMPLETE_GENERATED_AND_COMPILED_POSTIMAGE_PASS_NO_MODEL_PERIOD',source=producer,actual_compiler_start_HEAD=producer,actual_compiler_end_HEAD=git('rev-parse','HEAD').decode().strip(),initial1_source=q['source'],composition_core=CORE,case=q['case'],optimization=q['optimization'],profile=str(a.profile),profile_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),build_root=str(build),input_root=str(a.input),input_inventory={k:SHA(v) for k,v in after.items()},actual_initial1_BUILD_sha256=SHA((old/'BUILD.json').read_bytes()),actual_initial2_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),generated_sources=observed,compiled=compiled,model_executions=0,canonical_admission=False)
 with (a.output/'RESULT.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
 print(result['status'],q['case'],q['optimization'])


if __name__=='__main__':main()
