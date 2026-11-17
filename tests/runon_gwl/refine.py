"""Bounded original431 day-five temporal diagnostic; no production edits."""
from pathlib import Path
import csv,hashlib,json,re,shutil,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path('C:/SWAP5-testing/runon-gwl-first-divergence01')
OLD=Path('C:/SWAP5-testing/pondmx-canonical-audit01')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return list(csv.DictReader(s for s in p.read_text(encoding='cp1252').splitlines() if s and not s.startswith('*')))
def main():
 OUT.mkdir(exist_ok=False);result={'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'diagnostic_only':True,'tolerances_changed':False,'runs':{}}
 exe=Path('C:/SWAP5-RC2/provider/build/swap_b0_gfortran.exe');result['executable_sha256']=sha(exe)
 full=rows(OLD/'water-original431/result_output.csv');swap5=rows(OLD/'water-admitted-full/original/result_output.csv')
 for name,dt in [('nominal',None),('dt004',0.004),('dt0004',0.0004)]:
  case=OUT/name;shutil.copytree(OLD/'water-executed-inputs',case);p=case/'swap.swp';text=p.read_text(encoding='cp1252')
  text,n=re.subn(r'(?m)^(\s*TEND\s*=\s*)\d{4}-\d{2}-\d{2}',r'\g<1>2002-01-05',text);assert n==1
  if dt is not None:text,n=re.subn(r'(?m)^(\s*DTMAX\s*=\s*)[\d.]+',lambda m:m[1]+str(dt),text);assert n==1
  p.write_text(text,encoding='cp1252');inventory={x.name:sha(x) for x in case.iterdir() if x.is_file()};start=time.perf_counter()
  with (case/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=case,stdout=log,stderr=subprocess.STDOUT,timeout=20)
  data=rows(case/'result_output.csv') if (case/'result_output.csv').exists() else []
  entry=dict(command=[str(exe),'./swap.swp'],seconds=time.perf_counter()-start,returncode=r.returncode,swap_ok=(case/'swap.ok').exists(),inputs=inventory,rows=len(data),end=data[-1] if data else {},error=(case/'swap.err').read_text() if (case/'swap.err').exists() else '')
  result['runs'][name]=entry
  if data:
   entry['day5_GWL_delta_to_SWAP5_cm']=float(data[-1]['GWL'])-float(swap5[5]['GWL'])
   if dt is None:entry['all_short_rows_exact_to_immutable_full']=data==full[:6];assert entry['all_short_rows_exact_to_immutable_full']
  (OUT/'RESULT.json').write_text(json.dumps(result,indent=2));print(name,json.dumps({k:v for k,v in entry.items() if k not in ('inputs','end')}),{k:entry['end'].get(k) for k in ('GWL','WTOT','RUNOFF','DRN','IRRIG')},flush=True)
  assert entry['swap_ok'] and len(data)==6,entry['error']
if __name__=='__main__':main()
