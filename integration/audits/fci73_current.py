"""Bounded F-CI73 moving successor; preserves historical pins and original science."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/f-ci/F-CI73P_STATUS.json'
WORKFLOW='.github/workflows/fci73-fgc25-moving-preservation.yml'
PROGRAMS=('multiswap_commit','single_tile_equivalence','multiswap_qualification','corrector_tile_fail_closed','permutation_determinism','multicell_isolation')
ORACLE='de9a811ebb3a85bf14c440350fb730b0fab8f576c06683f1265757669542d9d8'
FLAGS=['-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror','-Wno-error=compare-reals','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
def check(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['current_successor_20261018']
def verify_source():
 s=record();git('merge-base','--is-ancestor',s['baseline'],'HEAD')
 check(not git('diff',s['baseline'],'HEAD','--','src','reference'),'F-CI73 production/reference changed')
 check(not git('status','--porcelain','--','src','tests','tools','reference','.github','integration/audits/fci73_current.py'),'dirty F-CI73 source')
 check(sha(Path(__file__).read_bytes())==s['validator_sha256'],'F-CI73 validator identity')
 check(sha((ROOT/WORKFLOW).read_bytes())==s['workflow_sha256'],'F-CI73 workflow identity')
 for p,v in s['successor_blobs'].items():
  check(git('rev-parse',s['historical_admission']+':'+p)==v['historical'],'F-CI73 historical source drift '+p)
  check(git('hash-object',p)==v['current'],'F-CI73 unknown source successor '+p)
 return dict(source=True,production_changed=False,qualified=False)
def evidence():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'F-CI73 capsule integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==len({m.name for m in ms}) and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'F-CI73 unsafe capsule');f={m.name:t.extractfile(m).read()for m in ms}
 m=json.loads(f.pop('MANIFEST.json'));check(set(m)==set(f),'F-CI73 capsule inventory')
 for p,h in m.items():check(sha(f[p])==h,'F-CI73 raw member '+p)
 return f
def validate(f):
 r=json.loads(f['result.json']);check(r['status']=='CURRENT_FGC25_OWNER_AND_FVQ87_O0_O2_PASS','F-CI73 unfinished science')
 check(r['execution_commit']==record()['execution_commit'],'F-CI73 unbound native execution')
 check(r['owner_exit']==r['independent_exit']==0 and r['baseline_workflow_exit']==1,'F-CI73 execution result')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'F-CI73 native input drift '+p)
 log=f['owner.stdout'].decode();check(log.rstrip().endswith('F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS'),'F-CI73 original owner gate absent')
 ee=json.loads(f['compiler-events.json']);check(len(ee)==14 and all(e['returncode']==0 for e in ee),'F-CI73 compiler execution')
 for e in ee:check(e['args'][:len(FLAGS)]==FLAGS,'F-CI73 changed numerical/warning flags')
 for opt in [0,2]:
  for name in PROGRAMS:
   driver='tests/fgc/test_fgc25_'+name+'.f90';marker='FGC25_test_fgc25_'+name+f'_O{opt}=PASS'
   check(log.count(marker)==1,'F-CI73 missing owner case '+marker)
   check(sum(f'-O{opt}'in e['args']and driver in e['args']for e in ee)==1,'F-CI73 original driver not compiled '+driver)
 c=json.loads(f['independent/CONTROL.json']);check(c['status']=='PASS'and len(c['records'])==2,'F-CI73 incomplete independent oracle')
 check(c['driver_blob']=='338416575b1583152acc65cd606c4322a20dd94d','F-CI73 independent driver replaced')
 original=subprocess.check_output(['git','show',c['fixture_owner']+':tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'],cwd=ROOT)
 marker=b'\nprogram test_fgc21_restricted_predictor_corrector_window\n';check(original.count(marker)==1,'F-CI73 original fixture boundary')
 fixture=f['independent/fgc21_fixture.f90'];check(fixture==original.split(marker)[0]+b'\n' and sha(fixture)==c['fixture_sha256'],'F-CI73 historical fixture drift')
 for p,h in c['dependency_blobs'].items():check(git('hash-object',p)==h,'F-CI73 independent dependency '+p)
 check({e['opt']for e in c['records']}=={0,2},'F-CI73 missing independent optimization')
 for e in c['records']:
  opt=e['opt'];check(e['compile_exit']==e['run_exit']==0,'F-CI73 failed independent execution')
  check(sha(f[f'independent/o{opt}/output.stdout'])==e['stdout_sha256']==ORACLE,'F-CI73 historical oracle drift')
  check(e['command'][1:1+len(FLAGS)]==FLAGS and f'-O{opt}'in e['command'],'F-CI73 independent flags')
  check(any(a['args']==e['command'][1:]for a in ee),'F-CI73 independent compiler unrecorded')
 return dict(qualified=True,owner_cases=12,independent_cases=2,oracle_exact=True,production_changed=False)
def verify_science():return {**verify_source(),**validate(evidence())}
def main():
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--self-test',action='store_true');a=p.parse_args();print(json.dumps(verify_source()if a.source_only else verify_science(),indent=2))
 if a.self_test:
  import copy
  f=evidence();passed=[]
  def reject(name,fn):
   d=copy.deepcopy(f);fn(d)
   try:validate(d)
   except(ValueError,KeyError,IndexError):passed.append(name);return
   raise AssertionError('accepted '+name)
  def edit(d,p,fn):
   r=json.loads(d[p]);fn(r);d[p]=json.dumps(r).encode()
  reject('missing owner case',lambda d:d.__setitem__('owner.stdout',d['owner.stdout'].replace(b'FGC25_test_fgc25_multiswap_commit_O0=PASS',b'')))
  reject('oracle raw corruption',lambda d:d.__setitem__('independent/o2/output.stdout',b'PASS'))
  reject('unchecked compiler',lambda d:edit(d,'compiler-events.json',lambda es:es[0]['args'].remove('-fcheck=all')))
  reject('missing compiler invocation',lambda d:edit(d,'compiler-events.json',lambda es:es.pop()))
  reject('failed compiler',lambda d:edit(d,'compiler-events.json',lambda es:es[0].__setitem__('returncode',1)))
  reject('missing independent optimization',lambda d:edit(d,'independent/CONTROL.json',lambda c:c['records'].pop()))
  reject('fixture drift',lambda d:d.__setitem__('independent/fgc21_fixture.f90',b'!'))
  reject('unbound input',lambda d:edit(d,'result.json',lambda r:r['input_sha256'].__setitem__('src/runtime/mod_groundwater_multiswap_topology.f90','0'*64)))
  reject('unfinished science',lambda d:edit(d,'result.json',lambda r:r.__setitem__('status','RUNNING')))
  reject('unbound execution',lambda d:edit(d,'result.json',lambda r:r.__setitem__('execution_commit','0'*40)))
  print(json.dumps(dict(negative_controls=passed,count=len(passed))))
if __name__=='__main__':main()
