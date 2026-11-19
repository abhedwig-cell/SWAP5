"""Private direct-kernel full controls; explicit unsupported bindings, unchanged donor."""
from pathlib import Path
import contextlib,hashlib,json,subprocess,sys,zipfile
root=Path(__file__).resolve().parents[2];w=Path(r'C:\SWAP5-testing\saltfarm-guard-cost05\full');w.mkdir();source=Path(r'C:\SWAP5-testing\saltfarm-newton-cost03\source');sys.path[:0]=[str(source/'app/hybrid_water'),str(source/'tools/solute'),str(root/'tests/saltfarm_newton')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
from direct_kernel_probe import install
ref=Path(r'C:\SWAP5-testing\rc3-local01\provider');base=Path(r'C:\SWAP5-testing\saltfarm-newton-close01');baseline=(h.start_process,h.send,h.receive);results=[];restarts=[];commands=[];builds={}
for opt in ('O0','O2'):
 old=base/f'qualified-{opt}';meta,case=validate_bundle(old,ref,h.SALTFARM);d=w/f'build-{opt}';d.mkdir();sources=[]
 for p,digest in meta['identity']['kernel_sources']:
  src=source/p;assert hashlib.sha256(src.read_bytes()).hexdigest()==digest;sources.append(str(src))
 dll=d/'direct.dll';cmd=['gfortran',*meta['identity']['kernel_flags'],'-shared',*sources,str(source/'app/hybrid_water/donor_adapter.f90'),str(root/'tests/saltfarm_newton/direct_kernel_probe.f90'),'-o',str(dll)];commands.append(cmd);r=subprocess.run(cmd,cwd=d,capture_output=True,text=True,timeout=60);(d/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr;builds[opt]=dll
(w/'COMMANDS.json').write_text(json.dumps(commands,indent=2))
for idx,(mode,opt) in enumerate((('pipe','O2'),('direct','O2'),('direct','O2'),('pipe','O2'),('direct','O0'))):
 h.start_process,h.send,h.receive=baseline
 if mode=='direct':install(h,builds[opt])
 old=base/f'qualified-{opt}';gold=base/f'accept-{opt}/full';meta,case=validate_bundle(old,ref,h.SALTFARM);folder=w/f'run{idx}-{mode}-{opt}';folder.mkdir();data=[];binding={**meta['binding'],'private_direct05':dict(mode=mode,library=hashlib.sha256(builds[opt].read_bytes()).hexdigest())}
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,h.executable(old,'day_donor'),h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
   with (folder/'daily.jsonl').open('w') as f:
    for day in range(1,1462):
     row=host.step(1,checkpoint=day in (109,111,365,367,453,455,1460,1461));assert row['committed'],(day,row);data.append(row);f.write(json.dumps(row)+'\n')
   host.close()
 _,seconds=bounded(25,trial);assert physical(data)==physical(rows(gold));assert csvlines(folder/'original/result_output.csv')==csvlines(gold/'original/result_output.csv');budget=check(data)
 for day in (109,111,365,367,453,455,1460,1461):
  with zipfile.ZipFile(folder/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(gold/f'accepted-column-1-day-{day}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 rec=dict(mode=mode,opt=opt,seconds=seconds,days=1461,exact_physical_csv_eight_native=True,budgets=budget,folder=str(folder));results.append(rec);(w/'RESULT.json').write_text(json.dumps(results,indent=2));print(json.dumps(rec),flush=True)
 # Each optimization gets one set of complete cold windows, not a repeat for timing.
 if (mode,opt,idx) not in (('direct','O2',1),('direct','O0',4)):continue
 for start,end in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
  origin=w/f'origin-{opt}-{start}-{end}';receipt=h.verify_checkpoint(folder/f'accepted-column-1-day-{start}.zip',start,binding,origin);dest=w/f'restart-{opt}-{start}-{end}';dest.mkdir()
  def resume():return h.run(h.executable(old,'day_donor'),h.executable(old,'day_kernel'),case,dest,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
  r,seconds=bounded(25,resume);assert r['first_refusal'] is None;actual=rows(dest);assert physical(actual)==physical(data[start:end]);check(actual);assert csvlines(dest/'original/result_output.csv')[-(end-start):]==csvlines(folder/'original/result_output.csv')[start+2:end+2]
  with zipfile.ZipFile(dest/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(folder/f'accepted-column-1-day-{end}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
  restarts.append(dict(opt=opt,start=start,end=end,seconds=seconds,exact_physical_csv_native=True));(w/'RESTART.json').write_text(json.dumps(restarts,indent=2));print('COLD_EXACT',opt,start,end,seconds,flush=True)
