"""Private exact-current-source typed reply discriminator; never rebind a build."""
from pathlib import Path
import argparse,contextlib,ctypes as c,inspect,json,math,subprocess,sys,textwrap,time,zipfile
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from direct_day_kernel import NativeDayKernel
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--full',action='store_true');a=p.parse_args();a.work.mkdir(parents=True,exist_ok=False)
bundle=Path(r'C:\SWAP5-testing\saltfarm-guard-cost05\composition01\qualified-O2');reference=Path(r'C:\SWAP5-testing\rc3-local01\provider');gold=bundle.parent/'accept-O2/full';meta,case=validate_bundle(bundle,reference,h.SALTFARM)
original=h.DailyHost.step
assert not subprocess.check_output(['git','diff','b28706d8b16661d8a9e85339d317256eaca51206','--','app','src','reference','tools'],cwd=ROOT)
def typed_reply(process,values):
 if not isinstance(process,NativeDayKernel):return h.send(process,' '.join(map(str,values)))
 if process.cancelled:raise TimeoutError('Direct day kernel cancelled')
 if process.done or process.stage!=4:raise ValueError('Invalid typed reply lifecycle')
 if len(values)!=process.nodes+12:raise ValueError('Incomplete typed reply')
 reply=(c.c_double*len(values))(*values);result,status=(c.c_double*4)(),c.c_int()
 process.lib.dk_apply(process.handle,process.column,process.day,len(values),reply,result,c.byref(status));process.checked(status,(0,1))
 key='DAILY_ACCEPTED' if status.value==1 else 'DAILY_REFUSED'
 process.queue.append((key,list(map(str,[process.column,process.day,int(result[0]),result[1],result[2]]))));process.stage=3
namespace=dict(h.__dict__,typed_reply=typed_reply)
source=textwrap.dedent(inspect.getsource(original));needle='send(self.host, " ".join(map(str, reply)))';assert source.count(needle)==1
exec(source.replace(needle,'typed_reply(self.host,reply)'),namespace);candidate=namespace['step']
days=1461 if a.full else 365;results=[]
for i,mode in enumerate(('original','typed','typed','original')):
 h.DailyHost.step=candidate if mode=='typed' else original
 dest=a.work/f'run{i}-{mode}';dest.mkdir();data=[]
 binding={**meta['binding'],'private_typed_probe06':dict(mode=mode,recipe_sha256=h.sha(Path(__file__)))}
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,dest,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
   with (dest/'daily.jsonl').open('w') as journal:
    for day in range(1,days+1):
     row=host.step(1,checkpoint=day in (109,111,365,367,453,455,1460,1461));assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
   host.close()
 _,seconds=bounded(35 if a.full else 15,trial)
 assert physical(data)==physical(rows(gold)[:days]);check(data);assert csvlines(dest/'original/result_output.csv')==csvlines(gold/'original/result_output.csv')[:days+2]
 for day in (109,111,365,367,453,455,1460,1461):
  if day>days:continue
  with zipfile.ZipFile(dest/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(gold/f'accepted-column-1-day-{day}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 results.append(dict(mode=mode,seconds=seconds,days=days,physical_csv_native_exact=True,budgets=check(data)))
 (a.work/'RESULT.json').write_text(json.dumps(results,indent=2));print(json.dumps(results[-1]),flush=True)
h.DailyHost.step=original
if a.full:
 h.DailyHost.step=candidate;source=a.work/'run1-typed';restarts=[]
 for low,high in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
  binding={**meta['binding'],'private_typed_probe06':dict(mode='typed',recipe_sha256=h.sha(Path(__file__)))}
  checkpoint=source/f'accepted-column-1-day-{low}.zip';digest=h.sha(checkpoint);origin=a.work/f'origin{low}-{high}';receipt=h.verify_checkpoint(checkpoint,low,binding,origin);dest=a.work/f'restart{low}-{high}';dest.mkdir()
  def resume():return h.run(h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,dest,high,checkpoint_day=low,origin=origin,origin_receipt=receipt,runtime=True,publish_day=high,checkpoint_binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
  result,seconds=bounded(35,resume);assert result['first_refusal'] is None;assert physical(rows(dest))==physical(rows(source)[low:high]);check(rows(dest));assert csvlines(dest/'original/result_output.csv')[-(high-low):]==csvlines(source/'original/result_output.csv')[low+2:high+2];assert h.sha(checkpoint)==digest
  with zipfile.ZipFile(dest/f'accepted-column-1-day-{high}.zip') as x,zipfile.ZipFile(source/f'accepted-column-1-day-{high}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
  restarts.append(dict(start=low,end=high,seconds=seconds,physical_csv_native_exact=True,origin_unchanged=True));(a.work/'RESTART.json').write_text(json.dumps(restarts,indent=2))
 h.DailyHost.step=original
