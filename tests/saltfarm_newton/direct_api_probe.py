"""Actual direct-executor refusal and independent-context checks from preserved days."""
from pathlib import Path
import ctypes as c,json,math,sys
sys.path.insert(0,str(Path(__file__).resolve().parent));from direct_kernel_probe import Native
w=Path(r'C:\SWAP5-testing\saltfarm-guard-cost05\full');gold=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\accept-O2\full');data=[json.loads(s) for s in (gold/'daily.jsonl').read_text().splitlines()];origin=data[108];day=data[109];nodes=len(origin['pressure_head_cm']);epoch=40908.;results=[]
for opt in ('O0','O2'):
 contexts=[]
 try:
  for idx in range(2):
   log=(w/f'api-{opt}-{idx}-framingfix.log').open('w');n=Native(w/f'build-{opt}/direct.dll','HYBRID_SALTFARM_WATER',log);n.receive({'DAILY_MODEL'});n.write('2');state=[109,math.fsum(origin['stock_end_cm']),*origin['stock_end_cm'],*origin['pressure_head_cm']]
   for col in (1,2):n.write(f'{nodes} {epoch}');n.write(' '.join(map(str,state)))
   contexts.append((n,log))
  flow=day['external_flux_cm'];reply=[110,math.fsum(day['stock_end_cm']),math.fsum(flow[:7]),math.fsum(flow[7:]),flow[15]-flow[6],flow[15]-flow[6],*day['pressure_head_cm'],*day['stock_end_cm']]
  # terminal bottom is not the integrated exchange: use actual printed HYBRID_HYDRAULIC qbot.
  stdout=gold/'original/donor.stdout';hyd=[s.split() for s in stdout.read_text().splitlines() if s.startswith('HYBRID_HYDRAULIC')];reply[5]=-float(hyd[110][2])
  first=contexts[0][0];bad=reply.copy();bad[1]+=1
  arr=(c.c_double*len(bad))(*bad);out=(c.c_double*4)();status=c.c_int();first.lib.dk_apply(first.handle,1,110,len(bad),arr,out,c.byref(status));assert status.value==0 and out[0]==0 and out[3]==epoch+109 and abs(out[1])>1e-10
  # A distinct column and independently allocated context still commit actual day110 exactly.
  observed=[]
  for n,col in ((first,2),(contexts[1][0],1)):
   n.write(f'{col} 110');assert n.receive({'DAILY_REQUEST'})[0]=='DAILY_REQUEST';n.write(' '.join(map(str,reply)));key,record=n.receive({'DAILY_ACCEPTED'});assert float(record[key][3])==day['kernel_residual_cm'];observed.append(record[key])
  first.terminate();n=contexts[1][0];out2=(c.c_double*2)();n.lib.dk_request(n.handle,1,111,out2,c.byref(status));assert status.value==0 and out2[0]==epoch+110
  n.lib.dk_request(n.handle,1,110,out2,c.byref(status));assert status.value==-1
  result=dict(opt=opt,refusal_preserves_origin_and_revision=True,independent_columns_and_contexts=True,free_does_not_change_other_context=True,stale_day_refused=True);results.append(result);print(result)
 finally:
  for n,log in contexts:n.terminate();log.close()
(w/'API.json').write_text(json.dumps(results,indent=2))
