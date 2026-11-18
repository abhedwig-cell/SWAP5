"""Private bounded stopping discriminator; never changes a release bundle."""
from pathlib import Path
import argparse,contextlib,json,shutil,subprocess,sys,zipfile
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--mode',choices=['none','interior'],required=True);p.add_argument('--days',type=int,default=365);a=p.parse_args()
sys.path[:0]=[str(a.source/'app/hybrid_water'),str(a.source/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.qualification/'provider';old=a.qualification/'saltfarm-O2-candidate-build';meta,case=validate_bundle(old,ref,h.SALTFARM);build=out/'build';shutil.copytree(old,build)
src=(old/'headcalc.f90').read_text(encoding='cp1252');anchor='if (.not.flnonconv .and. mass_polish_at==0) then';assert src.count(anchor)==1
condition='.false.' if a.mode=='none' else 'abs(budget_total+budget_step)>0.5d0*1d-10*(t1900-budget_start+dt)'
src=src.replace(anchor,'if (.not.flnonconv .and. mass_polish_at==0 .and. '+condition+') then');(build/'headcalc.f90').write_text(src,encoding='cp1252')
cmd=['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(ref/'build/swap-obj'),'-I',str(ref/'build/ttutil-obj'),'-c','headcalc.f90'];commands=[cmd];r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
exe=build/'probe.exe';objects=[build/f.name if (build/f.name).exists() else f for f in sorted((ref/'build/swap-obj').glob('*.o'))];cmd=['gfortran','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(ref/'build/ttutil-obj/libttutil.a')];commands.append(cmd);r=subprocess.run(cmd,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
binding={**meta['binding'],'private_newton_policy':a.mode,'headcalc':h.sha(build/'headcalc.f90')};folder=out/'run';folder.mkdir();data=[]
def trial():
 with contextlib.ExitStack() as stack:
  host=h.DailyHost(stack,exe,h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
  with (folder/'daily.jsonl').open('w') as journal:
   for day in range(1,a.days+1):
    row=host.step(1,checkpoint=day in (109,111,a.days));data.append(row);journal.write(json.dumps(row)+'\n');journal.flush()
    if not row['committed']:raise ValueError('Day refused: '+str(day)+' '+str(row))
  host.close()
result=dict(mode=a.mode,requested_days=a.days,commands=commands,source_sha=h.sha(build/'headcalc.f90'))
try:
 _,seconds=bounded(20,trial);result.update(status='PASS',seconds=seconds,budgets=check(data))
 if a.days>=111:
  origin=out/'origin109';receipt=h.verify_checkpoint(folder/'accepted-column-1-day-109.zip',109,binding,origin);restart=out/'restart109';restart.mkdir()
  def resume():return h.run(exe,h.executable(old,'day_kernel'),case,restart,111,checkpoint_day=109,origin=origin,origin_receipt=receipt,runtime=True,publish_day=111,checkpoint_binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
  continuation,elapsed=bounded(20,resume);assert continuation['first_refusal'] is None;assert physical(rows(restart))==physical(data[109:111]);assert csvlines(restart/'original/result_output.csv')[-2:]==csvlines(folder/'original/result_output.csv')[111:113]
  with zipfile.ZipFile(restart/'accepted-column-1-day-111.zip') as x,zipfile.ZipFile(folder/'accepted-column-1-day-111.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
  result['exact_restart109_111']=True
except Exception as ex:result.update(status='FAIL',error=repr(ex),completed_days=len(data))
(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='commands'},indent=2))
