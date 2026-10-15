#!/usr/bin/env python3
"""Measured current-production root-growth contracts; synthetic water carrier is explicit."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,re,shutil,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 donor_path=ROOT/'tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90'
 donor=donor_path.read_text().split('\nprogram test_fwof34_accepted_window_runtime_lineage\n')[0]+'\n'
 # Reconcile the old single-water fixture with explicit mass completeness.
 donor=donor.replace('only: real64','only: real64,int64',1)
 donor=donor.replace('    procedure :: storage => fwof34_storage','    procedure :: storage_accounting_status => fixture_storage_status\n    procedure :: storage => fwof34_storage',1)
 donor=donor.replace('    outcome%mass_in = transfer_mass','    outcome%mass_accounting_complete = .true.\n    outcome%missing_mass_contribution_mask = 0\n    outcome%mass_in = transfer_mass',1)
 routine='''  subroutine fixture_storage_status(self,state,complete,missing_mask)
    class(fwof34_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    complete=.false.;missing_mask=1_int64
    if(self%scale<0d0)return
    select type(state)
    type is(fwof34_state_t)
      complete=.true.;missing_mask=0_int64
    end select
  end subroutine
'''
 donor=donor.replace('end module mod_fwof34_test_model',routine+'end module mod_fwof34_test_model')
 fixture=out/'fixture.f90';fixture.write_text(donor)
 lineage=out/'test_lineage.f90';lineage.write_text('program test_fwof34_accepted_window_runtime_lineage\n'+donor_path.read_text().split('\nprogram test_fwof34_accepted_window_runtime_lineage\n',1)[1])
 drivers=[ROOT/'tests/root-growth/test_root_growth_transaction.f90',ROOT/'tests/fmig431/test_swap431_root_growth_oxygen_composition.f90',ROOT/'tests/fmig431/test_swap431_root_supply_fail_closed.f90',ROOT/'tests/fmig431/test_swap431_potential_shadow_pre_event_restart.f90',ROOT/'tests/fmig431/test_swap431_potential_shadow_daily.f90']
 modules={}
 for p in sorted((ROOT/'src').rglob('*.f90'))+[fixture]:
  for n in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.M|re.I):
   if n.lower()in modules:raise ValueError('duplicate module '+n)
   modules[n.lower()]=p
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  if p in active:raise ValueError('cycle '+str(p))
  active.add(p)
  for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_intrinsic|intrinsic)\s*)?(?:::)?\s*(\w+)',p.read_text(),re.M|re.I):
   n=n.lower()
   if n in modules:visit(modules[n])
   elif n not in {'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}:raise ValueError('unresolved '+n)
  active.remove(p);seen.add(p);ordered.append(p)
 drivers.append(lineage)
 for d in drivers:visit(d)
 sources=[p for p in ordered if p not in drivers]
 inputs={str(p.relative_to(ROOT)):sha(p)for p in sources+drivers+[donor_path,Path(__file__).resolve()]if p.is_relative_to(ROOT)}
 events=[];runs=[];observations={};start=time.perf_counter()
 result={'status':'RUNNING','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'inputs':inputs,'provider_count':len(sources),'fixture_sha256':sha(fixture),'compiler':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],'scope':'Real root/crop transaction and accepted-window contracts, synthetic single-water carrier; not Richards/file-weather lifecycle admission'}
 def save():
  (out/'events.json').write_text(json.dumps(events,indent=2)+'\n');(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
 def run(cmd,cwd,category):
  t=time.perf_counter();p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True)
  stem=f'{len(events):04d}-{category}';(out/(stem+'.stdout')).write_bytes(p.stdout);(out/(stem+'.stderr')).write_bytes(p.stderr)
  events.append({'command':list(map(str,cmd)),'category':category,'seconds':time.perf_counter()-t,'returncode':p.returncode,'stdout':stem+'.stdout','stderr':stem+'.stderr','stdout_sha256':hashlib.sha256(p.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr).hexdigest()});save()
  if p.returncode:raise RuntimeError(p.stderr.decode(errors='replace')[-4000:]+p.stdout.decode(errors='replace')[-4000:])
  return p.stdout
 try:
  for opt in (0,2):
   b=out/f'O{opt}';b.mkdir();flags=['-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror','-Wno-error=compare-reals','-Wno-error=function-elimination','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
   objects=[]
   for i,src in enumerate(sources):
    obj=b/f'{i}.o';run(['gfortran',*flags,'-c',src,'-o',obj],b,'compile');objects.append(obj)
   for driver in drivers:
    exe=b/driver.stem;run(['gfortran',*flags,driver,*objects,'-o',exe],b,'link')
    for profile in (range(5)if driver==drivers[0]else [None]):
     output=run([exe]+([str(profile)]if profile is not None else []),b,'native')
     if b'PASS'not in output:raise ValueError('missing native assertions')
     if profile is not None and profile!=4:
      line=next(x for x in output.decode().splitlines()if x.startswith('ROOT_OBSERVATION '))
      observations[(opt,profile)]=[float(x)for x in line.split()[1:]]
     runs.append({'opt':opt,'driver':driver.name,'profile':profile,'stdout_sha256':hashlib.sha256(output).hexdigest()})
  for opt in (0,2):
   if len({(observations[(opt,k)][1],observations[(opt,k)][3])for k in range(4)})!=1:raise ValueError('actual oxygen changed potential owner')
   if observations[(opt,0)][0]>=observations[(opt,1)][0]:raise ValueError('no actual oxygen discrimination')
  for row in runs:
   other=[r for r in runs if r['opt']!=row['opt']and r['driver']==row['driver']and r['profile']==row['profile']]
   if len(other)!=1 or other[0]['stdout_sha256']!=row['stdout_sha256']:raise ValueError('optimization mismatch')
  if any(sha(ROOT/p)!=h for p,h in inputs.items()):raise ValueError('input changed')
  result.update(status='PASS',runs=runs,wall_seconds=time.perf_counter()-start,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native']})
 except Exception as e:
  result.update(status='FAIL',error=str(e),runs=runs,wall_seconds=time.perf_counter()-start);save();raise
 save();print(json.dumps(result,indent=2))
if __name__=='__main__':main()
