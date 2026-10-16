#!/usr/bin/env python3
"""Source-bound DISLAYER admission with original immutable owner validation."""
from pathlib import Path
from functools import lru_cache
import argparse,base64,copy,gzip,hashlib,importlib.util,json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json';PHASE='dislayer_phase_20261016'
BASE='c9231e1b102f9666865ced5604ef04d135b3931e'
FROZEN='2ea0795f57ebcf8aad49e7e82d803c887957292b'
SURFACE=['src','tests','tools','reference','.github']
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def old(path,ref=BASE):return subprocess.check_output(['git','show',ref+':'+path],cwd=ROOT)
def capsule(e):
 raw=base64.b64decode((ROOT/e['path']).read_bytes());require(sha(raw)==e['sha256'],'archive integrity '+e['path']);return json.loads(gzip.decompress(raw))
def verify_reference(p,reader=lambda q:(ROOT/q).read_bytes()):
 e=p['reference_qualification'];require(e['qualified'],'unqualified B1 component');r=capsule(e['evidence'])
 manifest='reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-04/manifest.json';m=json.loads(reader(manifest));parent=reader(m['parent']['path'])
 require(m['qualified']and sha(parent)==m['parent']['sha256']==e['parent_sha256'],'B1 parent drift')
 require(parent==old(m['parent']['path']),'prior admitted reference modified')
 out=parent
 expected=[('if (abs(sumqdr) < 1.0d-8) then','if (sumqdr == 0.0d0) then'),('if (abs(sumqdr) < 1.d-8 .AND. abs(qdrain(idr)) > 1.d-8) then','if (sumqdr == 0.0d0 .AND. qdrain(idr) /= 0.0d0) then')]
 require([(x['old'],x['new'])for x in m['patches']]==expected,'expanded B1 correction')
 for a,b in expected:require(out.count(a.encode())==1,'B1 patch shape');out=out.replace(a.encode(),b.encode())
 require(out==reader(m['materialized_reference'])and sha(out)==m['candidate_sha256']==e['source_sha256'],'B1 exact reconstruction')
 results=r['result']['results'];require(len(results)==4 and {(x['case'],x['optimization'])for x in results}=={(c,o)for c in['original03','corrected04']for o in(0,2)},'B1 native executions missing')
 require(all(x['returncode']==0 for x in r['result']['events']),'failed B1 native command')
 module_path=ROOT/'tests/fmig431/run_swap431_dislayer_reference.py';spec=importlib.util.spec_from_file_location('dislayer_reference_validator',module_path);v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
 binaries={}
 for row in results:
  for path,h in row['inputs'].items():require(sha(reader(path))==h,'B1 input drift '+path)
  require('-fcheck=all'in row['flags']and'-ffpe-trap=invalid,zero,overflow'in row['flags'],'unchecked B1 native')
  raw=base64.b64decode(r['binary'][row['binary_path']]);require(sha(raw)==row['binary_sha256'],'B1 raw nodes drift');binaries[row['case'],row['optimization']]=raw
 for opt in(0,2):require(v.validate(v.parse(binaries['original03',opt]),v.parse(binaries['corrected04',opt]))==r['result']['science'][opt//2],'B1 independent conservation/source oracle')
 for name in ['original03','corrected04']:require(binaries[name,0]==binaries[name,2],'B1 optimization drift')
 controls=r['applicator_controls'];require(len(controls)==4 and {x['case']for x in controls}=={'valid','occupied','same-path','wrong-parent'},'B1 applicator controls')
 require(all((x['returncode']!=0)==x['expected_rejection']for x in controls),'B1 applicator rejection failed')
 return True
def verify(s,r):
 p=s[PHASE];require(p['qualified']is True,'DISLAYER not qualified');require(p['ledger_rows']==['SW431-DRAIN-DISLAYER'],'DISLAYER scope')
 frozen=json.loads(old(STATUS,FROZEN))[PHASE]
 for k in ['baseline','existing_candidate','existing_branch','ledger_rows','conditions_frozen','excluded','invariants']:require(p[k]==frozen[k],'frozen condition drift '+k)
 rows=r['result']['results'];cases={'dislayer_contract','dislayer_guards','inf_contract','multilevel_contract','signed_contract','positive_process','positive_binder','dislayer_runtime','inf_runtime','multi_runtime','signed_runtime'}
 require(len(rows)==22 and {(x['case'],x['optimization'])for x in rows}=={(c,o)for c in cases for o in(0,2)},'incomplete production/native preservation')
 for path,h in p['qualification_inputs_sha256'].items():require(sha((ROOT/path).read_bytes())==h,'harness drift '+path)
 require(all(x['returncode']==0 for x in r['result']['events']),'failed final execution')
 for row in rows:
  require('-fcheck=all'in row['flags']and'-ffpe-trap=invalid,zero,overflow'in row['flags'],'unchecked production')
  for path,h in row['inputs'].items():require(sha((ROOT/path).read_bytes())==h,'production dependency drift '+path)
  output=r['outputs'][row['case']+':'+str(row['optimization'])];require(sha(output.encode())==row['stdout_sha256'],'raw production output drift')
  pair=next(x for x in rows if x['case']==row['case']and x['optimization']!=row['optimization']);require(pair['stdout_sha256']==row['stdout_sha256'],'production optimization drift')
  if row['case']=='dislayer_contract':require('25920'in output and'DISLAYER_CORRECTED_SOURCE_REAL_BINDER_MATRIX=PASS'in output,'full real binder matrix')
  if row['case']=='dislayer_guards':require('DISLAYER_INVALID_CASES=20 SHAPE=2 OWNERSHIP=1 PREBOUND=1 DEFAULT_EXACT=3 DIRECT_NONMUTATION=2'in output,'invalid/default guards')
  if row['case'].endswith('_runtime'):
   prefix='SW431_'+{'dislayer_runtime':'DISLAYER','inf_runtime':'INF','multi_runtime':'MULTI','signed_runtime':'SIGNED'}[row['case']]
   count=288 if row['case']=='dislayer_runtime'else 48 if row['case']=='inf_runtime'else 24
   require(output.count(prefix+'_SINGLE ')==count,'runtime cases missing')
   require(output.count(prefix+'_REJECT_REPLAY_RESTART=PASS')==(48 if count==288 else 8 if count==48 else 4),'runtime lifecycle missing')
   require(output.count(prefix+'_INACTIVE_EXACT_IDENTITY=PASS')==(24 if count==288 else 4 if count==48 else 2),'runtime inactive missing')
   require(output.count(prefix+'_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS')==(12 if count==288 else 2 if count==48 else 1),'runtime isolation missing')
   require(prefix+'_FAIL_CLOSED_PREMUTATION_MATRIX=PASS'in output,'runtime preflight missing')
 b=r['b18'];require(b['status']=='PASS'and b['accepted']==3240 and b['held']==1296 and len(b['results'])==4,'original B18 assertions missing')
 require(all(x['returncode']==0 for x in b['events']),'B18 execution failed')
 for row in b['results']:
  for path,h in row['inputs'].items():require(sha((ROOT/path).read_bytes())==h,'B18 input drift '+path)
  require(sha(r['b18_outputs'][row['variant']+':'+str(row['optimization'])].encode())==row['stdout_sha256'],'B18 raw drift')
 # Sealed complete reverse projections preserve all incumbent default formulas,
 # state/caller bodies and original owner assertions, including availability.
 for path,patches in r['default_body_projections'].items():
  lines=(ROOT/path).read_text().splitlines(True)
  for patch in reversed(patches):
   a,b=patch['range'];require(lines[a:b]==patch['current'],'reviewed insertion drift '+path);lines[a:b]=patch['baseline']
  require(''.join(lines).encode()==old(path),'default owner body drift '+path)
 for path,h in p['incumbent_unchanged_inputs'].items():
  if path in r['default_body_projections']:continue
  require(sha((ROOT/path).read_bytes())==h,'parallel incumbent science drift '+path)
 require(json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())==json.loads(old('integration/audits/MC_IRR01_STATUS.json')),'parallel admission authority drift')
 return True
@lru_cache(None)
def loaded():
 s=json.loads((ROOT/STATUS).read_text());p=s[PHASE];r=capsule(p['qualification_evidence']);verify(s,r);verify_reference(p)
 changes={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*SURFACE],cwd=ROOT,text=True).splitlines()}
 require(changes=={k:v['status']for k,v in p['successor_postimages'].items()},'foreign DISLAYER science')
 for path,e in p['successor_postimages'].items():require(blob((ROOT/path).read_bytes())==e['blob'],'unqualified DISLAYER postimage '+path)
 return s,r
