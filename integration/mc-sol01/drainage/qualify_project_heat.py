"""Native481-day heat/crop/detailed-rain composition through real owners."""
import argparse,csv,datetime,hashlib,json,math,os,re,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--composed-preservation',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=True);bundle=a.bundle.resolve();events=[];results={};sha=lambda b:hashlib.sha256(b).hexdigest();previous=[]
if(out/'events.json').exists():previous=json.loads((out/'events.json').read_text());(out/'initial-attempt-events.json').write_text(json.dumps(previous,indent=2))
case=out/'project';runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_cauchy3.py'))['fixture'](case);original=(case/'project.swp').read_text()
source=original.replace('SWHEA=0','SWHEA=1\nSWCALT=2\nSWTOPBHEA=1\nSWBOTBHEA=1').replace('SWREDU=2','SWREDU=0').replace('SWDRA=1','SWDRA=0').replace('SWBBCFILE=1','SWBBCFILE=0\nSWBOTB=2\nSW2=1\nSINAVE=0.\nSINAMP=0.\nSINMAX=0.').replace('SWDC=0','SWDC=1\nDECPOT=.001,.002\nGAMPAR=.05\nRTHETA=.3\nBEXP=1.\nFDEPTH=1.,1.')
source+='\nPSAND PSILT PCLAY ORGMAT\n.194 .529 .277 .021\n.157 .471 .372 .010\nTSOILTB=0.,5.,-40.,8.,-120.,12.\n'
common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',case/'project.swp','--bundle',bundle,'--native-hydraulics','--native-heat','--temporal-tolerance','.01','--solute-transport','implicit_upwind','--surface-exfiltration','historical_zero']
def run(cmd,label,ok=True):
 cached=next((e for e in previous if e['label']==label and e['command']==list(map(str,cmd))and(e['returncode']==0)==ok),None)
 if cached is not None:
  assert ok
  target=Path(cmd[cmd.index('--output')+1]);m=json.loads((target/'manifest.json').read_text());assert m['swp_sha256']==sha((case/'project.swp').read_bytes())
  assert m['executable_sha256']==sha(Path(json.loads((bundle/'bundle.json').read_text())['exe']).read_bytes())
  for f,h in m['files'].items():assert sha((target/f).read_bytes())==h
  events.append(cached);return
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,timeout=180)
 for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,expected_success=ok,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2));assert(r.returncode==0)==ok,(label,r.stderr.decode()[-2500:]);return r
rows=lambda p:list(csv.DictReader(p.open()))
expected={}
for path in sorted((case/'weather data').glob('History.*')):
 for line in path.read_text().splitlines():
  if line.startswith("'ANDE-M'"):
   x=line.split();day=datetime.date(int(x[3]),int(x[2]),int(x[1]));expected[day]=.5*(float(x[5])+float(x[6]))
expected=[v for d,v in sorted(expected.items())if datetime.date(1998,1,1)<=d<=datetime.date(1999,4,26)];assert len(expected)==481
for name,exponent in [('half','.5'),('double','2.')]:
 (case/'project.swp').write_text(source.replace('FREXP=.5','FREXP='+exponent));folder=out/name;folder.mkdir(exist_ok=True)
 for label,extra in [('full',[]),('split',['--stop-after','365']),('resumed',['--restart',folder/'split'])]:run(common+['--output',folder/label]+extra,name+'-'+label)
 fs=['state.csv','endpoint.csv','temperature.csv','restart.bin'];budget=rows(folder/'full/budget.csv');assert len(budget)==481 and budget[365:]==rows(folder/'resumed/budget.csv')
 for f in fs:assert(folder/'full'/f).read_bytes()==(folder/'resumed'/f).read_bytes(),(name,f)
 temps=[float(x['temperature_c'])for x in rows(folder/'full/temperature.csv')];assert len(temps)==12 and max(temps)-min(temps)>1e-5
 for row in budget:
  assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
  assert float(row['observed_heat_residual_j_cm2'])<=1e-9
  assert abs(float(row['potential_transpiration_cm'])-float(row['actual_transpiration_cm'])-float(row['drought_reduction_cm'])-float(row['oxygen_reduction_cm']))<1e-12
  independent=float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm']);assert abs(independent)<1e-10
 assert sum(float(r['actual_transpiration_cm'])for r in budget)>0 and sum(float(r['soil_evaporation_cm'])for r in budget)>0
 document=(folder/'full/input.nml').read_text();air=[float(x)for x in re.search(r'^ air_temperature_c=(.*)$',document,re.M)[1].split(',')];assert len(air)==len(expected)and all(abs(x-y)<=4*math.ulp(max(1.,abs(x),abs(y)))for x,y in zip(air,expected))
 results[name]=dict(budget=budget,air_temperature_c=air,files={f:sha((folder/'full'/f).read_bytes())for f in fs},temperature=temps)
 before={f.name:sha(f.read_bytes())for f in(folder/'split').iterdir()};weather=case/'weather data/History.998';raw=weather.read_bytes();weather.write_bytes(raw.replace(b'10.1',b'10.2',1));target=folder/'foreign-weather';run(common+['--restart',folder/'split','--output',target],name+'-foreign-weather',False);assert not target.exists();weather.write_bytes(raw);assert before=={f.name:sha(f.read_bytes())for f in(folder/'split').iterdir()}
results['half']['chemistry_differs_from_double']=results['half']['files']['state.csv']!=results['double']['files']['state.csv'];assert results['half']['chemistry_differs_from_double']
bad_boesten=source.replace('SWREDU=0','SWREDU=2')
if a.composed_preservation:bad_boesten=bad_boesten.replace('COFREDBO=0.79','COFREDBO=0.')
for name,text in [('analytic',source.replace('SWCALT=2','SWCALT=1')),('boesten',bad_boesten),('drainage',source.replace('SWDRA=0','SWDRA='+('2'if a.composed_preservation else'1'))),('wrong-heat',source.replace('SWHEA=1','SWHEA=0')),('bad-texture',source.replace('.194 .529 .277 .021','1.194 .529 .277 .021'))]:
 (case/'project.swp').write_text(text);target=out/('forbidden-'+name);run(common+['--output',target],name,False);assert not target.exists()
(case/'project.swp').write_text(source);target=out/'forbidden-picard';run(common+['--water-conductivity','picard']+(['--retain-step-proposal']if a.composed_preservation else[])+['--output',target],'picard',False);assert not target.exists()
meta=json.loads((bundle/'column/build-complete.json').read_text());inputs=dict(meta['input_sha256'])
for path in ['app/solute_crop/read_swp_project.f90','tools/solute/run_project.py','tools/solute/run_column.py','tools/solute/run_crop_daily.py','tests/nut-sol/qualify_native_cauchy3.py','integration/mc-sol01/drainage/qualify_project_heat.py']:inputs[path]=sha((ROOT/path).read_bytes())
record=dict(status='NATIVE_PROJECT_HEAT_CROP481_RESTART_PASS',events=events,results=results,input_sha256=inputs,complete_days=481,coupled_cases=2,fresh_process_restarts=2,source_nodes=12,rejected_processes=8,composed_preservation=a.composed_preservation,superseded_negative_selection='Boesten/drainage/Picard positive variants move to COMPOSED_HEAT qualification; invalid COFRED, extended drainage and Picard/proposal still reject.'if a.composed_preservation else None,energy_contract='Unchanged1e-9 J/cm2 process energy gate applies at every heat step. Observed residual is maximum of exposed last accepted step per rain segment, not a whole-day energy sum.',qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
