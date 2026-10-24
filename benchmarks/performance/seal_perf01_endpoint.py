"""Seal separated4x causes and generated repairs without production admission."""
import csv,hashlib,io,itertools,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=ROOT/'benchmarks/performance';sha=lambda b:hashlib.sha256(b).hexdigest();read=lambda p:list(csv.DictReader(p.open()));result=dict(status='RESEARCH_FULL481_1X4X_COMPLETES_NOT_PRODUCTION_ADMITTED',production_changed=False,production_qualified=False,cases={})
for rain,folder in [(1,'perf01-endpoint-1x-v1'),(4,'perf01-endpoint-check-v1')]:
 p=Path('/tmp')/folder;record=json.loads((p/'RESULT.json').read_text());a,b=[read(p/('full481-'+arm)/'budget.csv')for arm in ['head','flux']];assert len(a)==len(b)==481
 case=dict(events=record['events'],metrics={})
 for k in ['runoff_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']:
  d=[10*(float(y[k])-float(x[k]))for x,y in zip(a,b)];case['metrics'][k]=dict(reference_total_mm=10*sum(float(x[k])for x in a),total_difference_mm=sum(d),max_daily_difference_mm=max(map(abs,d)),max_cumulative_difference_mm=max(map(abs,itertools.accumulate(d))))
 case['max_storage_difference_mm']=10*max(abs(float(y['water_end_cm'])-float(x['water_end_cm']))for x,y in zip(a,b));case['runoff_occurrence_changes']=[dict(day=i+1,reference_mm=10*float(x['runoff_cm']),candidate_mm=10*float(y['runoff_cm']))for i,(x,y)in enumerate(zip(a,b))if(float(x['runoff_cm'])>0)!=(float(y['runoff_cm'])>0)]
 case['strict_daily_runoff_screen_pass']=case['metrics']['runoff_cm']['max_daily_difference_mm']<.01
 for arm,rows in [('head',a),('flux',b)]:
  assert max(abs(float(v['water_residual_cm']))for v in rows)<1e-10
  closure=10*(float(rows[-1]['water_end_cm'])-float(rows[0]['water_start_cm'])-sum(float(v['water_in_cm'])-float(v['water_out_cm'])for v in rows));assert abs(closure)<1e-9;case[arm+'_period_water_closure_mm']=closure
 restart=json.loads(Path('/tmp/perf01-endpoint-restart'+str(rain)+'x-v1/RESULT.json').read_text());assert restart['status']=='ACTUAL_DAY240_RESTART_EXACT';case['restart']=restart;result['cases'][str(rain)]=case
identity={}
for case in ['first2','day146']:
 identity[case]={}
 for n in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
  a=(Path('/tmp/perf01-output-amount-endpoint-O0')/case/n).read_bytes();b=(Path('/tmp/perf01-output-amount-endpoint-O2')/case/n).read_bytes();assert a==b;identity[case][n]=sha(a)
result['O0_O2_identity']=identity
files={};folders=['perf01-isolate-4x-v1','perf01-isolate-4x-v2','perf01-isolate-4x-v3','perf01-output-amount-v1','perf01-historical-endpoint-v1','perf01-historical-endpoint-O0','perf01-output-amount-endpoint-O0','perf01-output-amount-endpoint-O2','perf01-endpoint-check-v1','perf01-endpoint-1x-v1','perf01-endpoint-restart1x-v1','perf01-endpoint-restart4x-v1']
for name in folders:
 for p in (Path('/tmp')/name).rglob('*'):
  if not p.is_file()or p.suffix in ['.o','.mod','.a']:continue
  b=p.read_bytes()
  if not b.startswith(b'\x7fELF'):files['raw/'+name+'/'+str(p.relative_to(Path('/tmp')/name))]=b
for name in ['isolate_perf01_4x.py','screen_perf01_geometry.py','screen_perf01_output_amount.py','screen_perf01_endpoint.py','check_perf01_historical_restart.py','seal_perf01_endpoint.py','PERF01_HISTORICAL_RESEARCH_20261024.md']:files['reproduce/'+name]=(HERE/name).read_bytes()
files['RESULT.json']=json.dumps(result,indent=2).encode();files['MANIFEST.json']=json.dumps({n:sha(b)for n,b in sorted(files.items())},indent=2).encode();target=HERE/'PERF01_ENDPOINT_20261024_EVIDENCE.tar.xz'
with tarfile.open(target,'w:xz')as t:
 for n,b in sorted(files.items()):m=tarfile.TarInfo(n);m.size=len(b);t.addfile(m,io.BytesIO(b))
with tarfile.open(target)as t:
 for n,h in json.load(t.extractfile('MANIFEST.json')).items():assert sha(t.extractfile(n).read())==h
result['evidence']=dict(path=str(target.relative_to(ROOT)),sha256=sha(target.read_bytes()),members=len(files));(HERE/'PERF01_ENDPOINT_20261024_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['evidence'])
