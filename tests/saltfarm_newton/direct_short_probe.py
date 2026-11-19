from pathlib import Path
import contextlib,json,sys,zipfile
w=Path(r'C:\SWAP5-testing\saltfarm-guard-cost05\direct');source=Path(r'C:\SWAP5-testing\saltfarm-newton-cost03\source');sys.path[:0]=[str(source/'app/hybrid_water'),str(source/'tools/solute'),str(Path('tests/saltfarm_newton').resolve())]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
from direct_kernel_probe import install
ref=Path(r'C:\SWAP5-testing\rc3-local01\provider');old=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\qualified-O2');gold=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\accept-O2\full');meta,case=validate_bundle(old,ref,h.SALTFARM);baseline=(h.start_process,h.send,h.receive);results=json.loads((w/'RESULT.json').read_text())
for idx,mode in enumerate(('direct','direct','pipe'),start=len(results)):
 h.start_process,h.send,h.receive=baseline
 if mode=='direct':install(h,w/'direct.dll')
 folder=w/f'run{idx}-{mode}-loadfix';folder.mkdir();data=[];binding={**meta['binding'],'private_direct05':mode}
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,h.executable(old,'day_donor'),h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
   with (folder/'daily.jsonl').open('w') as f:
    for day in range(1,366):
     r=host.step(1,checkpoint=day in (109,111));assert r['committed'];data.append(r);f.write(json.dumps(r)+'\n')
   host.close()
 _,elapsed=bounded(15,trial);assert physical(data)==physical(rows(gold)[:365]);check(data);assert csvlines(folder/'original/result_output.csv')==csvlines(gold/'original/result_output.csv')[:367]
 with zipfile.ZipFile(folder/'accepted-column-1-day-109.zip') as x,zipfile.ZipFile(gold/'accepted-column-1-day-109.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 results.append(dict(mode=mode,seconds=elapsed,days=365,exact_physical_csv_native=True));(w/'RESULT.json').write_text(json.dumps(results,indent=2));print(results[-1],flush=True)
