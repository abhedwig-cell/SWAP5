"""Selected aquifer-canonical composition: exact emitted closure and own replay.

The complete parent cohorts stay immutable. No replacement scientific criterion
or whole-period scientific PASS is inferred from these prefix checks.
"""
from pathlib import Path
import argparse,json,shutil,subprocess,sys,time
from run import ROOT,m,POLICY
from conserved_aquifer_solute import enabled

def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);shutil.copytree(a.prior/'inputs',out/'inputs')
 result=dict(source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),canonical='edbc66b9e2f9debee588db5763da960aee04b36c',profiles={},tolerances_changed=False,original_full_science='FAIL_PRESERVED',full_scientific_equivalence='NOT_CLAIMED')
 for key in ('water-surface-history','chemical-surface-history'):
  project=m.e.load(out/'inputs'/key,time_step_policy=POLICY)
  assert not enabled(project)
  for opt in ('O0','O2'):
   name=key+'-'+opt;build=out/(name+'-build');old=a.prior/(name+'-build')
   cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(project.input_directory),'--experimental-time-step-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
   start=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);seconds=time.perf_counter()-start;(out/(name+'.build-log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
   meta,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((old/'BUILD.json').read_text());assert meta['inputs']==prior['inputs']
   generated={f.name:m.sha(f) for f in build.glob('*.f90')};assert generated=={f.name:m.sha(f) for f in old.glob('*.f90')}
   # Host and input adapter changed; do not disguise their new identities. All
   # remaining persisted physical/build dependencies must remain exactly equal.
   changed=sorted(k for k in set(meta['identity'])|set(prior['identity']) if meta['identity'].get(k)!=prior['identity'].get(k))
   assert set(changed)<= {'host','experimental_input_adapter','restart_publisher'},changed
   assert 'conserved_aquifer_solute' not in meta['identity']
   parent=a.prior/(name+'-full')
   if not parent.exists():parent=a.prior/(name+'-prefix365')
   full=out/(name+'-prefix365');brief,data=m.trajectory(build,a.reference_work,project,full,365,{4,6,199,201,362,365},30)
   assert m.physical(data)==m.physical(m.rows(parent)[:365])
   brief['own']=[m.own(build,a.reference_work,project,full,data,s,e,out/(name+'-own'+str(s))) for s,e in ((4,6),(199,201),(362,365))]
   result['profiles'][name]=dict(build_command=cmd,build_seconds=seconds,generated_sources=generated,changed_identity_fields=changed,all_other_identity_fields_exact=True,aquifer_enabled=False,input_exact=True,prefix_physical_exact=True,coverage=brief,inherited='UNCHANGED_FULL_NATIVE_HEAT_AND_INDEPENDENT_REFERENCE_DEPENDENCIES')
   (out/'RESULT.json').write_text(json.dumps(result,indent=2));print(name,'ADMISSION_PREFIX_BALANCE_NATIVE_EXACT',flush=True)
 result['status']='SELECTED_CANONICAL_COMPOSITION_PASS';(out/'RESULT.json').write_text(json.dumps(result,indent=2))
if __name__=='__main__':main()
