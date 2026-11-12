"""Replay the exact generated worker without SWAP5 scheduling; no physics change.

Same execution-input bytes, preloaded original day calls, unchanged native worker,
full stdout retained. Exact physical receipts and original CSV establish whether
host state transfer rather than the generated original block causes a difference.
"""
import argparse,ctypes,json,os,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True);p.add_argument('--full',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();meta=json.loads((a.bundle/'BUILD.json').read_text())
case=a.output/'case';case.mkdir()
for name in meta['inputs']:
 (case/name).parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(a.full/'original'/name,case/name)
rows=[json.loads(s) for s in (a.full/'daily.jsonl').read_text().splitlines()];last=rows[-1]['day']
command=[str(a.bundle.resolve()/('day_donor.exe' if os.name=='nt' else 'day_donor')),'./swap.swp']
payload=''.join(f'{day} -1\n' for day in range(1,last+1))+'0 -1\n'
beg=time.perf_counter()
with (a.output/'stdout').open('wb') as stdout,(a.output/'stderr').open('wb') as stderr:
 with subprocess.Popen(command,cwd=case,stdin=subprocess.PIPE,stdout=stdout,stderr=stderr) as process:
  process.communicate(payload.encode(),timeout=60)
 seconds=time.perf_counter()-beg
 assert process.returncode==100
receipts=[];values={}
for line in (a.output/'stdout').read_text(encoding='cp1252').splitlines():
 key,_,text=line.strip().partition(' ')
 if key.startswith('HYBRID_'):values[key]=text.split()
 if key=='HYBRID_DAY_RETURN':
  r=rows[len(receipts)];stocks=list(map(float,values['HYBRID_STOCK_FLUX']));flux=list(map(float,values['HYBRID_EXTERNAL_FLUX']));hydraulic=list(map(float,values['HYBRID_HYDRAULIC']))
  assert int(values[key][0])==r['day']
  assert stocks[:6]==r['stock_end_cm'] and stocks[6:]==r['stock_start_cm']
  assert flux==r['external_flux_cm'] and hydraulic[2:]==r['pressure_head_cm'] and hydraulic[0]==r['groundwater_cm']
  if 'solute_ledger_mg_cm2' in r:
   assert list(map(float,values['HYBRID_SOLUTE_LEDGER']))==r['solute_ledger_mg_cm2']
   assert list(map(float,values['HYBRID_UPTAKE']))==r['uptake_terms_cm']
  receipts.append(r['day'])
assert len(receipts)==last
records=lambda q:[s for s in q.read_text().splitlines() if s.strip() and not s.startswith('*')]
assert records(case/'result_output.csv')==records(a.full/'original/result_output.csv')
result=dict(days=last,wall_seconds=seconds,exact_unrounded_physical_receipts=True,exact_original_csv=True,
 interpretation='New daily host scheduling/state transfer excluded as cause of baseline-versus-current numeric differences for this selected full trajectory; generated corrected original worker alone reproduces them.')
if os.name=='nt':
 from ctypes import wintypes
 c,e,k,u=(wintypes.FILETIME() for _ in range(4));get=ctypes.windll.kernel32.GetProcessTimes;get.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)];get.restype=wintypes.BOOL
 assert get(int(process._handle),ctypes.byref(c),ctypes.byref(e),ctypes.byref(k),ctypes.byref(u))
 sec=lambda v:((v.dwHighDateTime<<32)+v.dwLowDateTime)/1e7
 result['worker_cpu_user_seconds']=sec(u);result['worker_cpu_system_seconds']=sec(k)
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
