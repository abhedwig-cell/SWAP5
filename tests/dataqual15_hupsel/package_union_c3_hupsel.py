"""Seal actual current-union C3 Hupsel execution; no substitute model."""
import argparse, hashlib, io, json, subprocess, tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,default=ROOT.parent);a=p.parse_args()
W=a.workspace.resolve();out=ROOT/'integration/dataqual15_hupsel';out.mkdir(parents=True,exist_ok=True)
sha=lambda data:hashlib.sha256(data).hexdigest()
load=lambda path:json.loads(path.read_text())
members={};source={};normalized={}
def add(name,data):
 if name in members:assert members[name]==data,name
 members[name]=data
def file(name,path):add(name,path.read_bytes())
def js(name,value):add(name,(json.dumps(value,indent=2,sort_keys=True)+'\n').encode())
builds={'hupsel-O2':'dq15-union-oxygen-hupsel-O2b','hupsel-O0':'dq15-union-oxygen-hupsel-O0b'}
for label,folder in builds.items():
 base=W/folder;build=load(base/'BUILD.json');file('builds/'+label+'/BUILD.json',base/'BUILD.json')
 if(base/'EVENTS.json').exists():file('builds/'+label+'/EVENTS.json',base/'EVENTS.json')
 for path in list(base.glob('*.stdout'))+list(base.glob('*.stderr')):file('builds/'+label+'/'+path.name,path)
 entries={}
 for original,digest in build['source_sha256'].items():
  path=Path(original);data=path.read_bytes();assert sha(data)==digest,path
  if path.is_relative_to(ROOT):
   relative=path.relative_to(ROOT).as_posix();source[relative]=digest;key='source/repository/'+relative
  else:key='source/generated/'+label+'/'+path.name
  add(key,data);entries[key]=digest
 exe=base/'swap5_hupsel_germination';assert sha(exe.read_bytes())==build['executable_sha256']
 file('binaries/'+label,exe);file('binaries/read-fallow-'+label,base/'read_fallow')
 normalized[label]=dict(provider_count=build['provider_count'],compiler=build['compiler'],source_sha256=entries,
  executable_sha256=build['executable_sha256'],flags=[('-I<BUILD>'if x.startswith('-I')else'-J<BUILD>'if x.startswith('-J')else x)for x in build['flags']])

# Retain the full reviewed two-project footprint, but hash CURRENT union bytes.
# This does not import old macro bytes or claim a Grassgrowth run in this proof.
old=load(W/'SWAP5-combined-candidate/integration/dataqual15_hupsel/COMBINED_CLOSED_RESULT.json')
paths=set(old['repository_source_sha256'])
paths-={'tests/dataqual15_hupsel/package_combined_closed.py','tests/dataqual15_hupsel/verify_combined_closed.py'}
paths|={'tests/dataqual15_hupsel/package_union_c3_hupsel.py','tests/dataqual15_hupsel/verify_union_c3_hupsel.py'}
for relative in sorted(paths):
 path=ROOT/relative;data=path.read_bytes();source[relative]=sha(data);add('source/repository/'+relative,data)

cases={'hupsel-full1096':'dq15-union-oxygen-hupsel1096-O2',
 'hupsel-restart584':'dq15-union-c3-hupsel584-restart-O2',
 'hupsel-restart730':'dq15-union-c3-hupsel730-restart-O2',
 'hupsel-restart868':'dq15-union-c3-hupsel868-restart-O2',
 'hupsel-tail1058-O0':'dq15-union-oxygen-hupsel1058-tail-O0',
 'hupsel-tail1058-O2':'dq15-union-oxygen-hupsel1058-tail-O2',
 'hupsel-restart1077-O0':'dq15-union-oxygen-hupsel1077-restart-O0',
 'hupsel-restart1077-O2':'dq15-union-oxygen-hupsel1077-restart-O2',
 'hupsel-guards730-O2':'dq15-union-c3-codec730-O2',
 'hupsel-guards868-O2':'dq15-union-c3-codec868-O2',
 'hupsel-guards1077-O0':'dq15-union-c3-codec1077-O0'}
for label,folder in cases.items():
 base=W/folder;record=load(base/'RESULT.json')
 if 'guards'not in label:
  incoming=record['command'][2]
  if incoming!='-':file('cases/'+label+'/restart-origin.bin',Path(incoming))
 for path in base.rglob('*'):
  if not path.is_file()or'.tmp'in path.name:continue
  if path.suffix in('.csv','.bin','.json','.nml','.swp','.crp','.met','.dra','.bbc','.binding')or path.name in('stdout','stderr','prepare.stdout','prepare.stderr'):
   file('cases/'+label+'/'+path.relative_to(base).as_posix(),path)

