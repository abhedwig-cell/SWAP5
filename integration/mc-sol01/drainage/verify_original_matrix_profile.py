"""Source/raw authority for a reproduced excluded full-profile failure."""
import argparse,base64,csv,hashlib,io,json,runpy,subprocess,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='146823954f2a24e43b6e007591ef2876331daa9d';D='integration/mc-sol01/drainage/';STATUS=D+'ORIGINAL_MATRIX_PROFILE_STATUS.json';sha=lambda b:hashlib.sha256(b).hexdigest()
def source(reader=lambda p:(ROOT/p).read_bytes()):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['stage']=='REPRODUCED_TECHNICAL_BLOCKER'and not s['qualified']
 assert not subprocess.check_output(['git','diff',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT)
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 return s

def capsule():
 e=source()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len(members)==e['members']==len({m.name for m in members})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  f={m.name:t.extractfile(m).read()for m in members}
 manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(b)for p,b in f.items()};return f

def validate(f):
 results=[];rows=lambda b:list(csv.DictReader(io.StringIO(b.decode())))
 for opt in ['O0','O2']:
  pre=opt+'/';r=json.loads(f[pre+'BLOCKER.json']);a=json.loads(f[pre+'RESULT.json']);assert r['status']=='REPRODUCED_ORIGINAL_MATRIX112_DAY10_WATER_REJECTION'and r['baseline']==BASE
  assert not r['qualified']and not r['canonically_admitted']and not r['full481_qualified']and not r['production_edited'];assert r['optimization']==opt
  assert len(a['events'])==1 and a['events'][0]['label']=='full'and a['events'][0]['returncode']==1
  assert len(r['events'])==5 and all(e['returncode']==1 for e in r['events'])and r['rejected_source_selections']==4
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h==sha(f['executed/'+p]),p
  for key in ['rejection_restart_exact','committed_state_unchanged','partial_candidate_unchanged','no_failed_generation_published']:assert r[key]
  failure=r['failure'];assert failure==dict(window=10,completed_rain_segments=0,attempts=324,solver_rejections=134,temporal_rejections=175,mass_rejections=0,thermal_status=0)
  full=next(p[:-len('stdout')]for p in f if p.startswith(pre+'full.pending-')and p.endswith('/stdout'))
  restart=next(p[:-len('stdout')]for p in f if p.startswith(pre+'restart-rejected.pending-')and p.endswith('/stdout'))
  stdout=f[full+'stdout'];assert stdout==f[restart+'stdout']and b'rejected window/process/completed:          10           0           0'in stdout and b'324         134         175           0'in stdout and b'rejected thermal status:           0'in stdout
  prefix=r['accepted_prefix'];assert prefix['days']==9 and prefix['nodes']==112;results.append(prefix)
  raw=f[pre+'day9/restart.bin'];assert raw[:8]==b'S5PT0002'and len(raw)==53232
  for p in [full,restart]:assert f[p+'diagnostic-rejected.bin']==raw==f[p+'diagnostic-partial-candidate.bin']
  for p,h in prefix['files'].items():assert sha(f[pre+'day9/'+p])==h
  budget=rows(f[pre+'day9/budget.csv']);assert budget==prefix['budget']and len(budget)==9 and f[full+'budget.csv']==f[pre+'day9/budget.csv']
  for r0 in budget:
   assert abs(float(r0['water_residual_cm']))<1e-10 and abs(float(r0['solute_residual_mg_cm2']))<1e-10 and 0<=float(r0['observed_heat_residual_j_cm2'])<=1e-9
   assert abs(float(r0['potential_transpiration_cm'])-float(r0['actual_transpiration_cm'])-float(r0['drought_reduction_cm'])-float(r0['oxygen_reduction_cm']))<1e-12
   gross=float(r0['water_end_cm'])-float(r0['water_start_cm'])-float(r0['rain_supplied_cm'])+float(r0['runoff_cm'])+float(r0['soil_evaporation_cm'])+float(r0['pond_evaporation_cm'])+float(r0['actual_transpiration_cm'])-float(r0['bottom_up_cm'])+float(r0['drainage_cm']);assert abs(gross)<1e-10
  state=rows(f[pre+'day9/state.csv']);assert len(state)==112
  assert all(min(float(r0[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for r0 in state)
  # Verify declared projections against literal original compressed authority.
  with tempfile.TemporaryDirectory()as tmp:
   folder=Path(tmp)/'source';provenance=runpy.run_path(str(ROOT/(D+'qualify_original_matrix_profile.py')))['fixture'](folder)
   assert provenance==r['source_provenance']==a['original_sources']
   for name,v in provenance.items():assert (folder/name).read_bytes()==f[pre+'project/'+name]and sha(f[pre+'project/'+name])==v['executed_sha256']
 assert results[0]==results[1]
 frozen=next(p[:-len('stdout')]for p in f if p.startswith('frozen/full.pending-')and p.endswith('/stdout'));assert b'rejected window/process/completed:           3           0           0'in f[frozen+'stdout']
 return dict(status='BLOCKER_EVIDENCE_VERIFIED',reproduced_optimizations=2,separate_process_reproductions=2,prefix_days=9,prefix_nodes=112,failed_generation_publications=0,committed_state_byte_exact=True,original_full_profile_qualified=False,production_unchanged=True,work_packages='MC-NUT01/MC-SOL01 remain CLOSED WITH EXCLUSIONS')

def verify():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupted profile proof '+name)
 p=D+'qualify_original_matrix_profile.py';reject('source',lambda:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 for p in ['O0/day9/restart.bin','O2/day9/budget.csv','O0/project/wintcer1.crp']:
  bad=dict(f);bad[p]+=b'!';reject(p,lambda bad=bad:validate(bad))
 p='O2/BLOCKER.json';bad=dict(f);r=json.loads(bad[p]);r['full481_qualified']=True;bad[p]=json.dumps(r).encode();reject('false full qualification',lambda:validate(bad))
 p=next(p for p in f if p.startswith('O0/full.pending-')and p.endswith('/stdout'));bad=dict(f);bad[p]=bad[p].replace(b'324',b'323');reject('solver receipt',lambda:validate(bad))
 return passed
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--self-test',action='store_true');a=p.parse_args();print(json.dumps(self_test()if a.self_test else verify(),indent=2))
