"""Full481-day4x detailed-rain discriminator; research only."""
import csv,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path('/tmp/perf01-historical-4x-v1');OUT.mkdir();SOURCE=Path('/tmp/perf01-historical-stages-v4/detailed');EXE=Path('/tmp/perf01-historical-current-v2/project')
r=dict(status='RUNNING',production_qualified=False,forcing_transformation='Multiply prepared daily rain and every detailed event rate by4; retain event endpoints, ET, crop, soils and seasonal bottom. Embedded original weather remains provenance, not transformed weather.',events=[],cases={})
def save():(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
for arm in ['head','flux']:
 d=OUT/arm;d.mkdir();text=(SOURCE/arm/'input.nml').read_text()
 for field in ['rain_cm_day','rain_rates']:
  def scale(m):return m[1]+','.join(format(4*float(v),'.17e')for v in m[2].split(','))
  text,n=re.subn(r'(?m)^( '+field+r'=)([^\n]+)',scale,text);assert n==1
 (d/'input.nml').write_text(text);(d/'input.swp').write_bytes((SOURCE/arm/'input.swp').read_bytes());start=time.perf_counter();cmd=[str(EXE),'input.nml','-','481','input.swp']
 try:p=subprocess.run(cmd,cwd=d,capture_output=True,timeout=120);code=p.returncode;out=p.stdout;err=p.stderr
 except subprocess.TimeoutExpired as e:code='TIMEOUT120';out=e.stdout or b'';err=e.stderr or b''
 (d/'stdout').write_bytes(out);(d/'stderr').write_bytes(err);event=dict(arm=arm,command=cmd,returncode=code,seconds=time.perf_counter()-start,exe_sha256=hashlib.sha256(EXE.read_bytes()).hexdigest());r['events'].append(event)
 rows=list(csv.DictReader((d/'budget.csv').open()))if(d/'budget.csv').exists()else[];event['completed_days']=len(rows)
 if code==0:
  assert len(rows)==481;event['max_water_residual_cm']=max(abs(float(v['water_residual_cm']))for v in rows);assert event['max_water_residual_cm']<1e-10
  assert all(float(v['solute_end_mg_cm2'])==0 for v in rows)
 r['cases'][arm]=event;save()
r['status']='RESEARCH_4X_COMPLETED'if all(c['returncode']==0 for c in r['cases'].values())else'RESEARCH_4X_EXECUTION_LIMIT';save();print(json.dumps(r,indent=2))
