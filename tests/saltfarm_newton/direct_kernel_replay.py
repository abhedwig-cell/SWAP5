"""Replay actual accepted data through each real kernel executor, isolating transport."""
from pathlib import Path
import contextlib,json,math,sys
root=Path(__file__).resolve().parents[2];source=Path(r'C:\SWAP5-testing\saltfarm-newton-cost03\source');sys.path[:0]=[str(source/'app/hybrid_water'),str(source/'tools/solute'),str(root/'tests/saltfarm_newton')]
import daily_host as h
from check_hupsel51_repair import bounded,rows
from direct_kernel_probe import install
w=Path(r'C:\SWAP5-testing\saltfarm-guard-cost05\kernel-replay');w.mkdir();full=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\accept-O2\full');old=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\qualified-O2');data=rows(full);hyd=[list(map(float,s.split()[1:])) for s in (full/'original/donor.stdout').read_text().splitlines() if s.startswith('HYBRID_HYDRAULIC')];initial=' '.join(map(str,[0,math.fsum(data[0]['stock_start_cm']),*data[0]['stock_start_cm'],*hyd[0][2:]]));replies=[]
for i,r in enumerate(data,1):
 f=r['external_flux_cm'];replies.append(' '.join(map(str,[i,math.fsum(r['stock_end_cm']),math.fsum(f[:7]),math.fsum(f[7:]),f[15]-f[6],-hyd[i][1],*r['pressure_head_cm'],*r['stock_end_cm']])))
baseline=(h.start_process,h.send,h.receive);result=[]
for idx,mode in enumerate(('pipe','direct','direct','pipe')):
 h.start_process,h.send,h.receive=baseline
 if mode=='direct':install(h,w.parent/'full/build-O2/direct.dll')
 dest=w/f'run{idx}-{mode}';dest.mkdir();receipts=[]
 def trial():
  with contextlib.ExitStack() as stack:
   host,log=h.start_process(stack,[h.executable(old,'day_kernel'),h.SALTFARM.model,'explicit-project'],dest,'kernel');h.receive(host,log,{'DAILY_MODEL'});h.send(host,'1');h.send(host,f'{h.SALTFARM.nodes} {h.SALTFARM.start_clock}');h.send(host,initial)
   for i,(r,reply) in enumerate(zip(data,replies),1):
    h.send(host,f'1 {i}');_,request=h.receive(host,log,{'DAILY_REQUEST'});assert list(map(float,request['DAILY_REQUEST']))==[1,i-1,h.SALTFARM.start_clock+i-1,h.SALTFARM.start_clock+i]
    h.send(host,reply);_,response=h.receive(host,log,{'DAILY_ACCEPTED'});v=list(map(float,response['DAILY_ACCEPTED']));assert v[:3]==[1,i,i] and v[3]==r['kernel_residual_cm'] and v[4]==r['bottom_outward_cm'];receipts.append(v)
   h.send(host,'0 0');host.wait(timeout=5)
 _,elapsed=bounded(10,trial);(dest/'receipts.json').write_text(json.dumps(receipts));result.append(dict(mode=mode,seconds=elapsed,days=1461,exact_actual_day_receipts=True));(w/'RESULT.json').write_text(json.dumps(result,indent=2));print(result[-1],flush=True)
