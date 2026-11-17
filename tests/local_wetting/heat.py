"""Reuse the existing read-only original numerical heat observer, no energy invention."""
from pathlib import Path
import argparse,ast,contextlib,json,re,shutil,subprocess
from run import ROOT,m,POLICY
from heat_receipts import read_accepted_heat
SOURCES=['src/process/mod_linear_mixture_sensible_storage.f90','src/kernel/mod_energy_conservation_types.f90','src/process/mod_whole_column_sensible_energy_accounting.f90','app/hybrid_water/heat_accounting.f90']
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();ref=a.reference_work/'build'
 # Reuse precisely the admitted observer function, not its archived runner/setup.
 recipe='research/hybrid-water01/qualify_original_heat_accounting.py';body=subprocess.check_output(['git','show','HEAD:'+recipe],cwd=ROOT,text=True);node=next(n for n in ast.parse(body).body if isinstance(n,ast.FunctionDef) and n.name=='instrument');ns={};exec(compile(ast.Module(body=[node],type_ignores=[]),recipe,'exec'),ns)
 result=dict(kind='SUPPORTED_ORIGINAL_NUMERICAL_CONDUCTION_ONLY',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),observer_git_blob=subprocess.check_output(['git','rev-parse','HEAD:'+recipe],cwd=ROOT,text=True).strip(),energy_budget_j_cm2=1e-9,full_energy_balance_complete=False,profiles={})
 for key in ('water-surface-history','chemical-surface-history'):
  project=m.e.load(out/'inputs'/key,time_step_policy=POLICY)
  for opt in ('O0','O2'):
   name=key+'-'+opt;original=out/(name+'-build');build=out/(name+'-heat2-build');shutil.copytree(original,build);meta=json.loads((original/'BUILD.json').read_text());commands=[]
   def execute(cmd):
    commands.append(list(map(str,cmd)));r=subprocess.run(commands[-1],cwd=build,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
   for src in SOURCES:execute(['gfortran','-O2','-ffree-line-length-none','-fcheck=all','-I',build,'-J',build,'-c',ROOT/src])
   raw=(ref/'swap-selected/temperature.f90').read_text(encoding='cp1252');observed=ns['instrument'](raw).replace('audit_solid(1:numnod),audit_face(1:numnod+1))','audit_solid(1:numnod),audit_face(1:numnod+1),detailed=.false.)');assert re.sub(r'! BEGIN HEAT OBSERVATION\n.*?! END HEAT OBSERVATION\n','',observed,flags=re.S)==raw
   src=build/'temperature.f90';src.write_text(observed,encoding='cp1252');flags=['-O2',*meta['identity']['donor_flags'][1:]];execute(['gfortran',*flags,'-I',build,'-I',ref/'swap-obj','-I',ref/'ttutil-obj','-c',src]);exe=build/'heat_observed_donor.exe'
   objects=[build/x.name if (build/x.name).exists() else x for x in sorted((ref/'swap-obj').glob('*.o'))];execute(['gfortran','-o',exe,*objects,build/'hybrid_step_budget.o',*[build/(Path(s).stem+'.o') for s in SOURCES],ref/'ttutil-obj/libttutil.a'])
   folder=out/(name+'-heat2');folder.mkdir();data=[]
   def trial():
    with contextlib.ExitStack() as stack:
     binding={**meta['binding'],'heat_observation':{'temperature_source_sha256':m.sha(src),'accounting_sources':{v:m.sha(ROOT/v) for v in SOURCES}}}
     host=m.h.DailyHost(stack,exe,original/'day_kernel.exe',out/'inputs'/key,folder,[m.h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=project.model,project=project)
     with (folder/'daily.jsonl').open('w') as journal:
      for day in range(1,1097):
       row=host.step(1,checkpoint=day in {2,4,6,199,201,211,213,215,365,367,530,532,1094,1096});data.append(row);journal.write(json.dumps(row)+'\n');assert row['committed']
     host.close()
   _,seconds=m.bounded(30,trial);assert m.physical(data)==m.physical(m.rows(out/(name+'-full')))
   report=read_accepted_heat(folder/'original/original-heat-accounting.txt',data,project,compact=True);assert len(report['daily'])==1096 and not report['full_energy_balance_complete']
   result['profiles'][name]=dict(seconds=seconds,physical_daily_exact=True,commands=commands,observer_source_sha256=m.sha(src),executable_sha256=m.sha(exe),accepted_days=1096,maximum_cell_residual_j_cm2=max(v['cell_residual_max_j_cm2'] for v in report['daily']),maximum_global_step_residual_j_cm2=max(v['global_step_residual_max_j_cm2'] for v in report['daily']),full_energy_balance_complete=False)
   (folder/'HEAT.json').write_text(json.dumps(report,indent=2));(out/'HEAT.json').write_text(json.dumps(result,indent=2));print(name,'FULL_SUPPORTED_CONDUCTION_UNCHANGED_LIMIT_PASS',flush=True)
if __name__=='__main__':main()
