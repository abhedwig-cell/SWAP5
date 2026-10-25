"""Real native project bootstrap/BBC/drainage/crop qualification and preservation."""
import argparse,csv,hashlib,json,os,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--baseline-bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
out=a.output.resolve();out.mkdir(exist_ok=True);bundle=a.bundle.resolve();base=a.baseline_bundle.resolve();events=[];results={};sha=lambda b:hashlib.sha256(b).hexdigest()
previous=[]
if(out/'events.json').exists():
 previous=json.loads((out/'events.json').read_text());(out/'initial-attempt-events.json').write_text(json.dumps(previous,indent=2));previous=[e for e in previous if e['returncode']==0 or not e['expected_success']]
fixture=runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_cauchy3.py'))['fixture'];case=out/'project';fixture(case);original=(case/'project.swp').read_text()
common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',case/'project.swp','--bundle',bundle,'--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
def run(cmd,label,ok=True):
 cached=next((e for e in previous if e['label']==label and e['command']==list(map(str,cmd)) and e['expected_success']==ok),None)
 if cached is not None:
  # Reuse completed unchanged physical invocations from the failed active trial.
  # Compare all staged source/executable bindings before accepting raw artifacts.
  if ok:
   target=Path(cmd[cmd.index('--output')+1]);m=json.loads((target/'manifest.json').read_text())
   assert m['executable_sha256']==sha(Path(json.loads((bundle/'bundle.json').read_text())['exe']).read_bytes())
   assert m['swp_sha256']==sha((case/'project.swp').read_bytes())
   for name,h in m['files'].items():assert sha((target/name).read_bytes())==h
  events.append(cached);return
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,timeout=180)
 for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,expected_success=ok,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2));assert(r.returncode==0)==ok,(label,r.stderr.decode()[-3000:]);return r
def physical(folder):
 fs=['state.csv','endpoint.csv','restart.bin'];rows=list(csv.DictReader((folder/'budget.csv').open()));assert len(rows)>0
 for r in rows:
  assert abs(float(r['water_residual_cm']))<1e-10 and abs(float(r['solute_residual_mg_cm2']))<1e-10
  independent=float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['rain_supplied_cm'])+float(r['runoff_cm'])+float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])+float(r['actual_transpiration_cm'])-float(r['bottom_up_cm'])+float(r['drainage_cm'])
  assert abs(independent)<1e-10
 state=list(csv.DictReader((folder/'state.csv').open()))
 assert all(min(float(r[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for r in state)
 return dict(files={f:sha((folder/f).read_bytes())for f in fs},budget=rows)
for name,values in [('below','5.,1.'),('equal','10.,2.')]:
 swp=original.replace('SWINCO=1','SWINCO=2\nGWLI=-100.')+'\nKSATEXM='+values+'\n';(case/'project.swp').write_text(swp);folder=out/name;folder.mkdir(exist_ok=True)
 for label,extra in [('full',[]),('split',['--stop-after','365']),('resumed',['--restart',folder/'split'])]:run(common+['--native-hydraulics','--output',folder/label]+extra,name+'-'+label)
 result=physical(folder/'full');assert len(result['budget'])==481
 assert result['budget'][365:]==physical(folder/'resumed')['budget'];assert result['files']==physical(folder/'resumed')['files']
 assert sum(float(r['drainage_cm'])for r in result['budget'])>0
 results[name]=result
 target=folder/'forbidden';run(common+['--output',target],name+'-default-off',False);assert not target.exists()
 (case/'project.swp').write_text(swp.replace('GWLI=-100.','GWLI=-101.'));target=folder/'foreign-source';run(common+['--native-hydraulics','--restart',folder/'split','--output',target],name+'-foreign-source',False);assert not target.exists()
 (case/'project.swp').write_text(swp)
assert results['below']==results['equal']
# A real attempted active composition hit the existing Picard admission guard.
# Keep the failed trial and require the unsupported combination to reject.
(case/'project.swp').write_text(original.replace('SWINCO=1','SWINCO=2\nGWLI=-100.')+'\nKSATEXM=20.,4.\n');target=out/'blocked-active';run(common+['--native-hydraulics','--output',target],'active-existing-guard',False);assert not target.exists()
# Default route: compare the actual current caller with an independently built
# exact canonical baseline executable, using byte-identical generated forcing.
(case/'project.swp').write_text(original);run(common+['--output',out/'default'],'default')
old=json.loads((base/'bundle.json').read_text());run([sys.executable,'-B',ROOT/'tools/solute/run_column.py','--exe',old['exe'],'--input',out/'default/input.nml','--swp',case/'project.swp','--output',out/'baseline'],'baseline')
results['default']=physical(out/'default');assert results['default']==physical(out/'baseline')
# Preserve failed paths as evidence. None may publish a final generation.
hydro=original.replace('SWINCO=1','SWINCO=2\nGWLI=-100.')+'\nKSATEXM=10.,2.\n'
for name,text in [('saturated',hydro.replace('GWLI=-100.','GWLI=0.')),('bad-ksatexm',hydro.replace('KSATEXM=10.,2.','KSATEXM=0.,2.')),('conflicting-bottom',hydro+'\nSWBOTB=2\n'),('loose-restart',hydro.replace('SWINCO=2','SWINCO=3'))]:
 (case/'project.swp').write_text(text);target=out/('forbidden-'+name);run(common+['--native-hydraulics','--output',target],name,False);assert not target.exists()
(case/'project.swp').write_text(hydro);bbc=(case/'swap.bbc').read_bytes();(case/'swap.bbc').write_bytes(bbc.replace(b'1998-12-31',b'1998-12-30'));target=out/'foreign-bbc';run(common+['--native-hydraulics','--restart',out/'equal/split','--output',target],'foreign-bbc',False);assert not target.exists();(case/'swap.bbc').write_bytes(bbc)
meta=json.loads((bundle/'column/build-complete.json').read_text());inputs=dict(meta['input_sha256'])
for f in ['tools/solute/run_project.py','tools/solute/run_column.py','tools/solute/run_crop_daily.py','tests/nut-sol/qualify_native_cauchy3.py','integration/mc-sol01/drainage/qualify_project_hydraulics.py']:inputs[f]=sha((ROOT/f).read_bytes())
record=dict(status='PROJECT_HYDRAULICS_BBC481_RESTART_PASS',events=events,results=results,input_sha256=inputs,source_nodes=12,coupled_cases=2,complete_days=481,fresh_process_restarts=2,default_comparisons=4,rejected_processes=sum(e['returncode']!=0 for e in events),active_KSATEXM_Picard_composition='REJECTED_BY_EXISTING_ADMISSION_GUARD',bundle=json.loads((bundle/'bundle.json').read_text()),baseline_bundle=old,qualified=False,canonically_admitted=False)
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
