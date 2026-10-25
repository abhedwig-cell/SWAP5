"""Extend an immutable admitted generation; never rerun a completed segment."""
import argparse,csv,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();BASE='d6e3955914819ede9d25aaf7b764e48c8467909c'
def check_generation(folder,exe,input_hash,swp_hash):
 m=json.loads((folder/'manifest.json').read_text());assert m['status']=='COMPLETE'and m['executable_sha256']==sha(exe.read_bytes());assert m['input_sha256']==input_hash and m['swp_sha256']==swp_hash
 for p,h in m['files'].items():assert sha((folder/p).read_bytes())==h,(folder,p)
 assert(folder/'restart.bin').read_bytes()[:8]==b'S5PT0002';return m

def budget(folder,start,end):
 rows=list(csv.DictReader((folder/'budget.csv').open()));assert len(rows)==end-start and [int(r['window'])for r in rows]==list(range(start+1,end+1))
 for r in rows:
  assert abs(float(r['water_residual_cm']))<1e-10 and abs(float(r['solute_residual_mg_cm2']))<1e-10
  assert abs(float(r['potential_transpiration_cm'])-float(r['actual_transpiration_cm'])-float(r['drought_reduction_cm'])-float(r['oxygen_reduction_cm']))<1e-12
  assert 0<=float(r['observed_heat_residual_j_cm2'])<=1e-9
  gross=float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['rain_supplied_cm'])+float(r['runoff_cm'])+float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])+float(r['actual_transpiration_cm'])-float(r['bottom_up_cm'])+float(r['drainage_cm']);assert abs(gross)<1e-10
 state=list(csv.DictReader((folder/'state.csv').open()));assert len(state)==112 and all(min(float(r[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for r in state)
 return rows

def main():
 p=argparse.ArgumentParser();p.add_argument('--seed',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--until',type=int,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=True);seed=a.seed.resolve();bundle=a.bundle.resolve();b=json.loads((bundle/'bundle.json').read_text());exe=Path(b['exe']);build=json.loads((exe.parent/'build-complete.json').read_text());input_hash=sha((seed/'input.nml').read_bytes());swp_hash=sha((seed/'input.swp').read_bytes());seed_m=check_generation(seed,exe,input_hash,swp_hash);assert seed_m['stop_after']==30 and b['optimization']=='O2'
 for path,h in build['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
 record=out/'RESULT.json'
 if record.exists():
  r=json.loads(record.read_text());assert r['baseline']==BASE and r['seed_restart_sha256']==seed_m['files']['restart.bin']and r['executable_sha256']==sha(exe.read_bytes())
 else:r=dict(baseline=BASE,status='RUNNING',optimization='O2',seed=str(seed),seed_restart_sha256=seed_m['files']['restart.bin'],executable_sha256=sha(exe.read_bytes()),build=build,segments=[],events=[],qualified=False,canonically_admitted=False,full_original_Andelst=False,original_macro_Rutter_excluded=True)
 parent=seed;start=30;allrows=budget(seed,0,30)
 for segment in r['segments']:
  folder=out/segment['folder'];m=check_generation(folder,exe,input_hash,swp_hash);assert m['parent_restart_sha256']==check_generation(parent,exe,input_hash,swp_hash)['files']['restart.bin'];assert segment['start']==start and segment['end']==m['stop_after'];allrows+=budget(folder,start,segment['end']);parent=folder;start=segment['end']
 assert a.until>start and a.until<=481 and a.until-start<=120
 target=out/('to-'+str(a.until));assert not target.exists();cmd=[sys.executable,'-B',ROOT/'tools/solute/run_column.py','--exe',exe,'--input',seed/'input.nml','--swp',seed/'input.swp','--restart',parent,'--stop-after',str(a.until),'--output',target]
 r.update(status='RUNNING',next_interval=[start,a.until]);record.write_text(json.dumps(r,indent=2)+'\n');t=time.monotonic()
 try:cp=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=900)
 except subprocess.TimeoutExpired as e:
  for stream in ['stdout','stderr']:(out/('to-'+str(a.until)+'.'+stream)).write_bytes(getattr(e,stream)or b'')
  r.update(status='CENSORED',qualified=False);r['events'].append(dict(command=list(map(str,cmd)),returncode=None,seconds=time.monotonic()-t,censored=True));record.write_text(json.dumps(r,indent=2)+'\n');raise
 for stream in ['stdout','stderr']:(out/('to-'+str(a.until)+'.'+stream)).write_bytes(getattr(cp,stream))
 r['events'].append(dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-t))
 if cp.returncode:
  r.update(status='NATIVE_REJECTION_TO_RECONCILE',qualified=False,completed_days=start);record.write_text(json.dumps(r,indent=2)+'\n');raise RuntimeError(cp.stderr.decode()[-1800:])
 m=check_generation(target,exe,input_hash,swp_hash);assert m['parent_restart_sha256']==check_generation(parent,exe,input_hash,swp_hash)['files']['restart.bin'];extra=budget(target,start,a.until);assert float(extra[0]['water_start_cm'])==float(allrows[-1]['water_end_cm']) and float(extra[0]['solute_start_mg_cm2'])==float(allrows[-1]['solute_end_mg_cm2']);allrows+=extra
 r['segments'].append(dict(folder=target.name,start=start,end=a.until,parent_restart_sha256=m['parent_restart_sha256'],restart_sha256=m['files']['restart.bin'],native_seconds=m['native_seconds']));r.update(status='CONTINUATION_SEGMENT_PASS',completed_days=a.until,all_budget=allrows,input_sha256={**build['input_sha256'],'integration/mc-sol01/drainage/continue_source_profile.py':sha(Path(__file__).read_bytes()),'tools/solute/run_column.py':sha((ROOT/'tools/solute/run_column.py').read_bytes())},physical_results=dict(nodes=112,complete_days=a.until,water_max_cm=max(abs(float(x['water_residual_cm']))for x in allrows),solute_max_mg_cm2=max(abs(float(x['solute_residual_mg_cm2']))for x in allrows),observed_heat_max_j_cm2=max(float(x['observed_heat_residual_j_cm2'])for x in allrows)));record.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(status=r['status'],complete_days=a.until,native_seconds=m['native_seconds'])))
if __name__=='__main__':main()
