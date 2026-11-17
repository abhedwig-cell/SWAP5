"""Qualify actual R/pulse composition by exact emitted dependencies and native replay."""
from pathlib import Path
import argparse,json,subprocess,sys
from run import ROOT,m,POLICY
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 result=dict(status='INCOMPLETE',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),canonical_base='f0e5e39ea3d166755e394700a5a8765700eab875',profiles={},tolerances_changed=False,science='NOT_QUALIFIED')
 for key in ('water-surface-history','chemical-surface-history'):
  project=m.e.load(a.prior/'inputs'/key,time_step_policy=POLICY)
  for opt in ('O0','O2'):
   name=key+'-'+opt;old=a.prior/(name+'-build');build=out/(name+'-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(project.input_directory),'--experimental-time-step-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
   r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
   meta,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((old/'BUILD.json').read_text())
   same={p.name:m.sha(p) for p in build.glob('*.f90')};assert same=={p.name:m.sha(p) for p in old.glob('*.f90')}
   closure=('donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','adapter','driver','budget_source','lower_boundary_receipt','scheduled_pond_history','irrigation_pulse_time','local_wetting_time','time_step_policy')
   assert all(meta['identity'].get(k)==prior['identity'].get(k) for k in closure)
   assert meta['inputs']==prior['inputs']
   full=out/(name+'-prefix215');brief,data=m.trajectory(build,a.reference_work,project,full,215,{4,6,211,213,215},30)
   oldrows=m.rows(a.prior/(name+'-full'));assert m.physical(data)==m.physical(oldrows[:215])
   brief['own']=[m.own(build,a.reference_work,project,full,data,s,e,out/(name+'-own'+str(s))) for s,e in ((4,6),(211,213),(213,215))]
   result['profiles'][name]=dict(generated=same,closure_fields=list(closure),all_emitted_dependencies_and_inputs_exact=True,prefix_exact_to_qualified_full=True,prefix=brief,command=cmd)
   (out/'RESULT.json').write_text(json.dumps(result,indent=2));print(name,'COMPOSED_SOURCE_PREFIX_NATIVE_EXACT',flush=True)
 result['status']='ACTUAL_SCHEDULED_WETTING_COMPOSITION_GENERATED_INPUT_CLOSURE_AND_NATIVE_EXACT';(out/'RESULT.json').write_text(json.dumps(result,indent=2))
if __name__=='__main__':main()