gold=W/'dq15-combined-hupsel1096-O2'
for name in ['RESULT.json','budget.csv','crop.csv','germination.csv','endpoint.csv','state.csv','temperature.csv','restart.bin','checkpoint.bin']:
 file('golden/hupsel/'+name,gold/name)
provenance=W/'dq15-union-oxygen-hupsel-qualification'
for path in provenance.glob('*.json'):file('provenance/'+path.name,path)
with tarfile.open(W/'SWAP5-combined-candidate/integration/dataqual15_hupsel/COMBINED_CLOSED_EVIDENCE.tar.xz','r:xz')as prior:
 for item in prior:
  if item.isfile()and item.name.startswith('reference/'):add(item.name,prior.extractfile(item).read())
ttutil=Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers/ttobj/libttutil.a');file('ttutil/libttutil.a',ttutil)
input_map={}
for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
 relative='reference/swap-4.3.1/projects/1.hupselbrook/'+name
 data=(ROOT/relative).read_bytes();source[relative]=sha(data);add('source/repository/'+relative,data)
 input_map['cases/hupsel-full1096/'+name]=relative
baseline='3170aa1'
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['git','archive',baseline,'src','app'],cwd=ROOT)))as tree:
 inventory={m.name:sha(tree.extractfile(m).read())for m in tree if m.isfile()}
js('BASELINE_PRODUCTION_SHA256.json',inventory)
reviewed={}
for relative in subprocess.check_output(['git','diff','--name-only',baseline,'--','src','app'],cwd=ROOT,text=True).splitlines():
 path=ROOT/relative;reviewed[relative]=sha(path.read_bytes())if path.exists()else None
 if path.exists():
  data=path.read_bytes();source[relative]=sha(data);add('source/repository/'+relative,data)

receipt=dict(status='CURRENT_UNION_C3_ORIGINAL_HUPSEL1096_PASS_NOT_PRODUCTION_OR_SCIENTIFIC_EQUIVALENCE',
 scientific_source_commit='d6514ab',full_original_hupsel=True,current_union_C3=True,
 scope='Hupsel only. Current union Grassgrowth1827 proof must be independently verified by the final selector.',
 repository_source_sha256=source,normalized_builds=normalized,original_input_map=input_map,
 reviewed_production_delta_baseline=baseline,reviewed_production_delta=reviewed,ttutil_sha256=sha(members['ttutil/libttutil.a']),
 full_scientific_equivalence=False,production_promoted=False,canonically_admitted=False,
 hard_bounds=dict(water_cm=1e-10,solute_mg_cm2=1e-10,heat_j_cm2=1e-9,
  authorities=['app/solute_project/main.f90: transaction mass_tolerance',
  'src/runtime/mod_fmr_b111_pond_thermal_application.f90: chemical receipt closure',
  'src/process/mod_soil_temperature_contract.f90: energy_abs_tolerance_j_cm2']),
 diagnostic_difference='Only unused post-emergence pressure_average_cm differs on584-to591 restart; native and every physiological column are identical.',
 executions={label:load(W/folder/'RESULT.json')for label,folder in cases.items()if'guards'not in label})
js('QUALIFICATION.json',receipt);js('MANIFEST.json',{name:sha(data)for name,data in sorted(members.items())})
archive=out/'UNION_C3_HUPSEL_EVIDENCE.tar.xz'
with tarfile.open(archive,'w:xz',preset=6)as tar:
 for name,data in sorted(members.items()):
  item=tarfile.TarInfo(name);item.size=len(data);item.mtime=0;item.mode=0o644;tar.addfile(item,io.BytesIO(data))
summary={k:v for k,v in receipt.items()if k!='executions'}
summary.update(archive_sha256=sha(archive.read_bytes()),archive_members=len(members),archive_bytes=archive.stat().st_size,
 execution_summaries={k:{x:r.get(x)for x in['returncode','completed_days','seconds','maximum_water_residual_cm','maximum_solute_residual_mg_cm2']}for k,r in receipt['executions'].items()})
(out/'UNION_C3_HUPSEL_RESULT.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:summary[k]for k in['archive_sha256','archive_members','archive_bytes']}))
