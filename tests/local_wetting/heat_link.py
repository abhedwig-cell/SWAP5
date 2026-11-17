"""Keep original numerical temperature object, observe across its call boundary."""
from pathlib import Path
import argparse,contextlib,json,shutil,subprocess,os
from run import ROOT,m,POLICY
from heat_receipts import read_accepted_heat
from heat import SOURCES

def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--days',type=int,default=586);p.add_argument('--profiles',nargs='+',default=['water-surface-history-O0']);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.reference_work/'build';result={'days':a.days,'profiles':{},'tolerances_changed':False,'full_energy_balance_complete':False}
 for name in a.profiles:
  key,opt=name.rsplit('-',1);original=a.prior/(name+'-build');build=out/(name+'-build');shutil.copytree(original,build);meta=json.loads((original/'BUILD.json').read_text());project=m.e.load(a.prior/'inputs'/key,time_step_policy=POLICY);commands=[]
  for source in [*[ROOT/v for v in SOURCES],ROOT/'tests/local_wetting/heat_link_observer.f90']:
   cmd=['gfortran','-'+opt,'-ffree-line-length-none','-ffp-contract=off','-fcheck=all','-I',str(build),'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-J',str(build),'-c',str(source)];commands.append(cmd);r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  objects=[build/x.name if (build/x.name).exists() else x for x in sorted((ref/'swap-obj').glob('*.o'))];exe=build/'heat_link.exe';cmd=['gfortran','-Wl,--wrap=__mod_soiltemperature_MOD_soiltemperature','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),*[str(build/(Path(v).stem+'.o')) for v in SOURCES],str(build/'heat_link_observer.o'),str(ref/'ttutil-obj/libttutil.a')];commands.append(cmd);r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  baseline=None;timings={}
  for mode in ('off','on'):
   os.environ['SWAP5_HEAT_OBSERVE']='1' if mode=='on' else '0'
   folder=out/(name+'-'+mode);folder.mkdir();data=[]
   def trial():
    with contextlib.ExitStack() as stack:
     binding={**meta['binding'],'heat_link_observer':{'wrapper':m.sha(ROOT/'tests/local_wetting/heat_link_observer.f90'),'exe':m.sha(exe)}}
     host=m.h.DailyHost(stack,exe,original/'day_kernel.exe',a.prior/'inputs'/key,folder,[m.h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=project.model,project=project)
     with (folder/'daily.jsonl').open('w') as journal:
      for day in range(1,a.days+1):
       row=host.step(1,checkpoint=day in {2,4,6,199,201,211,213,215,365,367,530,532,1094,1096});journal.write(json.dumps(row)+'\n');data.append(row);assert row['committed']
     host.close()
   _,timings[mode]=m.bounded(30,trial)
   if mode=='off':baseline=data;continue
   old=m.rows(a.prior/(name+'-full'))[:a.days];exact=m.physical(data)==m.physical(baseline);heat=read_accepted_heat(folder/'original/original-heat-summary.txt',data,project,compact=True);(folder/'HEAT.json').write_text(json.dumps(heat,indent=2))
   result['profiles'][name]=dict(seconds=timings,physical_on_off_exact=exact,first_on_off_difference=next((x['day'] for x,y in zip(data,baseline) if m.physical([x])!=m.physical([y])),None),first_old_binary_difference=next((x['day'] for x,y in zip(baseline,old) if m.physical([x])!=m.physical([y])),None),original_temperature_object_sha256=m.sha(ref/'swap-obj/temperature.o'),original_temperature_object_reused='temperature.o' not in [p.name for p in build.glob('*.o')],commands=commands,executable_sha256=m.sha(exe),accepted_heat_days=len(heat['daily']),maximum_cell_residual_j_cm2=max(v['cell_residual_max_j_cm2'] for v in heat['daily']),maximum_global_step_residual_j_cm2=max(v['global_step_residual_max_j_cm2'] for v in heat['daily']))
   (out/'RESULT.json').write_text(json.dumps(result,indent=2));print(name,exact,timings,flush=True);assert exact
if __name__=='__main__':main()
