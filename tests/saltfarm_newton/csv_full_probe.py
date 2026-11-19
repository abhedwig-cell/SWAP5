"""Private full control for CSV-only append candidate, no production bundle rebind."""
from pathlib import Path
import contextlib,json,shutil,subprocess,sys,zipfile
root=Path(__file__).resolve().parents[2];w=Path(r'C:\SWAP5-testing\saltfarm-step-cost04-full');w.mkdir(exist_ok=False)
frozen=Path(r'C:\SWAP5-testing\saltfarm-newton-cost03\source');sys.path[:0]=[str(frozen/'app/hybrid_water'),str(frozen/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
old=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\qualified-O2');ref=Path(r'C:\SWAP5-testing\rc3-local01\provider');gold=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\accept-O2\full');meta,case=validate_bundle(old,ref,h.SALTFARM)
b=w/'candidate';shutil.copytree(old,b);shutil.copyfile(r'C:\SWAP5-testing\saltfarm-step-cost04-csv\candidate-clock\swap_csv_output.f90',b/'swap_csv_output.f90')
commands=[]
cmd=['gfortran',*meta['identity']['donor_flags'],'-I',str(b),'-I',str(ref/'build/swap-obj'),'-I',str(ref/'build/ttutil-obj'),'-c','swap_csv_output.f90'];commands.append(cmd);r=subprocess.run(cmd,cwd=b,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
objects=[b/f.name if (b/f.name).exists() else f for f in sorted((ref/'build/swap-obj').glob('*.o'))];exe=b/'diagnostic.exe';cmd=['gfortran','-o',str(exe),*map(str,objects),str(b/'hybrid_step_budget.o'),str(ref/'build/ttutil-obj/libttutil.a')];commands.append(cmd);r=subprocess.run(cmd,cwd=b,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
(w/'COMMANDS.json').write_text(json.dumps(commands,indent=2));results=[]
for idx,mode in enumerate(('control','candidate','candidate','control')):
 folder=w/f'run{idx}-{mode}';folder.mkdir();data=[];donor=h.executable(old,'day_donor') if mode=='control' else exe;binding={**meta['binding'],'private_step_cost04_full':dict(mode=mode,csv=h.sha((old if mode=='control' else b)/'swap_csv_output.f90'))}
 def run():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,donor,h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
   with (folder/'daily.jsonl').open('w') as f:
    for day in range(1,1462):
     row=host.step(1,checkpoint=day in (109,111,365,367,453,455,1460,1461));assert row['committed'],(day,row);data.append(row);f.write(json.dumps(row)+'\n')
   host.close()
 _,elapsed=bounded(25,run);assert physical(data)==physical(rows(gold));assert csvlines(folder/'original/result_output.csv')==csvlines(gold/'original/result_output.csv');budget=check(data)
 for day in (109,111,365,367,453,455,1460,1461):
  with zipfile.ZipFile(folder/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(gold/f'accepted-column-1-day-{day}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 rec=dict(mode=mode,seconds=elapsed,days=1461,exact_physical_csv_eight_native=True,budgets=budget,folder=str(folder));results.append(rec);(w/'RESULT.json').write_text(json.dumps(results,indent=2));print(json.dumps(rec),flush=True)
# Actual cold workers spanning the initial, annual, difficult and terminal days.
folder=w/'run1-candidate';restarts=[];binding={**meta['binding'],'private_step_cost04_full':dict(mode='candidate',csv=h.sha(b/'swap_csv_output.f90'))}
for start,end in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
 origin=w/f'origin{start}-{end}';receipt=h.verify_checkpoint(folder/f'accepted-column-1-day-{start}.zip',start,binding,origin);dest=w/f'restart{start}-{end}';dest.mkdir()
 def resume():return h.run(exe,h.executable(old,'day_kernel'),case,dest,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
 r,elapsed=bounded(25,resume);assert r['first_refusal'] is None;actual=rows(dest);assert physical(actual)==physical(rows(folder)[start:end]);check(actual);assert csvlines(dest/'original/result_output.csv')[-(end-start):]==csvlines(folder/'original/result_output.csv')[start+2:end+2]
 with zipfile.ZipFile(dest/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(folder/f'accepted-column-1-day-{end}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 restarts.append(dict(start=start,end=end,seconds=elapsed,exact_physical_csv_native=True));(w/'RESTART.json').write_text(json.dumps(restarts,indent=2));print('COLD_EXACT',start,end,elapsed,flush=True)
