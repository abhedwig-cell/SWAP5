"""Seal rejected refinements; preserve original candidate and failure evidence."""
import hashlib,io,json,tarfile,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=ROOT/'benchmarks/performance';sha=lambda b:hashlib.sha256(b).hexdigest();js=lambda p:json.loads(Path(p).read_text());r=dict(status='REFINEMENTS_NOT_SELECTED_NO_PRODUCTION_ADMISSION',production_changed=False,production_qualified=False,baseline='e3347ac5e46fa077a28e2261da2771ee35e4a4ed',output_only=js('/tmp/perf01-amount-refinement/RESULT.json'),storage_only=js('/tmp/perf01-state-refinement/RESULT.json'))
for case in ['first2','day146']:
 for n in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert(Path('/tmp/perf01-output-tight-O0')/case/n).read_bytes()==(Path('/tmp/perf01-output-tight-O2')/case/n).read_bytes()
r['selected_output_only_O0_O2']='BYTE_EXACT';r['restarts']={str(n):js('/tmp/perf01-tight-restart'+str(n)+'/RESULT.json')for n in [1,4]};assert all(v['status']=='ACTUAL_DAY240_RESTART_EXACT'for v in r['restarts'].values())
assert r['output_only']['cases']['4']['metrics']['runoff_cm']['max_daily_mm']>.63
assert r['storage_only']['events'][-1]['returncode']!=0
files={}
for folder in ['perf01-output-tight-O2','perf01-output-tight-O0','perf01-amount-refinement','perf01-state-tight-O2','perf01-state-refinement','perf01-tight-restart1','perf01-tight-restart4']:
 for p in (Path('/tmp')/folder).rglob('*'):
  if not p.is_file()or p.suffix in ['.o','.mod','.a']:continue
  b=p.read_bytes()
  if not b.startswith(b'\x7fELF'):files['raw/'+folder+'/'+str(p.relative_to(Path('/tmp')/folder))]=b
for n in ['screen_perf01_output_amount.py','screen_perf01_amount_refinement.py','seal_perf01_refinement.py','check_perf01_historical_restart.py','PERF01_HISTORICAL_RESEARCH_20261024.md']:files['reproduce/'+n]=(HERE/n).read_bytes()
files['RESULT.json']=json.dumps(r,indent=2).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2).encode();target=HERE/'PERF01_REFINEMENT_20261024_EVIDENCE.tar.xz'
with tarfile.open(target,'w:xz')as t:
 for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);t.addfile(m,io.BytesIO(b))
with tarfile.open(target)as t:
 for p,h in json.load(t.extractfile('MANIFEST.json')).items():assert sha(t.extractfile(p).read())==h
r['evidence']=dict(path=str(target.relative_to(ROOT)),sha256=sha(target.read_bytes()),members=len(files));(HERE/'PERF01_REFINEMENT_20261024_RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(r['evidence'])
