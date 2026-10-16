"""Reference-only successor; preserve immutable source-bound incumbent evidence."""
from pathlib import Path
from functools import lru_cache
import importlib.util,json,os,subprocess,sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[4]
BASE='5bacc7419f5ad73614f8e55b1d0c7c88706da00c'
ORIGIN='49f3434df92fa4864dda5cd06c80ad32dfb32f38'
SURFACE=['src','tests','tools','reference','.github']
def require(ok,label):
 if not ok:raise ValueError(label)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def load():
 s=importlib.util.spec_from_file_location('swap019_science',Path(__file__).parent/'tests/verify.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def record():return json.loads((ROOT/'integration/audits/MC_NUT_SOL_STATUS.json').read_text())['leaf_reference_admission_20261016']
def check_current():
 r=record();git('merge-base','--is-ancestor',BASE,'HEAD')
 require(r['baseline']==ORIGIN and r['reconciled_base']==BASE and not git('status','--porcelain','--',*SURFACE),'dirty or moved reference successor')
 rows={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 require(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign reference successor surface')
 require(all(not p.startswith('src/')for p in rows),'production source changed')
 require(git('rev-parse','HEAD:src')==git('rev-parse',BASE+':src'),'production source tree changed')
 for p,v in r['postimages'].items():require(git('rev-parse','HEAD:'+p)==v['blob'],'reference successor postimage '+p)
 require(not git('diff',BASE,'HEAD','--','reference/swap-4.3.1/b0','reference/swap-4.3.1/snapshots/B1.11.yml'),'immutable predecessor drift')
 require(not git('diff',BASE,'HEAD','--','src','tests/nut-crop','reference/swap-4.3.1/b1_11_frost_source'),'incumbent scientific input drift')
 return r
@lru_cache(None)
def incumbent(source_only):
 root=ROOT.parent/('leaf-reference-incumbent-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'incumbent moved')
 command=[sys.executable,'-B','tests/nut-crop/verify_reproductive_successor.py']+(['--source-only']if source_only else [])
 env=os.environ.copy();n=int(env.get('GIT_CONFIG_COUNT','0'));env['GIT_CONFIG_KEY_'+str(n)]='core.abbrev';env['GIT_CONFIG_VALUE_'+str(n)]='8';env['GIT_CONFIG_COUNT']=str(n+1)
 p=subprocess.run(command,cwd=root,env=env,capture_output=True,text=True)
 require(p.returncode==0,'incumbent owner rejected '+p.stderr[-1200:]);r=json.loads(p.stdout)
 if not source_only:require(r['qualified']and r['classic_annual_successor'],'incomplete current annual incumbent evidence')
 return r
def run_predecessor_controls():
 incumbent(False)
 root=ROOT.parent/('leaf-reference-incumbent-'+BASE[:12])
 p=subprocess.run([sys.executable,'-B','tests/fmig431/verify_signed_divdra_successor.py','--self-test'],cwd=root,capture_output=True,text=True)
 require(p.returncode==0 and 'MC_DRAIN01_EVIDENCE_CORRUPTION_CONTROLS=6'in p.stdout,'preserved predecessor corruption controls')
 print(p.stdout,end='')
def verify_source():
 if (ROOT/'tests/fmig431/verify_multilevel_divdra_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_multilevel_divdra_successor as drain
  return drain.verify_source()
 check_current();return {**incumbent(True),'reference_leaf_successor':True,'qualified':False,'reference_snapshot':'B1.12','production_reference_pins_unchanged':True}
def verify_qualification():
 if (ROOT/'tests/fmig431/verify_multilevel_divdra_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_multilevel_divdra_successor as drain
  return drain.verify_qualification()
 check_current();spec=importlib.util.spec_from_file_location('swap019_admission',ROOT/'tools/vq/b1_12_admission_gate.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate);gate.verify();m=load();data=m.unpack();science=m.validate(data);require(m.self_test(data)==9,'reference negative controls')
 return {**incumbent(False),'reference_leaf_successor':True,'qualified':True,'reference_snapshot':'B1.12','reference_science':science,'SWAP5_partial_return_admitted':False,'full_fci':'NOT_SELECTED_IMPACT'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
