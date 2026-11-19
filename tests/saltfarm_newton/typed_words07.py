"""Exact C-ABI input bytes on every admitted Windows SaltFarm day; no donor run."""
from pathlib import Path
import argparse,ctypes as c,hashlib,json,math,struct,sys
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();result={}
for opt in ('O0','O2'):
 full=a.work/f'accept-{opt}/full';journal=full/'daily.jsonl';stdout=full/'original/donor.stdout';data=[json.loads(v) for v in journal.read_text().splitlines()];hyd=[list(map(float,v.split()[1:])) for v in stdout.read_text().splitlines() if v.startswith('HYBRID_HYDRAULIC')];assert len(data)==1461 and len(hyd)==1462;digest=hashlib.sha256();words=0
 for day,row in enumerate(data,1):
  flow=row['external_flux_cm'];values=[day,math.fsum(row['stock_end_cm']),math.fsum(flow[:7]),math.fsum(flow[7:]),flow[15]-flow[6],-hyd[day][1],*row['pressure_head_cm'],*row['stock_end_cm']]
  assert all(math.isfinite(v) for v in values)
  direct=bytes((c.c_double*len(values))(*values));old=bytes((c.c_double*len(values))(*map(float,' '.join(map(str,values)).split())));assert direct==old;digest.update(direct);words+=len(values)
 result[opt]=dict(days=1461,actual_reply_words=words,all_actual_c_abi_bytes_exact=True,reply_stream_sha256=digest.hexdigest(),journal_sha256=hashlib.sha256(journal.read_bytes()).hexdigest(),hydraulic_stdout_sha256=hashlib.sha256(stdout.read_bytes()).hexdigest(),scope='Exact complete admitted Windows trajectories, not a fresh Windows public-build model run')
for value in (0.,-0.,sys.float_info.max,-sys.float_info.max,sys.float_info.min,-sys.float_info.min,math.ulp(0.),-math.ulp(0.)):
 assert struct.pack('d',value)==struct.pack('d',float(str(value)))
(a.work/'TYPED_WORDS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
