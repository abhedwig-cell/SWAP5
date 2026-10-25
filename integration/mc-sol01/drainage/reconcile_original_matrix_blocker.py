"""Prove original-profile rejection and committed-state preservation, no repair probe."""
import argparse,csv,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args();out=a.run.resolve();record=json.loads((out/'RESULT.json').read_text());bundle=Path(record['bundle']['exe']).parents[1];swp=out/'project/swap.swp';events=[]
 assert len(record['events'])==1 and record['events'][0]['returncode']!=0 and record['status']=='RUNNING'
 failed=next(out.glob('full.pending-*'));prefix=out/'day9';assert prefix.is_dir()and not(out/'full').exists()
 original=(failed/'stdout').read_text();assert 'rejected window/process/completed:          10           0           0'in original
 assert '324         134         175           0'in original and 'rejected thermal status:           0'in original
 raw=(prefix/'restart.bin').read_bytes();assert raw== (failed/'diagnostic-rejected.bin').read_bytes()==(failed/'diagnostic-partial-candidate.bin').read_bytes()
 assert raw[:8]==b'S5PT0002'and len(raw)==53232
 common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',swp,'--bundle',bundle,'--native-hydraulics','--native-heat','--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
 def run(label,extra):
  target=out/label;cmd=common+extra+['--output',target];t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),timeout=90)
  for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
  events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-t));assert r.returncode!=0 and not target.exists(),label
 run('restart-rejected',['--restart',prefix]);resumed=next(out.glob('restart-rejected.pending-*'));assert(resumed/'stdout').read_bytes()==(failed/'stdout').read_bytes()
 assert(resumed/'diagnostic-rejected.bin').read_bytes()==raw==(resumed/'diagnostic-partial-candidate.bin').read_bytes();assert(prefix/'restart.bin').read_bytes()==raw
 old=swp.read_bytes()
 for name,source in [('macro',old.replace(b'SWMACRO = 0',b'SWMACRO = 1')),('foreign-profile',old.replace(b'GWLI = -80.9',b'GWLI = -81.9'))]:
  assert source!=old;swp.write_bytes(source);run('forbidden-'+name,[]if name=='macro'else['--restart',prefix]);swp.write_bytes(old)
 crop=out/'project/wintcer1.crp';old=crop.read_bytes()
 for name,key,start,end in [('rutter','SWINTER','0','3'),('crop','LCC','232','231')]:
  source,n=re.subn(rb'(?m)^(\s*'+key.encode()+rb'\s*=\s*)'+start.encode(),rb'\g<1>'+end.encode(),old);assert n==1;crop.write_bytes(source);run('forbidden-'+name,[]if name=='rutter'else['--restart',prefix]);crop.write_bytes(old)
 rows=list(csv.DictReader((prefix/'budget.csv').open()));assert len(rows)==9
 assert(failed/'budget.csv').read_bytes()==(prefix/'budget.csv').read_bytes()
 gross=[]
 for r in rows:
  assert abs(float(r['water_residual_cm']))<1e-10 and abs(float(r['solute_residual_mg_cm2']))<1e-10 and 0<=float(r['observed_heat_residual_j_cm2'])<=1e-9
  assert abs(float(r['potential_transpiration_cm'])-float(r['actual_transpiration_cm'])-float(r['drought_reduction_cm'])-float(r['oxygen_reduction_cm']))<1e-12
  gross.append(float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['rain_supplied_cm'])+float(r['runoff_cm'])+float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])+float(r['actual_transpiration_cm'])-float(r['bottom_up_cm'])+float(r['drainage_cm']));assert abs(gross[-1])<1e-10
 state=list(csv.DictReader((prefix/'state.csv').open()));assert len(state)==112 and all(min(float(r[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for r in state)
 for key in ['actual_transpiration_cm','drainage_cm','runoff_cm']:assert sum(float(r[key])for r in rows)>0,key
 inputs=dict(record['build']['input_sha256'])
 for q in ['tools/solute/run_project.py','tools/solute/run_column.py','tools/solute/run_crop_daily.py','app/solute_crop/read_swp_project.f90','app/solute_crop/read_swp_crop.f90','app/solute_crop/read_swp_root.f90','integration/mc-sol01/drainage/qualify_original_matrix_profile.py',str(Path(__file__).relative_to(ROOT))]:inputs[q]=sha((ROOT/q).read_bytes())
 for q in record['original_sources'].values():inputs[q['compressed_path']]=q['compressed_sha256']
 result=dict(status='REPRODUCED_ORIGINAL_MATRIX112_DAY10_WATER_REJECTION',optimization=record['optimization'],production_edited=False,full481_qualified=False,baseline=record['baseline'],input_sha256=inputs,events=events,source_provenance=record['original_sources'],failure=dict(window=10,completed_rain_segments=0,attempts=324,solver_rejections=134,temporal_rejections=175,mass_rejections=0,thermal_status=0),accepted_prefix=dict(days=9,nodes=112,water_max_cm=max(abs(float(r['water_residual_cm']))for r in rows),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in rows),gross_water_max_cm=max(map(abs,gross)),observed_heat_max_j_cm2=max(float(r['observed_heat_residual_j_cm2'])for r in rows),files={f:sha((prefix/f).read_bytes())for f in ['state.csv','endpoint.csv','temperature.csv','restart.bin','budget.csv']},budget=rows),rejection_restart_exact=True,committed_state_unchanged=True,partial_candidate_unchanged=True,no_failed_generation_published=True,rejected_source_selections=4,qualified=False,canonically_admitted=False)
 (out/'BLOCKER.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
if __name__=='__main__':main()
