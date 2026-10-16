#!/usr/bin/env python3
"""Qualify one unused source-policy component, never production N admission."""
from pathlib import Path
import base64,hashlib,io,json,os,re,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[3]
BASE='be8a49cd59815b537b46e0dac2b3d0161366c796'
STATUS='integration/audits/MC_NUT_SOL_STATUS.json'
PROVIDER='src/crop/mod_b111_nfixation_policy.f90'
SURFACE=['src','tests','tools','reference','.github']
DISPATCH='''          if [[ -f src/crop/mod_b111_nfixation_policy.f90 ]]; then
            # Exact additive source-policy proof; no N runtime admission.
            python3 -B tests/fwof/pp02/verify_b111_nfixation_successor.py
          el'''
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['component_closeout_20261016']
def verify_source(git_reader=None):
 if (ROOT/'tests/mc-irr01/verify_managed_weather_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_managed_weather_successor as managed
  return managed.verify_source(git_reader)
 g=git if git_reader is None else git_reader;r=record();g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--',*SURFACE),'dirty NFIX source')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 expected=r['postimages'];check(rows=={p:x['status']for p,x in expected.items()},'foreign NFIX dependency delta')
 check({p for p in rows if p.startswith('src/')}=={PROVIDER} and rows[PROVIDER]=='A','existing production owner changed')
 for p,x in expected.items():check(g('rev-parse','HEAD:'+p)==x['blob']==blob((ROOT/p).read_bytes()),'NFIX postimage drift '+p)
 workflow='.github/workflows/fci-canonical.yml';s=(ROOT/workflow).read_text()
 check(s.count(DISPATCH)==1,'NFIX owner dispatch unknown')
 check(s.replace(DISPATCH,'          ')==subprocess.check_output(['git','show',BASE+':'+workflow],cwd=ROOT,text=True),'incumbent FCI workflow body drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'NFIX reference changed')
 for p in (ROOT/'src').rglob('*.f90'):
  if p.relative_to(ROOT).as_posix()!=PROVIDER:
   check(not re.search(r'\buse\s*(?:::\s*)?mod_b111_nfixation_policy\b',p.read_text(),re.I),'unqualified NFIX production caller')
 return {'baseline':BASE,'source_tree':g('rev-parse','HEAD:src'),'source_component_only':True,'qualified':False,'production_runtime_admission':False,'full_capability':False}
def evidence():
 a=record()['evidence'];raw=base64.b64decode((ROOT/a['path']).read_bytes());check(sha(raw)==a['decoded_sha256'],'NFIX archive corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();check(len(members)==a['members']==len({x.name for x in members}),'NFIX archive members')
  check(all(x.isfile()and not Path(x.name).is_absolute()and '..'not in Path(x.name).parts for x in members),'unsafe NFIX archive')
  data={x.name:t.extractfile(x).read()for x in members}
 check(set(data)==set(a['member_sha256']),'incomplete NFIX archive')
 for p,h in a['member_sha256'].items():check(sha(data[p])==h,'NFIX member drift '+p)
 return data
def incumbent():
 base=ROOT.parent/'nfix-incumbent-be8a49cd'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'NFIX incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain'],cwd=base,text=True).strip(),'NFIX incumbent dirty')
 p=subprocess.run([sys.executable,'-B','tests/fpm/verify_int12c_successor.py'],cwd=base,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(p.returncode==0,'unchanged incumbent proof failed '+p.stderr[-1200:]);r=json.loads(p.stdout);check(r['qualified'],'incumbent not qualified');return r

def verify_qualification():
 if (ROOT/'tests/mc-irr01/verify_managed_weather_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_managed_weather_successor as managed
  return managed.verify_qualification()
 source=verify_source();d=evidence();literal=json.loads(d['literal/result.json'])
 check(literal['cases']==593 and literal['quantities_per_case']==3,'incomplete NFIX corpus')
 check(literal['pass']and literal['byte_identity'],'NFIX oracle failed')
 check(set(literal['optimizations'])=={'O0','O2'},'NFIX optimization absent')
 for opt,v in literal['optimizations'].items():
  out=d['literal/'+opt+'.stdout'];check(v['exit']==0 and sha(out)==v['stdout_sha256'],'failed NFIX native')
  check(out.count(b'NFIX_LITERAL_CASE=')==593 and b'B111_NFIX_LITERAL_CASES=593|MISMATCHES=0' in out,'missing NFIX numerical evidence')
 check(d['literal/O0.stdout']==d['literal/O2.stdout'],'NFIX O0/O2 drift')
 for p,h in literal['source_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'stale NFIX literal input '+p)
 for p,h in json.loads(d['component/inputs.json']).items():check(sha((ROOT/p).read_bytes())==h,'stale NFIX component input '+p)
 out=d['component/native.log']
 check(out.count(b'B111_NFIXATION_POLICY_PASS')==2 and out.count(b'B111_NFIX_INVALID_CASES=39')==2,'NFIX unit/invalid proof absent')
 check(out.count(b'SWAP431_WOF81_07_N_ARBITRATION_PASS cases=1806')==2 and out.count(b'SWAP431_WOF81_04_EDGE_PASS')==2,'unchanged WOFOST81 science absent')
 check(b'NFIX_UNCHANGED_WOFOST81_OWNERS_O0_O2=PASS' in out,'WOFOST81 optimization identity absent')
 old=incumbent()
 return {**source,'qualified':True,'incumbent_owner':old,'preservation':'EXACT_ADDITIVE_UNUSED_COMPONENT_PLUS_UNCHANGED_NATIVE_WOFOST81_OWNERS','full_fci':'NOT_SELECTED_IMPACT_COMPONENT_ONLY','highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
