"""Seal executed BBC composition, failed rounds and bounded accuracy evidence."""
import base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;W=ROOT.parent
BASE='93f12afe2b76900f32dc10afa56de002c841be86';files={};excluded={}
sha=lambda b:hashlib.sha256(b).hexdigest()
def folder(label,p):
 assert p.exists(),p
 for f in sorted(p.rglob('*')):
  if f.is_symlink()or not f.is_file()or'__pycache__'in f.parts:continue
  raw=f.read_bytes();key=label+'/'+str(f.relative_to(p))
  if f.suffix in ['.o','.mod','.a']or raw.startswith(b'\x7fELF'):
   excluded[key]=dict(bytes=len(raw),sha256=sha(raw));continue
  files[key]=raw
def add(k,p):files[k]=p.read_bytes()
def rows(p):return[{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
for opt in ['O0','O2']:
 folder('native-'+opt,W/('cauchy3-qual481-'+opt));folder('build-'+opt,W/('cauchy3-bbcfil-'+opt))
 folder('contracts-'+opt,W/('cauchy3-contract-'+opt));folder('oldflux-'+opt,W/('cauchy3-oldflux-'+opt))
 folder('failed/qual311-'+opt,W/('cauchy3-qual311-'+opt));folder('prefix001-'+opt,W/('cauchy3-prefix311-'+opt))
folder('oldflux-oracle',W/'cauchy3-oldflux-oracle');folder('cpu',W/'cauchy3-cpu');folder('wet-prefix3',W/'cauchy3-wet-prefix3')
folder('prefix01',W/'cauchy3-tol01-prefix311');folder('inputs',W/'cauchy3-inputs/native-O2/project')
for p in sorted(W.glob('cauchy3-pilot*'))+sorted(W.glob('cauchy3-day312-*'))+sorted(W.glob('cauchy3-tail481-*'))+sorted(W.glob('cauchy3-full-O2*')):
 if p.is_dir():folder('failed-and-probes/'+p.name,p)
 elif p.is_file():add('failed-and-probes/'+p.name,p)
add('parent-owner.json',W/'cauchy3-parent-owner.json');add('oldflux-preservation.json',W/'cauchy3-oldflux-preservation.json')
files['parent-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
old=rows(W/'cauchy3-prefix311-O2/budget.csv');new=rows(W/'cauchy3-qual481-O2/full/budget.csv')[:311]
keys=['rain_supplied_cm','infiltration_cm','runoff_cm','surface_exfiltration_cm','soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm','drainage_cm','water_end_cm','solute_end_mg_cm2']
budget={k:dict(total_001=sum(d[k]for d in old),total_01=sum(d[k]for d in new),max_daily_difference=max(abs(a[k]-b[k])for a,b in zip(old,new)),endpoint_difference=new[-1][k]-old[-1][k])for k in keys}
old_profile=rows(W/'cauchy3-prefix311-O2/state.csv');new_profile=rows(W/'cauchy3-tol01-prefix311/state.csv')
profile={k:max(abs(a[k]-b[k])for a,b in zip(old_profile,new_profile))for k in ['head_cm','theta','concentration_mg_cm3']}
assert budget['rain_supplied_cm']['max_daily_difference']==0
assert budget['runoff_cm']['max_daily_difference']<.001 and budget['water_end_cm']['max_daily_difference']<.02
assert abs(budget['runoff_cm']['total_01']-budget['runoff_cm']['total_001'])<.005
assert abs(budget['drainage_cm']['total_01']-budget['drainage_cm']['total_001'])<.01
assert profile['head_cm']<.1
accuracy=dict(qualified_bounded_accuracy=True,days=311,budget=budget,max_profile_head_difference_cm=profile['head_cm'],profile=profile,
 scope='Common bounded constructed-soil/simple-crop trajectory, not original full Andelst parity')
files['accuracy.json']=json.dumps(accuracy,indent=2).encode()
files['EXCLUDED.json']=json.dumps(excluded,sort_keys=True).encode()
files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True).encode()
b=io.BytesIO()
with tarfile.open(fileobj=b,mode='w:xz',preset=6)as t:
 for p,raw in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(raw))
raw=b.getvalue();path=HERE/'CAUCHY3_EVIDENCE.tar.xz.b64';path.write_bytes(base64.b64encode(raw))
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
d=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*science],cwd=ROOT,text=True)
delta={s.split('\t')[1]:s.split('\t')[0]for s in d.splitlines()}
paths=set(delta)|{str(Path(__file__).relative_to(ROOT)),'integration/mc-sol01/drainage/CAUCHY3_CONTRACT.md'}
r=dict(work_unit='HIST-INTEGRATION01 original BBC bounded native481',baseline=BASE,implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,
 scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},
 evidence=dict(path=str(path.relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files)),
 qualification_owner='integration/audits/verify_native_cauchy_current.py',
 selected='Current real native481 O0/O2/.01/full/split365/resume; original input negatives; Robin and independent cell mass; unchanged-flux481 byte preservation; common311 .001/.01 physical accuracy; matched97 normal/wet CPU; original FSI35 and exact merge postimage.',
 not_selected=['highest low-air','RossFast expansion','new1e-6','unchanged NUT/FCT full process rebuild','full FCI'],
 preservation='Predecessor owner and13 source/raw controls actually replayed at exact93f12afe. Current old flux481 and old typed Robin real driver execute fresh. Historical NUT/FCT evidence is not relabelled fresh.',
 scope='Original BBC365-entry AFGEN endpoint holding, original DRA/detailed weather, supported constructed soil/simple crop, Boesten/root/implicit upwind. Full original Andelst and wet4x remain excluded.',
 next_action='Current owner/source/raw controls, original FSI35, docs and exact merge postimage before canonical admission.')
(HERE/'CAUCHY3_QUALIFICATION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
