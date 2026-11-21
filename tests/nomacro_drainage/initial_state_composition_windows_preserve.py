"""Seal new Windows state composition once, retaining every actual failure."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from groundwater_snow_archive_storage import store_original
from initial_state_composition_source_inverse import CORE,BASE,PHYSICAL_CORE,complete_inverse
ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';complete_inverse();files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in sorted(path.rglob('*')):
   assert not item.is_symlink()
   if item.is_file():name=prefix+'/'+item.relative_to(path).as_posix();assert name not in files;files[name]=item
 def build(path,label):
  tree(path,'compiled/'+label);projection[str(path)]=dict(archive_prefix='compiled/'+label,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 cohort=json.loads((ev/'INITIAL_STATE_COMPOSITION_WINDOWS_INDEPENDENT_COHORT_V3.json').read_text());assert len(cohort['profiles'])==22
 for label,item in cohort['profiles'].items():
  profile=Path(item['profile']);q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_INITIAL_STATE_COMPOSITION_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3
  assert item['observation']==json.loads(Path(item['independent']).read_text());tree(profile,'profiles/'+label);build(Path(q['build_root']),label)
  role=dict(profile='profiles/'+label,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),independent='observations/'+Path(item['independent']).name,kind=q['kind'],optimization=q['optimization'],initial_selector=q['initial_selector'])
  if q['initial_selector']==2:role['native_controls']='profiles/initial-state-daily-snow-cde-initial2-'+q['optimization']+'-controls-v1'
  roles.append(role)
 failures=[]
 for label in ('initial-state-implicit-water-initial1-O0-v1','initial-state-implicit-cde-initial1-O0-v2'):
  profile=ev/label;q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='FAILED' and q['build']['returncode']==0 and 'Foreign actual ordinary implicit coupled HeadCalc provider' in q['error'] and not (profile/'trajectory').exists();tree(profile,'retained-failed/'+label);build(Path(q['build_root']),'retained-failed-'+label);failures.append(label)
 # Input versions, native refusals, complete/partial controller probes and
 # external transaction raw bytes are all unique custody evidence.
 reserved=set(cohort['profiles'])|set(failures)
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith(('initial-state-','initial-state-composition-')) and path.name not in reserved:tree(path,'profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('initial_state_composition','initial-state-')):files['observations/'+path.name]=path
 source_paths=('app/hybrid_water/experimental_project.py','app/hybrid_water/implicit_snow_cde_root_carry.py','app/hybrid_water/ordinary_pond_source_guard.py','app/hybrid_water/implicit_snow_root_state.f90')
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 for path in source_paths:extra['source-current/'+path]=(ROOT/path).read_bytes();extra['source-parent/'+path]=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,physical_core=PHYSICAL_CORE,baseline=BASE,original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',new_native_codec='S5IRC003',all_equations_unchanged=True,original_receipts_rewritten=False),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 name='INITIAL_STATE_COMPOSITION_WINDOWS_RAW_V1';archive=a.staging/(name+'.zip');assert a.staging.is_dir() and not any(a.staging.iterdir()) and not (proof/(name+'.json')).exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 stored=store_original(archive,proof,archive.name);record=dict(status='ACTUAL_WINDOWS_TWENTY_PROFILE_COMPOSITIONS_TWO_ROOT3_BASELINES_ALL_RAW_SEALED_NOT_ADMITTED',**stored,members=members,roles=roles,runtime=CORE,physical_core=PHYSICAL_CORE,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),short35_contexts=22,new_initial1_contexts=20,root_native3_initial2_baselines=2,actual_compiled_root_refusals=56,source_refusals=40,frontend_controls=56,external_transaction_contexts=2,retained_failed_builds_before_models=2,retained_failed_transaction_prepares=1,full_periods_repeated=0,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(record['status'],record['bytes'],record['sha256'],len(members))


if __name__=='__main__':main()
