#!/usr/bin/env python3
"""Exact INT12-C application proof; preserves the unchanged canonical default.

This is an owner prerequisite, never a full moving-F-CI receipt.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='8a3c560dfc7a2dbfacc3050681cd170bc04ae00b'
STATUS='integration/audits/F-MIG431-INT12-C_STATUS.json'
BOOT='src/runtime/mod_fmr_production_application_bootstrap.f90'
ADAPTER='src/runtime/mod_fmr_interception_source_window_binding.f90'
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def record():return json.loads((ROOT/STATUS).read_text())['direct_application_recovery_20261016']
def verify_source(git_reader=None):
 if (ROOT/'tests/fpm/hyd_default_projection.json').exists():
  import verify_hyd_successor as hyd
  return hyd.verify_source(git_reader)
 g=git if git_reader is None else git_reader;r=record()
 check(r['base']==BASE,'unknown INT12-C base');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference','.github'),'dirty INT12-C scientific surface')
 expected=r['postimages']
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference','.github').splitlines()}
 check(rows=={p:e['status']for p,e in expected.items()},'foreign INT12-C dependency delta')
 check({p for p in expected if p.startswith('src/')}=={BOOT,ADAPTER},'INT12-C production scope widened')
 for p,e in expected.items():check(g('rev-parse','HEAD:'+p)==e['blob']==blob((ROOT/p).read_bytes()),'INT12-C postimage drift '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'INT12-C reference changed')
 for path in ['tests/root-growth/verify_swrd3_successor.py','tests/mc-met01/verify_daily_demand_successor.py']:
  current=(ROOT/path).read_text();line='sys.dont_write_bytecode=True  # Proof imports must leave the scientific checkout clean.\n'
  check(current.count(line)==1,'unknown proof import hygiene')
  check(current.replace(line,'')==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True),'incumbent proof body changed '+path)
 p=subprocess.run([sys.executable,'-B','tests/fpm/check_int12c_current_composition.py'],cwd=ROOT,capture_output=True,text=True)
 check(p.returncode==0,'incumbent default projection rejected '+p.stderr[-1000:])
 check(g('rev-parse','HEAD:'+ADAPTER)=='36f340ad425191a6149a50a21daccaf81d2bf839','original source adapter drift')
 return dict(baseline=BASE,source_tree=g('rev-parse','HEAD:src'),int12c_successor=True,co2_successor=True,
             swrd3_successor=True,swrd2_successor=True,harvest_successor=True,surface_successor=True,
             qualified=False,admitted=False)
def evidence():
 a=record()['archive'];raw=base64.b64decode((ROOT/a['path']).read_bytes())
 check(sha(raw)==a['decoded_sha256'],'INT12-C archive drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members),'unsafe INT12-C member')
  check(len({m.name for m in members})==len(members),'duplicate INT12-C member')
  data={m.name:t.extractfile(m).read()for m in members}
 check(set(data)==set(a['members']),'incomplete INT12-C archive')
 for p,h in a['members'].items():check(sha(data[p])==h,'INT12-C member corruption '+p)
 return data
def verify_qualification():
 source=verify_source();d=evidence();r=record()
 rows=json.loads(d['final/results.json'])
 drivers={'endpoint','test_ppa_wu01_production_application_bootstrap','test_ppa_wu03_common_forcing_adapter',
  'test_ppa_wu04a_black_runtime','test_ppa_wu04b_boesten_runtime','test_ppa_wu04a_black_process',
  'test_ppa_wu04b_boesten_process','test_rutter_output_binding'}
 check(len(rows)==16 and {(x['driver'],x['optimization'])for x in rows}=={(n,o)for n in drivers for o in (0,2)},'incomplete INT12-C owner results')
 for x in rows:check(x['returncode']==0 and not x['missing_markers'],'failed INT12-C native result')
 for n in drivers:
  name='' if n=='endpoint'else n+'-'
  check(d['final/'+name+'o0.txt']==d['final/'+name+'o2.txt'],'INT12-C optimization drift '+n)
 prior=json.loads((ROOT/STATUS).read_text())['application_recovery_20261016']['archive']
 raw=base64.b64decode((ROOT/prior['path']).read_bytes())
 check(sha(raw)==prior['decoded_sha256'],'previous owner archive drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for n in drivers-{'endpoint'}:
   for opt in (0,2):
    name=n+'-o'+str(opt)+'.txt';old=t.extractfile('owners/'+name).read()
    # Exact known source-line relocation in unchanged compiler diagnostics.
    # Preserve their text/count and every numerical/scientific output byte.
    before=subprocess.check_output(['git','show','d694ea1e5b381188e0057e13434f2e43b4e194f6:'+BOOT],cwd=ROOT).splitlines()
    after=(ROOT/BOOT).read_bytes().splitlines()
    for a,b in [(359,397),(460,498)]:
     check(before[a-1]==after[b-1],'diagnostic source statement changed')
     text=' of file '+BOOT+'\nFortran runtime warning: An array temporary was created\n'
     old=old.replace(('At line '+str(a)+text).encode(),('At line '+str(b)+text).encode())
    check(d['final/'+name]==old,'immutable incumbent native output drift '+name)
 output=d['final/o0.txt']
 for marker in [b'INT12C_DIRECT_PMDIRECT_DYNAMIC_TOP_ACTIVE_ROOT_COMMITS=PASS',
  b'INT12C_DIRECT_WET_DRY_DEMAND_AND_PHYSICAL_MASS=PASS',b'INT12C_DIRECT_UPSTREAM_REJECTION_AND_OPTIN_BOUNDARY=PASS',
  b'INT12C_REAL_APPLICATION_TWO_COLUMN_ROLLBACK_AND_RETRY=PASS']:
  check(marker in output,'INT12-C scientific marker absent')
 check(output.count(b'INT12C_DIRECT_ENDPOINT=')==8,'incomplete wet/dry actual endpoints')
 inputs=json.loads(d['final/compile_sources.json']);check({BOOT,ADAPTER}<={x['path']for x in inputs},'production not compiled')
 for x in inputs:
  raw=(ROOT/x['path']).read_bytes()
  if source.get('hyd_successor') and x['path'] in json.loads((ROOT/'tests/fpm/hyd_default_projection.json').read_text())['files']:
   import verify_hyd_successor as hyd
   raw=hyd.projected_bytes(x['path'])
  check(sha(raw)==x['sha256'],'stale INT12-C provider '+x['path'])
 for path in [BOOT,'tests/fpm/run_int12c_real_endpoint.py','tests/fpm/test_int12c_application.inc']:
  check(d['inputs/'+path]==(ROOT/path).read_bytes(),'INT12-C executed input drift '+path)
 check(b'INT12C_OUTPUT_SHA256=98e323ef612c82510d6dd3e5741c4d51b324051db7c13a6846d14798ed194717' in d['component-preservation.log'],'original component output changed')
 # Existing default code is projected byte-exact, not merely declared unchanged.
 # Validate actual admitted evidence at its immutable canonical checkout.
 base=ROOT.parent/'int12c-incumbent-8a3c560d'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'INT12-C incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'INT12-C incumbent dirty')
 p=subprocess.run([sys.executable,'-B','tests/crop-harvest/verify_harvest_successor.py'],cwd=base,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(p.returncode==0,'actual canonical incumbent evidence rejected '+p.stderr[-1200:])
 old=json.loads(p.stdout);check(old['qualified'],'canonical incumbent not qualified')
 if source.get('hyd_successor'):
  import verify_hyd_successor as hyd
  check(hyd.verify_qualification()['qualified'],'HYD owner evidence failed')
 return {**source,'qualified':True,'incumbent_owner':old,'preservation':'BYTE_EXACT_DEFAULT_PROJECTION_AND_FRESH_OWNERS_PLUS_DIRECT_PHYSICAL_SCIENCE',
         'full_fci':'NOT_CLAIMED_OWNER_PREREQUISITE_ONLY','highest':'NOT_SELECTED_UNCHANGED_DEPENDENCY'}
if __name__=='__main__':
 print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
