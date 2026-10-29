"""Collect completed native runs, preserving exact raw evidence and source bindings."""
import csv,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;OUT=ROOT/'integration/dataqual12'
sha=lambda b:hashlib.sha256(b).hexdigest()
files={};runs=[]
def add(name,path):files[name]=path.read_bytes()
for name in ['O0-5','O2-5','O2-30','O2-restart30','O2-120','O2-full120','O0-120']:
 p=W/('dq12-final-model-'+name);m=json.loads((p/'manifest.json').read_text());assert m['status']=='COMPLETE'and m['returncode']==0
 for f,h in m['files'].items():assert sha((p/f).read_bytes())==h;add('model/'+name+'/'+f,p/f)
 add('model/'+name+'/manifest.json',p/'manifest.json');r=list(csv.DictReader((p/'budget.csv').open()))
 runs.append(dict(run=name,start_day=float(r[0]['t0_day']),end_day=float(r[-1]['t1_day']),native_seconds=m['native_seconds'],max_water_residual_cm=max(abs(float(x['water_residual_cm']))for x in r),max_solute_residual_mg_cm2=max(abs(float(x['solute_residual_mg_cm2']))for x in r),final_water_cm=float(r[-1]['water_end_cm']),final_solute_mg_cm2=float(r[-1]['solute_end_mg_cm2'])))
for opt in ['O0','O2']:
 for name in ['shared','column','read_fallow']:
  p=W/('dq12-qualified-'+opt if name=='shared'else'dq12-checked-'+opt)/name/'build-complete.json';add('build/'+opt+'/'+name+'.json',p)
 for p in (W/'dq12-black-contract2'/opt).glob('test*.log'):
  assert b'PASS'in p.read_bytes();add('black/'+opt+'/'+p.name,p)
 assert len(list((W/'dq12-black-contract2'/opt).glob('test*.log')))==4
p=W/'dq12-thermal-contract/result.json';assert json.loads(p.read_text())['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED';add('thermal/result.json',p)
for role,folder in [('current','dq12-andelst-current-one'),('baseline','dq12-andelst-base-one')]:
 for name in ['manifest.json','state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']:add('preservation/'+role+'/'+name,W/folder/name)
for d in [5,30,120]:
 for name in ['swap.swp','result.bal','result.blc','swap.log']:
  p=W/('dq12-reference-hupsel'+str(d))/name
  if p.exists():add('reference/'+str(d)+'/'+name,p)
for name in ['crop-crossing','cofred','crc','crc-native']:
 assert not(W/'dq12-negative'/name).exists()
 for ext in ['stdout','stderr']:add('negative/'+name+'.'+ext,W/'dq12-negative'/(name+'.'+ext))
for p in (W/'dq12-negative').glob('*.pending-*/stdout'):add('negative/'+p.parent.name+'/stdout',p)
add('reference/BUILD.json',W/'dq12-reference431/BUILD.json')
add('black/recipe.py',Path('/tmp/dq12_contract2.py'))
for folder in ['dq12-hupsel-debug','dq12-andelst-preservation','dq12-thermal-preservation']:
 for p in (W/folder).rglob('*'):
  if p.is_file()and (p.suffix in ['.stdout','.stderr']or p.name in ['stdout','stderr','result.json']):add('failed/'+folder+'/'+str(p.relative_to(W/folder)),p)
result=dict(status='BOUNDED_WATER_SOLUTE_RESTART_QUALIFIED',new_original_projects_executed=1,longest_new_project_days=120,original_project='1.hupselbrook',original_project_complete=False,new_physical_laws=0,new_compositions=['direct PM, Black, Hooghoudt IPOS2, numeric heat, mobile solute','original SWBOTB6 zero flux','original two-hour surface irrigation, 48 mg/cm2 solute'],energy_qualified=False,historical_full_equivalence=False,coverage=dict(independent_complete_projects=3,projects_with_bounded_water_evidence=2,full_original_projects_migrated=0),runs=runs,comparison=dict(reference='B1.11 SWAP4.3.1 source authority; shortened TEND, optional SWCSV disabled',water120_reference_rounded_cm=76.19,solute120_reference_rounded_mg_cm2=45.16,claim='Measured differences, no exact full historical equivalence.'))
raw=(json.dumps(result,indent=2)+'\n').encode();files['RESULT.json']=raw;(OUT/'RESULT.json').write_bytes(raw)
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode()
with tarfile.open(OUT/'EVIDENCE.tar.xz','w:xz')as t:
 for name,b in sorted(files.items()):info=tarfile.TarInfo(name);info.size=len(b);info.mtime=0;t.addfile(info,io.BytesIO(b))
print('COLLECTED',len(files),sha((OUT/'EVIDENCE.tar.xz').read_bytes()))
