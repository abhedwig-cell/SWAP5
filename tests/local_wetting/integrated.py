"""Reconcile the admitted chemical source at the real PR merge postimage."""
from pathlib import Path
import argparse,json,subprocess,sys,zipfile
from run import ROOT,m,POLICY
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);result={'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'canonical':'e67710244d84a9a37b30b76e853a3e5b0eeb55d2','tolerances_changed':False,'profiles':{}}
 # Heat uses the exact copied original input deck, not a new fixture generator.
 import shutil
 shutil.copytree(a.prior/'inputs',out/'inputs')
 for key in ('water-surface-history','chemical-surface-history'):
  project=m.e.load(out/'inputs'/key,time_step_policy=POLICY)
  for opt in ('O0','O2'):
   name=key+'-'+opt;old=a.prior/(name+'-build');build=out/(name+'-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(project.input_directory),'--experimental-time-step-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/(name+'.build-log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
   meta,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((old/'BUILD.json').read_text());generated={p.name:m.sha(p) for p in build.glob('*.f90')};oldgen={p.name:m.sha(p) for p in old.glob('*.f90')};changed=sorted(n for n in generated.keys()|oldgen.keys() if generated.get(n)!=oldgen.get(n));assert meta['inputs']==prior['inputs']
   closure=('donor_flags','kernel_flags','kernel_sources','adapter','driver','budget_source','lower_boundary_receipt','scheduled_pond_history','irrigation_pulse_time','local_wetting_time','time_step_policy','micro_lookup_state_policy','micro_lookup_state_source')
   assert all(meta['identity'].get(k)==prior['identity'].get(k) for k in closure)
   if key.startswith('water'):
    assert not changed;full=out/(name+'-prefix365');brief,data=m.trajectory(build,a.reference_work,project,full,365,{4,6,362,365},30);assert m.physical(data)==m.physical(m.rows(a.prior/(name+'-full'))[:365]);windows=((4,6),(362,365));inherited='EXACT_PHYSICAL_CLOSURE_FULL_NATIVE_HEAT_INHERITED'
   else:
    assert set(changed)<=set(['irrigation.f90','solute.f90','mod_subsurface_solute_source.f90']);full=out/(name+'-full');brief,data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,6,199,201,211,213,215,365,367,530,532,1094,1096},30);assert m.physical(data)==m.physical(m.rows(a.prior/(name+'-full')));assert m.csvlines(full/'original/result_output.csv')==m.csvlines(a.prior/(name+'-full/original/result_output.csv'));windows=((2,4),(4,6),(199,201),(211,213),(213,215),(365,367),(530,532),(1094,1096));inherited='FRESH_AFFECTED_FULL_AND_NATIVE_REQUIRED'
    for end in (4,6,201,213,215,367,532,1096):
     with zipfile.ZipFile(full/('accepted-column-1-day-'+str(end)+'.zip')) as x,zipfile.ZipFile(a.prior/(name+'-full')/('accepted-column-1-day-'+str(end)+'.zip')) as y:
      assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
   brief['own']=[m.own(build,a.reference_work,project,full,data,s,e,out/(name+'-own'+str(s))) for s,e in windows];result['profiles'][name]={'generated_sources':generated,'source_delta':changed,'closure_fields_exact':list(closure),'coverage':brief,'assessment':inherited,'physical_exact_to_prior':True};(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(name,'CURRENT_CANONICAL_COMPOSITION_PASS',flush=True)
 result['status']='MERGE_POSTIMAGE_ALL_SELECTED_PHYSICAL_NATIVE_PASS';(out/'RESULT.json').write_text(json.dumps(result,indent=2))
if __name__=='__main__':main()
