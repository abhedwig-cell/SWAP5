"""Original112-node matrix/heat/crop interaction, using unchanged admitted owners.

This explicit projection excludes original macro and Rutter switches. It is not
an original complete application or a claim of historical chemical equivalence.
"""
import argparse,base64,csv,gzip,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE='146823954f2a24e43b6e007591ef2876331daa9d'
SOURCES=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006'
sha=lambda b:hashlib.sha256(b).hexdigest()
CHEMISTRY='\nSWBR=0\nCPRE=.125\nCDRAIN=.25\nCMLTB=0.,.2,-320.,.8\nDDIF=.0001\nLDIS='+','.join(['.01']*8)+'\nSWSP=1\nFREXP=.5\nCREF=1.\nKF='+','.join(['.0002']*8)+'\nSWDC=1\nDECPOT='+','.join(['.001']*8)+'\nGAMPAR=.05\nRTHETA=.3\nBEXP=1.\nFDEPTH='+','.join(['1.']*8)+'\nTSCF=.5\n'
NAMES=['swap.swp','swap.bbc','swap.dra','wintcer1.crp','wintcer2.crp','andelst_meteo.998','andelst_meteo.999','andelst_rain.998','andelst_rain.999']
def fixture(folder):
 folder.mkdir();provenance={}
 for name in NAMES:
  p=SOURCES/('b111-'+name+'.gz');original=gzip.decompress(p.read_bytes());data=original
  if name=='swap.swp':
   for key,old,new in [('SWMACRO',1,0),('SWSOLU',0,1)]:
    data,n=re.subn(rb'(?m)^(\s*'+key.encode()+rb'\s*=\s*)'+str(old).encode(),rb'\g<1>'+str(new).encode(),data);assert n==1
   data+=CHEMISTRY.encode()
  elif name.endswith('.crp'):
   data,n=re.subn(rb'(?m)^(\s*SWINTER\s*=\s*)3',rb'\g<1>0',data);assert n==1
  (folder/name).write_bytes(data)
  provenance[name]=dict(compressed_path=str(p.relative_to(ROOT)),compressed_sha256=sha(p.read_bytes()),original_sha256=sha(original),executed_sha256=sha(data))
 return provenance

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();bundle=a.bundle.resolve();build=json.loads((bundle/'column/build-complete.json').read_text());b=json.loads((bundle/'bundle.json').read_text());events=[]
 # Pure input-domain evidence: no changed process, solver, runtime, adapter,
 # launcher or generated input is permitted; compiled providers must be exact.
 for path,h in build['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
 for path,h in build['reused_artifact_sha256'].items():assert sha(Path(path).read_bytes())==h,path
 for path,h in b['executable_sha256'].items():assert sha(Path(path).read_bytes())==h,path
 record=dict(status='RUNNING',baseline=BASE,optimization=b['optimization'],build=build,bundle=b,events=events,qualified=False,canonically_admitted=False,full_original_Andelst=False,production_edited=False)
 def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
 def run(cmd,label,ok=True):
  t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,timeout=900)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,expected_success=ok,seconds=time.monotonic()-t));save()
  assert(r.returncode==0)==ok,(label,r.stdout.decode()[-1500:],r.stderr.decode()[-2500:]);return r
 case=out/'project';record['original_sources']=fixture(case);save();swp=case/'swap.swp';common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',swp,'--bundle',bundle,'--native-hydraulics','--native-heat','--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
 for label,extra in [('full',[]),('split',['--stop-after','365']),('resumed',['--restart',out/'split'])]:run(common+['--output',out/label]+extra,label)
 rows=lambda p:list(csv.DictReader(p.open()))
 budget=rows(out/'full/budget.csv');assert len(budget)==481 and budget[365:]==rows(out/'resumed/budget.csv')
 fs=['state.csv','endpoint.csv','temperature.csv','restart.bin']
 for f in fs:assert(out/'full'/f).read_bytes()==(out/'resumed'/f).read_bytes(),f
 assert(out/'full/restart.bin').read_bytes()[:8]==b'S5PT0002'
 state=rows(out/'full/state.csv');assert len(state)==112
 assert all(min(float(r[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for r in state)
 gross=[]
 for row in budget:
  assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
  assert 0<=float(row['observed_heat_residual_j_cm2'])<=1e-9
  assert abs(float(row['potential_transpiration_cm'])-float(row['actual_transpiration_cm'])-float(row['drought_reduction_cm'])-float(row['oxygen_reduction_cm']))<1e-12
  gross.append(float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm'])-float(row['bottom_up_cm'])+float(row['drainage_cm']));assert abs(gross[-1])<1e-10
 for key in ['drainage_cm','actual_transpiration_cm','rain_supplied_cm','soil_evaporation_cm','runoff_cm']:assert sum(float(r[key])for r in budget)>0,key
 pairs={label:list(map(float,re.search(r'SWAP5_COMMITTED_BOESTEN_PAIR=\s*([-+\d.Ee]+)\s+([-+\d.Ee]+)',(out/label/'stdout').read_text()).groups()))for label in ['full','split','resumed']};assert pairs['full']==pairs['resumed']and min(pairs['full']+pairs['split'])>=0
 # Original excluded processes must reject explicitly, and source-bound
 # continuation must not accept a changed profile or crop companion.
 original=swp.read_bytes()
 for name,data in [('macro',original.replace(b'SWMACRO = 0',b'SWMACRO = 1')),('foreign-profile',original.replace(b'GWLI = -80.9',b'GWLI = -81.9'))]:
  assert data!=original;swp.write_bytes(data);target=out/('forbidden-'+name);extra=[]if name=='macro'else['--restart',out/'split'];run(common+extra+['--output',target],name,False);assert not target.exists();swp.write_bytes(original)
 crop=case/'wintcer1.crp';old=crop.read_bytes();changed,n=re.subn(rb'(?m)^(\s*SWINTER\s*=\s*)0',rb'\g<1>3',old);assert n==1;crop.write_bytes(changed);target=out/'forbidden-rutter';run(common+['--output',target],'rutter',False);assert not target.exists();crop.write_bytes(old)
 changed,n=re.subn(rb'(?m)^(\s*LCC\s*=\s*)232',rb'\g<1>231',old);assert n==1;crop.write_bytes(changed);target=out/'forbidden-crop';run(common+['--restart',out/'split','--output',target],'foreign-crop',False);assert not target.exists();crop.write_bytes(old)
 inputs=dict(build['input_sha256']);inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__).read_bytes())
 for path in ['tools/solute/run_project.py','tools/solute/run_column.py','tools/solute/run_crop_daily.py','app/solute_crop/read_swp_project.f90','app/solute_crop/read_swp_crop.f90','app/solute_crop/read_swp_root.f90']:inputs[path]=sha((ROOT/path).read_bytes())
 for v in record['original_sources'].values():inputs[v['compressed_path']]=v['compressed_sha256']
 record.update(status='ORIGINAL_MATRIX112_HEAT_CROP481_RESTART_PASS',input_sha256=inputs,results=dict(files={f:sha((out/'full'/f).read_bytes())for f in fs},budget=budget,committed_pairs=pairs),physical_results=dict(nodes=112,layers=8,days=481,exact_process_restarts=1,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budget),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budget),gross_water_max_cm=max(map(abs,gross)),observed_heat_max_j_cm2=max(float(r['observed_heat_residual_j_cm2'])for r in budget)),rejected_processes=4);save();print(record['status'])
if __name__=='__main__':main()
