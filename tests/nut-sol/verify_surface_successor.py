#!/usr/bin/env python3
"""Exact additive surface route and independently source-bound Fortran evidence."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='f8eca95ba623dc18db0110cd1b84af46857c8b9b'
STATUS='integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json'
CAPSULE_SHA='ed6ba2035349ee34f48a86d15356601692529e0afa052175ecf5bb1cd6d0bb8d'
GUARDS={'tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def validate_delta(rows,tree,s):
 expected={p:'A' for p in s['added_blobs']};expected.update({p:'M' for p in GUARDS})
 check(rows==expected,'foreign surface dependency delta')
 check(set(s['guard_blobs'])==GUARDS,'surface guard coverage')
 for p,h in {**s['added_blobs'],**s['guard_blobs']}.items():check(tree.get(p)==h,'unqualified surface postimage '+p)
def verify_source():
 s=json.loads((ROOT/STATUS).read_text());check(s['baseline']==BASE,'wrong surface baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty surface dependencies')
 rows={r.split('\t')[1]:r.split('\t')[0] for r in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 tree={r.split('\t')[1]:r.split('\t')[0].split()[2] for r in git('ls-tree','-r','HEAD').splitlines()}
 validate_delta(rows,tree,s)
 for p,h in {**s['added_blobs'],**s['guard_blobs']}.items():check(blob((ROOT/p).read_bytes())==h,'dirty surface postimage '+p)
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'surface reference mutation')
 return dict(baseline=BASE,source_tree=git('rev-parse','HEAD:src'),qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());raw=base64.b64decode((ROOT/s['evidence']['path']).read_bytes())
 check(sha(raw)==s['evidence']['sha256']==CAPSULE_SHA,'surface capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as a:
  members=a.getmembers();check(all(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members),'unsafe surface capsule')
  check(len({m.name for m in members})==len(members),'duplicate surface evidence')
  data={m.name:a.extractfile(m).read() for m in members}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(manifest)==set(data),'incomplete surface manifest')
 for p,h in manifest.items():check(sha(data[p])==h,'surface member drift '+p)
 return data
def validate_evidence(data,execution_commit=None):
 s=json.loads((ROOT/STATUS).read_text());r=json.loads(data['stable/result.json']);events=json.loads(data['stable/events.json'])
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED','unfinished surface qualification')
 check(r['baseline']==(execution_commit or s['execution_commit']),'wrong surface execution')
 check(r['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','wrong surface authority')
 check(r['literal_lines']==[[346,355],[361,432],[442,442],[455,455]],'different surface literal source')
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute() and '..' not in Path(p).parts,'unsafe surface input')
  check(sha((ROOT/p).read_bytes())==h,'stale surface physical input '+p)
 production={p for p in s['added_blobs'] if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'untested surface production')
 for opt in ('O0','O2'):
  row=r['runs'][opt]
  check(row['process_provider_count']==2,'surface process closure')
  check('SURFACE_LITERAL_150_UNITS_BALANCE_INVALID_CUTOFF=PASS' in row['process_stdout'],'surface process absent')
  check('SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS' in row['physical_stdout'],'surface joint absent')
  check(row['physical_stdout'].count('SURFACE_ACTUAL_LITERAL_FOURTEEN_NEGATIVES_REPLAY=PASS')==2,'surface signed trajectories incomplete')
  check(sha(data['stable/'+opt+'/literal_age.f90'])==row['oracle_sha256'],'surface process oracle drift')
  check(sha(data['stable/'+opt+'/expected.bin'])==sha(data['stable/'+opt+'/fresh.bin'])==row['endpoint_sha256']==row['fresh_sha256'],'surface restart endpoint drift')
  compiles=[e for e in events if e['category']=='physical_compile' and '-'+opt in e['command']]
  check(len(compiles)==row['physical_provider_count']+1,'surface compile coverage')
  for p in production:check(sum(str(e['command'][e['command'].index('-c')+1]).endswith('/'+p) for e in compiles)==1,'surface provider not compiled '+p)
  for e in compiles:check('-fcheck=all' in e['command'] and '-ffpe-trap=invalid,zero,overflow' in e['command'],'surface runtime checks removed')
  natives=[e for e in events if e['category']=='physical_native' and '/'+opt+'/' in e['command'][0]]
  check(len(row['restart_negatives'])==10 and len(natives)==12,'surface restart negatives incomplete')
  check(natives[0]['command'][1]=='write' and natives[1]['command'][1]=='resume','surface native identity')
  check(data['stable/'+natives[0]['stdout']].decode()==row['physical_stdout'],'surface raw assertions drift')
  check(b'SURFACE_JOINT_FRESH_PROCESS=PASS' in data['stable/'+natives[1]['stdout']],'surface fresh process absent')
  for e in natives[2:]:check(b'MATRIX_JOINT_INVALID_FILE=PASS' in data['stable/'+e['stdout']],'surface decoder negative absent')
  process=[e for e in events if e['category']=='process_native' and '/'+opt+'/' in e['command'][0]]
  check(len(process)==1 and data['stable/'+process[0]['stdout']].decode()==row['process_stdout'],'surface raw process drift')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed surface command')
  for stream in ('stdout','stderr'):check('stable/'+e[stream] in data,'surface raw stream absent')
 check(r['runs']['O0']['endpoint_sha256']==r['runs']['O2']['endpoint_sha256'],'surface O0/O2 drift')
 witness=json.loads(data['preimage/RESULT.json'])
 check(witness['status']=='EXPECTED_PREIMAGE_ACCEPTS_WATER_MISMATCH','missing surface water mismatch witness')
 check(witness['final_driver_sha256']==r['input_sha256']['tests/nut-sol/test_surface_process.f90'],'different final flux control')
 check(witness['events'][-1]['exit']==1 and b'FAIL large finite near-match cannot violate absolute water budget' in data['preimage/2.stdout'],'preimage did not expose mismatched water acceptance')
 return r
def verify_qualification():
 source=verify_source();validate_evidence(read_evidence());return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent_mineral():
 verify_qualification()
 base=ROOT.parent/'surface-incumbent-f8eca95b'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'wrong surface incumbent')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty surface incumbent')
 p=subprocess.run([sys.executable,'-B','tests/nut-sol/verify_age_successor.py','--incumbent-mineral'],cwd=base,check=True,capture_output=True,text=True,
  env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
# Exact additive current-canonical successor. The original final science,
# including its discriminating water-budget witness, remains immutable.
_original_verify_source=verify_source
_original_verify_qualification=verify_qualification
CURRENT_BASE='31ff3158b956183c8af19f85bd3361847f60309b'
ORIGINAL_FINAL='238b6184140ec42cbd77f472436519d98bbf7bd7'
PRODUCERS={'src/process/mod_b111_surface_supply.f90','src/runtime/mod_fmr_b111_surface_solute_route.f90','src/runtime/mod_fmr_b111_surface_joint_application.f90'}
SURFACE_CASE="""      src/process/mod_b111_surface_supply.f90|src/runtime/mod_fmr_b111_surface_solute_route.f90|src/runtime/mod_fmr_b111_surface_joint_application.f90 )
        python3 tests/nut-sol/verify_surface_successor.py --incumbent-mineral || fail "unqualified surface input successor: $candidate_path"
        ;;
