"""Actual typed/text ABI equality, refusal atomicity, cancellation and ownership."""
from pathlib import Path
import argparse,contextlib,ctypes as c,io,json,math,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from direct_day_kernel import NativeDayKernel,library_path
import daily_host as h
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();result={}
for opt in ('O0','O2'):
 full=a.work/f'accept-{opt}/full';data=[json.loads(x) for x in (full/'daily.jsonl').read_text().splitlines()];old,day=data[108:110];hyd=[list(map(float,x.split()[1:])) for x in (full/'original/donor.stdout').read_text().splitlines() if x.startswith('HYBRID_HYDRAULIC')];f=day['external_flux_cm'];reply=[110,math.fsum(day['stock_end_cm']),math.fsum(f[:7]),math.fsum(f[7:]),f[15]-f[6],-hyd[110][1],*day['pressure_head_cm'],*day['stock_end_cm']]
 def start():
  n=NativeDayKernel(library_path(a.work/f'qualified-{opt}'),h.SALTFARM.model,io.StringIO());n.receive({'DAILY_MODEL'});n.write('2')
  for _ in (1,2):n.write(f'{h.SALTFARM.nodes} {h.SALTFARM.start_clock}');n.write(' '.join(map(str,[109,math.fsum(old['stock_end_cm']),*old['stock_end_cm'],*old['pressure_head_cm']])))
  return n
 with contextlib.ExitStack() as stack:
  typed,text,cancelled,clock=(start() for _ in range(4))
  for n in (typed,text,cancelled,clock):stack.callback(n.terminate)
  for n in (typed,text):
   try:n.submit(reply)
   except ValueError:pass
   else:raise AssertionError('Unrequested typed reply accepted')
   n.write('1 110');n.receive({'DAILY_REQUEST'})
  try:typed.submit(reply[:-1])
  except ValueError:pass
  else:raise AssertionError('Short typed reply accepted')
  typed.submit(reply);text.write(' '.join(map(str,reply)));actual=typed.receive({'DAILY_ACCEPTED'});assert actual==text.receive({'DAILY_ACCEPTED'})
  assert list(map(float,actual[1]['DAILY_ACCEPTED']))[:3]==[1,110,1]
  try:typed.write('1 110')
  except RuntimeError:pass
  else:raise AssertionError('Stale day accepted')
  typed.write('2 110');typed.receive({'DAILY_REQUEST'});bad=reply.copy();bad[1]+=1;typed.submit(bad);key,v=typed.receive({'DAILY_REFUSED'});assert float(v[key][2])==0
  # The text receipt's last field is bottom exchange, not accepted time.
  # Read the actual unchanged backend's fourth ABI value on an independent
  # rejected context to prove its clock/revision rollback directly.
  clock.write('1 110');clock.receive({'DAILY_REQUEST'});out,status=(c.c_double*4)(),c.c_int();arr=(c.c_double*len(bad))(*bad)
  clock.lib.dk_apply(clock.handle,1,110,len(bad),arr,out,c.byref(status));assert status.value==0 and out[0]==0 and out[3]==h.SALTFARM.start_clock+109
  cancelled.write('1 110');cancelled.receive({'DAILY_REQUEST'});cancelled.kill()
  try:cancelled.submit(reply)
  except TimeoutError:pass
  else:raise AssertionError('Cancelled typed reply accepted')
  typed.terminate()
  try:typed.submit(reply)
  except ValueError:pass
  else:raise AssertionError('Freed context accepted')
  text.write('2 110');text.receive({'DAILY_REQUEST'});text.submit(reply);key,v=text.receive({'DAILY_ACCEPTED'});assert int(v[key][0])==2 and v[key][1:]==actual[1][actual[0]][1:]
 result[opt]=dict(typed_text_exact=True,wrong_stage_refused=True,wrong_shape_does_not_consume_request=True,mass_refusal_keeps_revision_and_backend_clock=True,stale_day_refused=True,cancellation_refused=True,freed_context_refused=True,independent_columns_and_contexts=True,free_other_context_safe=True)
(a.work/'TYPED_API.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