@lru_cache(None)
def incumbent(source_only=False):
 namespace=ROOT.parent/'dislayer-immutable-chain';namespace.mkdir(exist_ok=True);root=namespace/('incumbent-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'incumbent moved')
 code='import sys,json;sys.path.insert(0,"tests/mc-irr01");import verify_availability_successor as v;print(json.dumps(v.'+('verify_source'if source_only else'verify_qualification')+'()))'
 cp=subprocess.run([sys.executable,'-B','-c',code],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(namespace/'python-cache')})
 require(cp.returncode==0,'original immutable availability owner rejected '+cp.stderr[-2500:]);old_result=json.loads(cp.stdout)
 if not source_only:require(old_result['qualified']and old_result['availability_successor']and old_result['inf_split_successor'],'unqualified incumbent')
 return old_result
def verify_source(git_reader=None):
 if (ROOT/'tests/mc-irr01/verify_depth_limit_successor.py').is_file():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_depth_limit_successor as successor
  return successor.verify_source(git_reader)
 require(git_reader is None,'unregistered projected reader');loaded();prior=incumbent(True)
 return {**prior,'dislayer_successor':True,'qualified':False,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()}
def verify_qualification():
 if (ROOT/'tests/mc-irr01/verify_depth_limit_successor.py').is_file():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_depth_limit_successor as successor
  return successor.verify_qualification()
 loaded();prior=incumbent(False)
 return {**prior,'incumbent':prior,'dislayer_successor':True,'qualified':True,'full_capability':True,'drainage_ledger_rows':['SW431-DRAIN-DIV-SIGNED','SW431-DRAIN-DIV-MULTI','SW431-DRAIN-INF-SPLIT','SW431-DRAIN-DISLAYER'],'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
def main():
 if (ROOT/'tests/mc-irr01/verify_depth_limit_successor.py').is_file():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_depth_limit_successor as successor
  if '--self-test'in sys.argv:
   root=ROOT.parent/'limit-incumbent-741'
   if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),'741f8a61b66dc8a91b3e18edfcb8121548b61f64'],cwd=ROOT,check=True,capture_output=True)
   require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()=='741f8a61b66dc8a91b3e18edfcb8121548b61f64','LIMIT immutable drainage moved')
   cp=subprocess.run([sys.executable,'-B','tests/fmig431/verify_dislayer_successor.py','--self-test'],cwd=root,capture_output=True,text=True)
   require(cp.returncode==0,'original DISLAYER controls rejected '+cp.stderr[-2000:]);print(cp.stdout,end='')
  print(json.dumps(successor.verify_qualification(),indent=2));return
 ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');args=ap.parse_args();s,r=loaded()
 if args.self_test:
  names=[]
  for name,edit in [('missing optimization',lambda a,b:b['result']['results'].pop()),('false qualification',lambda a,b:a[PHASE].__setitem__('qualified',False)),('relaxed condition',lambda a,b:a[PHASE]['conditions_frozen'].pop()),('expanded ledger',lambda a,b:a[PHASE]['ledger_rows'].append('SW431-DRAIN-DRAMET3')),('forged native',lambda a,b:b['outputs'].__setitem__('dislayer_runtime:0','forged')),('failed event',lambda a,b:b['result']['events'][0].__setitem__('returncode',1)),('B18 removed',lambda a,b:b['b18'].__setitem__('accepted',0)),('default projection removed',lambda a,b:b['default_body_projections']['src/process/mod_drainage_spatial_distribution.f90'].pop())]:
   a,b=copy.deepcopy(s),copy.deepcopy(r);edit(a,b)
   try:verify(a,b)
   except (ValueError,KeyError,StopIteration):names.append(name);continue
   raise ValueError('accepted '+name)
  print('DISLAYER_EVIDENCE_CORRUPTION_CONTROLS='+str(len(names)))
  refnames=[]
  for name,path in [('parent corruption','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03/divdra.f90'),('candidate corruption','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-04/divdra.f90'),('false B1 qualification','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-04/manifest.json')]:
   def bad_reader(q):
    raw=(ROOT/q).read_bytes()
    if q!=path:return raw
    if q.endswith('manifest.json'):
     m=json.loads(raw);m['qualified']=False;return json.dumps(m).encode()
    return raw+b'corrupt'
   try:verify_reference(s[PHASE],bad_reader)
   except (ValueError,KeyError):refnames.append(name);continue
   raise ValueError('accepted '+name)
  print('DISLAYER_REFERENCE_NEGATIVE_CONTROLS='+str(len(refnames)))

 verify_qualification();print('MC_DRAIN01_DISLAYER_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':main()