"""
IMPACT_PREFLIGHT='# Explicit preflight; produces a conservative selection report, never F-CI PASS.\n# Example: bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh --plan-rossfast-impact integration/f-ci-canonical\nif [[ "${1:-}" == --plan-rossfast-impact ]]; then\n  if [[ -z "${2:-}" || -n "${3:-}" ]]; then\n    echo \'Usage: --plan-rossfast-impact BASE_REF\' >&2\n    exit 2\n  fi\n  python3 -B tests/fci/select_component_impact.py --base "$2"\n  exit $?\nfi\n\n'
MOVING='tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
HARVEST='tests/crop-harvest/verify_harvest_successor.py'
DISPATCH={'verify_source': " if (ROOT/'src/runtime/mod_fmr_b111_surface_solute_route.f90').exists():\n  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_successor as surface\n  return surface.verify_source(git_reader)\n", 'verify_physical': " if (ROOT/'src/runtime/mod_fmr_b111_surface_solute_route.f90').exists():\n  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_successor as surface\n  return surface.verify_qualification()  # physical\n", 'verify_qualification': " if (ROOT/'src/runtime/mod_fmr_b111_surface_solute_route.f90').exists():\n  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_successor as surface\n  return surface.verify_qualification()  # qualification\n"}
CONTROL_DISPATCH="if (v.ROOT/'src/runtime/mod_fmr_b111_surface_solute_route.f90').exists():\n subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-sol/check_surface_evidence_controls.py')],check=True);raise SystemExit(0)\n"
def composition():return json.loads((ROOT/STATUS).read_text()).get('canonical_composition')
def verify_source(git_reader=None):
 if (ROOT/'src/runtime/mod_fmr_interception_source_window_binding.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/fpm'));import verify_int12c_successor as int12c
  return int12c.verify_source(git_reader)
 m=composition()
 if m is None:return _original_verify_source()
 g=git if git_reader is None else git_reader
 check(m['canonical']==CURRENT_BASE and m['original_final']==ORIGINAL_FINAL,'foreign surface composition baseline')
 g('merge-base','--is-ancestor',CURRENT_BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty composed surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',CURRENT_BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected=m['postimages'];check(rows=={p:r['status']for p,r in expected.items()},'foreign current surface delta')
 check({p for p in expected if p.startswith('src/')}==PRODUCERS and all(expected[p]['status']=='A'for p in PRODUCERS),'existing production changed')
 original=json.loads(subprocess.check_output(['git','show',ORIGINAL_FINAL+':'+STATUS],cwd=ROOT,text=True))
 for p in PRODUCERS:check(g('rev-parse','HEAD:'+p)==original['added_blobs'][p],'corrected final surface provider drift '+p)
 for p,r in expected.items():check(g('rev-parse','HEAD:'+p)==r['blob']==blob((ROOT/p).read_bytes()),'current surface postimage drift '+p)
 check(g('rev-parse','HEAD:src')==m['source_tree'],'surface source tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',CURRENT_BASE+':reference'),'surface reference changed')
 # Removing only governed guard dispatch leaves the complete incumbent bodies.
 text=(ROOT/HARVEST).read_text()
 for addition in DISPATCH.values():check(text.count(addition)==1,'unknown surface owner dispatch');text=text.replace(addition,'')
 check(text==subprocess.check_output(['git','show',CURRENT_BASE+':'+HARVEST],cwd=ROOT,text=True),'harvest owner body drift')
 moving=(ROOT/MOVING).read_text()
 if 'tests/fci/select_component_impact.py' in expected:
  check(moving.count(IMPACT_PREFLIGHT)==1,'unknown impact preflight');moving=moving.replace(IMPACT_PREFLIGHT,'')
 check(moving.count(SURFACE_CASE)==1,'unknown surface moving case')
 check(moving.replace(SURFACE_CASE,'')==subprocess.check_output(['git','show',CURRENT_BASE+':'+MOVING],cwd=ROOT,text=True),'full moving body changed')
 controls='tests/crop-harvest/check_admission_controls.py';text=(ROOT/controls).read_text();check(text.count(CONTROL_DISPATCH)==1,'unknown control dispatch')
 check(text.replace(CONTROL_DISPATCH,'')==subprocess.check_output(['git','show',CURRENT_BASE+':'+controls],cwd=ROOT,text=True),'incumbent controls changed')
 return dict(baseline=CURRENT_BASE,source_tree=m['source_tree'],current_source_tree=m['source_tree'],surface_successor=True,harvest_successor=True,swrd2_successor=True,swrd3_successor=True,co2_successor=True,calendar_successor=True,input_successor=True,thermal_successor=True,qualified=False,admitted=False)
def current_evidence():
 m=composition();e=m['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'current surface capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  members=a.getmembers();check(all(x.isfile()and not Path(x.name).is_absolute()and '..'not in Path(x.name).parts for x in members),'unsafe current surface capsule')
  check(len(set(x.name for x in members))==len(members),'duplicate current surface evidence');data={x.name:a.extractfile(x).read()for x in members}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete current surface manifest')
 for p,h in manifest.items():check(sha(data[p])==h,'current surface raw corruption '+p)
 return data
from functools import lru_cache
@lru_cache(None)
def incumbent_qualification():
 root=ROOT.parent/('surface-canonical-'+CURRENT_BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),CURRENT_BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==CURRENT_BASE,'surface incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'surface incumbent dirty')
 r=subprocess.run([sys.executable,'-B','tests/crop-harvest/verify_harvest_successor.py'],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(r.returncode==0,'actual admitted incumbent rejected '+r.stderr[-1000:]);result=json.loads(r.stdout)
 check(result['qualified']and result['swrd2_successor']and result['harvest_successor'],'incomplete admitted incumbent')
 return result
def verify_qualification():
 if (ROOT/'src/runtime/mod_fmr_interception_source_window_binding.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/fpm'));import verify_int12c_successor as int12c
  return int12c.verify_qualification()
 if composition()is None:return _original_verify_qualification()
 source=verify_source();data=current_evidence();r=validate_evidence(data,composition()['execution_commit']);old=incumbent_qualification()
 # Every existing production byte is unchanged from an actually qualified
 # canonical owner. This is bounded additive preservation, no full numerical PASS.
 return {**source,'qualified':True,'incumbent_owner':old,'surface_endpoint':r['runs']['O0']['endpoint_sha256'],'preservation':'EXACT_UNCHANGED_INCUMBENT_PRODUCTION_AND_GUARD_BODY_PLUS_CURRENT_SURFACE_PHYSICS','full_fci':'NOT_SELECTED_ADDITIVE_SOURCE_PROOF','highest':'NOT_SELECTED_POLICY'}
# Persistent surface-store successor: the original zero-pond proof above remains
# callable in its immutable incumbent worktree; this is not a wider pond model.
PERSISTENT_BASE='87bc1b1bc0e33d5df9cc460c56f7773209d40931'
PERSISTENT_PRODUCTION={'src/adapter/mod_matrix_joint_restart_file.f90','src/runtime/mod_fmr_b111_matrix_solute_route.f90'}
def persistent_record():return json.loads((ROOT/STATUS).read_text())['persistent_surface_restart_20261016']
def persistent_source(git_reader=None):
 if (ROOT/'tests/nut-sol/verify_pond_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_pond_successor as pond
  return pond.verify_source(git_reader)
 g=git if git_reader is None else git_reader;r=persistent_record()
 check(r['baseline']==PERSISTENT_BASE,'foreign persistent surface baseline')
 g('merge-base','--is-ancestor',PERSISTENT_BASE,'HEAD')
 surface=['src','tests','tools','reference','.github']
 check(not g('status','--porcelain','--',*surface),'dirty persistent surface dependencies')
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',PERSISTENT_BASE,'HEAD','--',*surface).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign persistent surface delta')
 check({p for p in rows if p.startswith('src/')}==PERSISTENT_PRODUCTION,'persistent production scope widened')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'persistent postimage drift '+p)
 check(g('rev-parse','HEAD:src')==r['production_source_tree'],'persistent production tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',PERSISTENT_BASE+':reference'),'persistent reference drift')
 # Retain the incumbent's capability flags, not its qualification on new source.
 flags={n:True for n in ['persistent_surface_restart_successor','material_root_irrigation_successor',
  'b111_request_successor','managed_irrigation_successor','nfix_component_preserved','hyd_successor',
  'daily_density_successor','int12c_successor','co2_successor','swrd3_successor','swrd2_successor',
  'harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor']}
 return dict(baseline=PERSISTENT_BASE,source_tree=r['production_source_tree'],current_source_tree=r['production_source_tree'],
  qualified=False,admitted=False,**flags)
def persistent_evidence():
 r=persistent_record()['science_archive'];raw=base64.b64decode((ROOT/r['path']).read_bytes())
 check(sha(raw)==r['decoded_sha256'],'persistent capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate persistent evidence')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe persistent evidence')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete persistent manifest')
 for p,h in manifest.items():check(sha(data[p])==h,'persistent member corruption '+p)
 return data
def persistent_science(data):
 r=json.loads(data['stable/result.json']);events=json.loads(data['stable/events.json']);record=persistent_record()
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED'and r['baseline']==record['execution_commit'],'unfinished/wrong persistent science')
 check(r['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','persistent literal authority drift')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'stale persistent executed input '+p)
 check(PERSISTENT_PRODUCTION<=r['input_sha256'].keys(),'untested persistent production')
 expected={'negative','nan','infinite','overbound','missing_mass','extra_byte','unknown_schema'}
 old_surface=current_evidence()
 for opt in ('O0','O2'):
  row=r['runs'][opt];s=row['surface_restart']
  for name in ('restart.bin','expected.bin'):
   check(data['stable/'+opt+'/'+name]==old_surface['stable/'+opt+'/'+name],'admitted V1/default binary drift')
  check(set(s['crc_correct_negatives'])==expected,'missing persistent decoder controls')
  for prefix,endpoint,fresh in [('surface-',s['endpoint_sha256'],s['fresh_sha256']),('',row['endpoint_sha256'],row['fresh_sha256'])]:
   check(sha(data['stable/'+opt+'/'+prefix+'expected.bin'])==sha(data['stable/'+opt+'/'+prefix+'fresh.bin'])==endpoint==fresh,'persistent fresh endpoint drift')
  check(sha(data['stable/'+opt+'/surface-v2.bin'])==s['native_sha256'],'persistent native payload drift')
  native=[e for e in events if e['category']=='restart_native'and '/'+opt+'/'in e['command'][0]]
  compiles=[e for e in events if e['category']=='restart_compile'and '-'+opt in e['command']]
  links=[e for e in events if e['category']=='restart_link'and '-'+opt in e['command']]
  check(len(compiles)==len(links)==1 and str(compiles[0]['command'][compiles[0]['command'].index('-c')+1]).endswith('/'+opt+'/surface_restart.f90'),'persistent driver not compiled/linked')
  check(len(native)==9 and native[0]['command'][1]=='write'and native[1]['command'][1]=='resume','persistent actual programs missing')
  check(data['stable/'+native[0]['stdout']].decode()==s['stdout']and 'SURFACE_STORE_NATIVE_OPAQUE_BALANCE=PASS'in s['stdout'],'missing persistent production assertions')
  check(b'SURFACE_STORE_FRESH_PROCESS=PASS'in data['stable/'+native[1]['stdout']],'missing persistent fresh native')
  for e in native[2:]:check(b'SURFACE_STORE_INVALID_FILE=PASS'in data['stable/'+e['stdout']],'persistent forged decoder accepted')
  for label in expected:check(any(Path(e['command'][2]).name=='surface-'+label+'.bin'for e in native[2:]),'persistent negative not executed '+label)
  old=[e for e in events if e['category']=='physical_native'and '/'+opt+'/'in e['command'][0]]
  check(len(old)==12 and len(row['restart_negatives'])==10,'incumbent zero-pond native controls missing')
  check(b'SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS'in data['stable/'+old[0]['stdout']],'zero-pond integration missing')
  check(b'SURFACE_JOINT_FRESH_PROCESS=PASS'in data['stable/'+old[1]['stdout']],'zero-pond fresh process missing')
  for e in old[2:]:check(b'MATRIX_JOINT_INVALID_FILE=PASS'in data['stable/'+e['stdout']],'incumbent decoder assertion missing')
  process=[e for e in events if e['category']=='process_native'and '/'+opt+'/'in e['command'][0]]
  check(len(process)==1 and b'SURFACE_LITERAL_150_UNITS_BALANCE_INVALID_CUTOFF=PASS'in data['stable/'+process[0]['stdout']],'literal process science missing')
  compiled=[e for e in events if e['category']=='physical_compile'and '-'+opt in e['command']]
  check(len(compiled)==row['physical_provider_count']+1,'persistent provider closure missing')
  for p in PERSISTENT_PRODUCTION:check(sum(str(e['command'][e['command'].index('-c')+1]).endswith('/'+p)for e in compiled)==1,'persistent provider uncompiled '+p)
  original=(ROOT/'tests/nut-sol/test_surface_joint.f90').read_text();anchor='  call backend%initialize(top);call second%initialize(top)\n'
  generated=original.replace(anchor,anchor+'  call surface_restart_contract()\n  stop\n').replace('contains\n','contains\n'+(ROOT/'tests/nut-sol/surface_restart_contract.inc').read_text()+'\n',1)
  check(generated.encode()==data['stable/'+opt+'/surface_restart.f90'],'unexecuted persistent generated driver')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed persistent command')
  for stream in ('stdout','stderr'):check('stable/'+e[stream]in data,'missing persistent raw event')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'persistent runtime checks removed')
 check(r['runs']['O0']['surface_restart']==r['runs']['O2']['surface_restart'],'persistent O0/O2 drift')
 projections=json.loads(data['review/default_projections.json'])
 check(set(projections)=={p for p,v in record['postimages'].items()if v['status']=='M'},'incomplete incumbent body review')
 for p,patches in projections.items():
  lines=(ROOT/p).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['current_range'];check(lines[a:b]==q['current'],'unreviewed persistent source island');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',PERSISTENT_BASE+':'+p],cwd=ROOT),'incumbent body not reconstructible '+p)
 return r
def persistent_qualification():
 if (ROOT/'tests/nut-sol/verify_pond_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_pond_successor as pond
  return pond.verify_qualification()
 source=persistent_source();r=persistent_record()
 check(r['phase']in ['SCIENCE_COMPLETE_ADMISSION_CONTROLS_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED','CANONICALLY_ADMITTED_PERSISTENT_SURFACE_RESTART'],'persistent science unfinished')
 persistent_science(persistent_evidence())
 base=ROOT.parent/'sol-surface-restart-incumbent-87bc1b1b'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),PERSISTENT_BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==PERSISTENT_BASE,'wrong persistent incumbent')
 check(not subprocess.check_output(['git','status','--porcelain','-uno'],cwd=base,text=True).strip(),'dirty persistent incumbent')
 old=subprocess.run([sys.executable,'-B','tests/mc-irr01/verify_material_root_successor.py'],cwd=base,capture_output=True,text=True)
 check(old.returncode==0,'persistent incumbent qualification failed '+old.stderr[-1000:]);incumbent=json.loads(old.stdout)
 check(incumbent['qualified'],'unqualified persistent incumbent')
 return {**source,'qualified':True,'scope':r['scope'],'incumbent':incumbent,'full_capability':False,
  'full_fci':'NOT_SELECTED_AFFECTED_RESTART_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent-mineral',action='store_true');a=p.parse_args()
 print(json.dumps(incumbent_mineral() if a.incumbent_mineral else verify_source() if a.source_only else verify_qualification(),indent=2))
