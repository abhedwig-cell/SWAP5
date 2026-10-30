"""Independent, portable source-bound DATAQUAL15 original execution proof.

Checks archived native outputs without recompiling or claiming whole-model
equivalence. The exact closed production delta protects inherited boundaries.
"""
import base64,csv,hashlib,io,json,math,struct,subprocess,tarfile,tempfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from checkpoint_layout import layout,payload
from check_history import check

ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()

def verify():
 s=json.loads((ROOT/'integration/dataqual15/EVIDENCE_MANIFEST.json').read_text())
 if (ROOT/'.git').exists():
  delta=subprocess.check_output(['git','diff','--name-status',s['baseline'],'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines()
  assert {r.split('\t')[1]:r.split('\t')[0]for r in delta}==s['reviewed_production_delta'],'unreviewed production delta'
  assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT),'uncommitted production source'
 for p,h in s['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 raw=(ROOT/'integration/dataqual15/EVIDENCE.tar.xz').read_bytes();assert sha(raw)==s['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as tar:
  members=tar.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive and'..'not in PurePosixPath(m.name).parts and'\\'not in m.name for m in members)
  f={m.name:tar.extractfile(m).read()for m in members}
 assert len(f)==s['archive_files']
 manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={n:sha(b)for n,b in f.items()}
 def load(n):return json.loads(f[n])
 def rows(n):return list(csv.DictReader(io.StringIO(f[n].decode())))
 def bound(p,h):
  if p in s['external_source_members']:assert sha(f[s['external_source_members'][p]])==h,p
  else:
   if PurePosixPath(p).is_absolute()or PureWindowsPath(p).is_absolute():
    normalized=p.replace('\\','/');assert '/SWAP5/'in normalized,p;p=normalized.split('/SWAP5/',1)[1]
   assert not PureWindowsPath(p).drive and '..'not in PurePosixPath(p).parts,p
   assert s['source_sha256'][p]==h and sha((ROOT/p).read_bytes())==h,p
 def bind(r):
  for p,h in r['source_sha256'].items():bound(p,h)
 def valid_rows(folder):
  budget=rows(folder+'/budget.csv');crop=rows(folder+'/crop.csv');assert budget and len(budget)==len(crop)
  for i,(b,c)in enumerate(zip(budget,crop)):
   assert int(b['day'])==int(budget[0]['day'])+i==int(c['day'])
   assert all(math.isfinite(float(v))for v in [*b.values(),*c.values()])
   assert abs(float(b['residual_cm']))<1e-10
   assert abs(float(b['water_end_cm'])-float(b['water_start_cm'])-float(b['input_cm'])+float(b['output_cm']))<1e-10
   assert abs(float(b['potential_cm'])-float(b['uptake_cm'])-float(b['drought_cm'])-float(b['oxygen_cm']))<1e-10
   assert abs(float(b['heat_residual_j_cm2']))<1e-8
  assert layout(f[folder+'/checkpoint.bin'])['clock']==int(budget[-1]['day'])
  return budget,crop
 original={'input.swp':'swap.swp','grass.crp':'grass.crp','input.met':'260.met','swap.bbc':'swap.bbc','swap.dra':'swap.dra'}
 project=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth'
 for opt in ['O0','O2']:
  build=load('dq15-weighted-'+opt+'/BUILD.json');bind(build)
  assert build['provider_count']==203 and '-'+opt in build['flags']and'-fcheck=all'in build['flags']
  assert build['native_returncode']==0 and all(e['returncode']==0 for e in build['events'])
  assert any(e['label']=='link'for e in build['events'])
  assert build['source_authority_sha256']==sha((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
  for n,h in build['original_inputs_sha256'].items():assert sha((project/original[n]).read_bytes())==h
  negative='dq15-weighted-negative-'+('O0'if opt=='O0'else'b-O2');bad=load(negative+'/RESULT.json');bind(bad)
  assert bad['executable_sha256']==build['executable_sha256']
  assert len(bad['events'])==11 and {e['case']for e in bad['events']}=={'crc','truncated','layout','clock','source','roots','delay','potential_delay','cut_index','yield_nan','compatibility_nan'}
  checkpoint='dq15-weighted-yearrun-'+opt+'/checkpoint-117.bin';assert sha(f[checkpoint])==bad['checkpoint_sha256']
  for event in bad['events']:
   name=negative+'/'+event['case']+'/'
   assert event['returncode']!=0 and b'bound grass prefix restart rejected'in f[name+'stdout']
   assert name+'checkpoint.bin'not in f and name+'budget.csv'not in f
   if event['case']=='source':assert f[name+'input.swp']!=f['dq15-weighted-yearrun-'+opt+'/input.swp']
   else:assert f[name+'input.swp']==f['dq15-weighted-yearrun-'+opt+'/input.swp']
 for folder in [*s['history_segments'],*s['O0_history_segments'],'dq15-weighted-restart126-140-O2','dq15-weighted-restart365-367-O2','dq15-weighted-restart365-367-O0']:
  binding=load(folder+'/application.binding');bind(binding)
  opt='O0'if folder.endswith('O0')else'O2'
  assert binding['executable_sha256']==load('dq15-weighted-'+opt+'/BUILD.json')['executable_sha256']
  for n,old in original.items():assert f[folder+'/'+n]==(project/old).read_bytes()
  valid_rows(folder)
 o0='dq15-weighted-yearrun-O0';o2='dq15-weighted-yearrun-O2';r=load(o0+'/RESULT.json')
 assert r['returncode']==0 and not r['censored']and r['completed_days']==140
 first,crop0=valid_rows(o0);long,crop2=valid_rows(o2)
 assert first==long[:140]and crop0==crop2[:140]
 assert payload(f[o0+'/checkpoint.bin'])==payload(f[o2+'/checkpoint-140.bin'])
 year_budget=[];year_crop=[]
 for folder in s['O0_history_segments']:
  b,c=valid_rows(folder);year_budget+=b;year_crop+=c
 assert [int(q['day'])for q in year_budget]==list(range(1,368))
 assert year_budget==long[:367]and year_crop==crop2[:367]
 year_end=s['O0_history_segments'][-1]
 assert payload(f[year_end+'/checkpoint.bin'])==payload(f[o2+'/checkpoint-367.bin'])
 restart='dq15-weighted-restart365-367-O0';r=load(restart+'/RESULT.json')
 assert r['returncode']==0 and not r['censored']and r['completed_days']==367
 b,c=valid_rows(restart);assert b==year_budget[365:367]and c==year_crop[365:367]
 assert f[restart+'/checkpoint.bin']==f[year_end+'/checkpoint.bin']
 for folder,first_day,last in [('dq15-weighted-restart126-140-O2',127,140),('dq15-weighted-restart365-367-O2',366,367)]:
  r=load(folder+'/RESULT.json');assert r['returncode']==0 and not r['censored']and r['completed_days']==last
  b,c=valid_rows(folder);assert [int(q['day'])for q in b]==list(range(first_day,last+1))
  assert b==long[first_day-1:last]and c==crop2[first_day-1:last]
  assert f[folder+'/checkpoint.bin']==f[o2+f'/checkpoint-{last}.bin']
 runtime=load('dq15-weighted-runtime/RESULT.json');bind(runtime)
 assert runtime['status']=='CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS'
 assert all(e['returncode']==0 for e in runtime['events'])
 native=[e for e in runtime['events']if e['label']=='native_existing_contract'];assert len(native)==8
 for opt in ['O0','O2']:
  for name in ['groundwater_runtime_driver','groundwater_table_runtime_driver','test_ppa_wu01_production_application_bootstrap','test_bartholomeus_application']:
   assert b'PASS'in f['dq15-weighted-runtime/'+opt+'/'+name+'.stdout']
 mowing=load('dq15-mowing-final-oracle/RESULT.json');bind(mowing)
 assert all(e['returncode']==0 for e in mowing['events'])
 for opt in ['O0','O2']:
  out=f['dq15-mowing-final-oracle/'+opt+'/stdout'].decode();assert 'ORIGINAL_GRASS_BIOMASS_CANDIDATE_PASS'in out
  lines=[l.split()for l in out.splitlines()if l.strip().startswith('GRASS_BODY')]
  assert len(lines)==8 and [int(l[1])for l in lines]==list(range(1,9))and all(float(l[2])==0 for l in lines)
 donor=load('dq15-original-reference/RESULT.json');assert donor['returncode']==100 and not donor['physical_input_changes']
 assert sha(f['original431/BUILD.json'])==donor['original_provider_build_json_sha256']
 build=load('original431/BUILD.json');assert build['executable_sha256']==donor['executable_sha256']and not build['physics_replaced'];bind(build['original_provider_build'])
 assert sha(f['original431/providers/selected/swap_main.f90'])==build['source_sha256']
 original_wofost=f['original431/providers/selected/wofost.f90'].decode().replace('\r\n','\n')
 assert f['dq15-mowing-final-oracle/original_wofost.f90'].decode()==original_wofost.replace('   private\n','   private\n   public :: read_wofost,initialize_wofost,initialize_grass,update_dvs_rate,update_wofost,r_act\n',1)
 assert sha(f['dq15-original-reference/swap.swp'])==donor['swp_after_sha256']and sha(f['original431/previous-output-only.swp'])==donor['swp_before_sha256']
 # The reference changes only requested diagnostic columns, not physical input.
 def physical_swp(b):return [l for l in b.decode().splitlines()if l.strip()and not l.lstrip().startswith(('INLIST_CSV','NUM_DECIMALS'))]
 assert physical_swp(f['dq15-original-reference/swap.swp'])==physical_swp(f['original431/previous-output-only.swp'])
 assert physical_swp(f['dq15-original-reference/swap.swp'])==physical_swp((project/'swap.swp').read_bytes())
 for n,h in donor['inputs_sha256'].items():assert sha(f['dq15-original-reference/'+n])==h
 assert len(list(csv.DictReader(l for l in f['dq15-original-reference/result_output.csv'].decode().splitlines()if l and not l.startswith('*'))))==1828
 # Recompute the exact contiguous history, balances and harvest comparison from
 # archived physical state. Extraction uses only already validated regular files.
 with tempfile.TemporaryDirectory(prefix='swap5-dataqual15-')as temp:
  root=Path(temp)
  for n,b in f.items():
   path=root/n;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b)
  history=check([root/n for n in s['history_segments']],root/'dq15-original-reference/result_output.csv')
  o0_history=check([root/n for n in s['O0_history_segments']],root/'dq15-original-reference/result_output.csv')
 assert o0_history==load('O0_HISTORY_CHECK.json')and o0_history['completed_days']==367
 assert o0_history['segments'][-1]['returncode']==0 and s['O0_O2_exact_days']==367
 assert history==load('HISTORY_CHECK.json')
 assert history['completed_days']==s['executed_days']and history['full_original_execution']==s['full_original_execution']
 assert not s['scientific_equivalence']and not history['scientific_equivalence']
 return dict(status='SOURCE_BOUND_ORIGINAL_GRASS_EXECUTION_PASS',executed_days=history['completed_days'],full_original_execution=history['full_original_execution'],scientific_equivalence=False,O0_O2_exact_days=367,exact_restarts=['126->140 O2','365->367 O0/O2'],invalid_restart_controls_per_build=11,native_preservation_contracts=8,whole_original_grass_cases_per_build=8,maximum_water_residual_cm=history['maximum_water_residual_cm'])

if __name__=='__main__':print(json.dumps(verify(),indent=2))
