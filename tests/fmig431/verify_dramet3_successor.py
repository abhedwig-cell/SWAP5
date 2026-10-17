#!/usr/bin/env python3
"""Native ordinary DRAMET3: exact source, original owner and sealed executions."""
from pathlib import Path
from functools import lru_cache
import argparse,base64,copy,gzip,hashlib,importlib.util,json,os,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
BASE='741f8a61b66dc8a91b3e18edfcb8121548b61f64'
FROZEN='7776cbab605dc53d916c56c964c47dd3c35130ab'
STATUS='integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json';PHASE='dramet3_phase_20261016'
SURFACE=['src','tests','tools','reference','.github']
ROWS=['SW431-DRAIN-DRAMET3','SW431-DRAIN-ALLOCATION','SW431-DRAIN-INF-LIMIT']
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def old(path,ref=BASE):return subprocess.check_output(['git','show',ref+':'+path],cwd=ROOT)
def capsule(e):
 raw=base64.b64decode((ROOT/e['path']).read_bytes());require(sha(raw)==e['sha256'],'capsule checksum');return json.loads(gzip.decompress(raw))
def extracted():
 raw=(ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/drainage.f90').read_bytes();require(sha(raw)=='48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc','original source drift')
 member=next(m for m in json.loads((ROOT/'integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json').read_text())['members']if m['path']=='SWAP/functions.f90');fraw=gzip.decompress(base64.b64decode(member['gzip_base64']));require(sha(fraw)==member['sha256'],'original functions drift')
 a=re.search(r'^\s*subroutine drainflux_basic\s*\(\).*?^\s*end subroutine drainflux_basic',raw.decode(),re.M|re.S|re.I).group().encode();b=re.search(r'^\s*real\(8\) function afgen .*?^\s*end function afgen',fraw.decode(),re.M|re.S|re.I).group().encode()
 return {'original_drainflux_basic.f90':sha(a),'original_afgen.f90':sha(b),'baseline_response_binding.f90':sha(old('src/runtime/mod_fmr_drainage_response_binding.f90'))}
def verify(s,r):
 p=s[PHASE];require(p['qualified']and p['ledger_rows']==ROWS,'unqualified/scope changed')
 frozen=json.loads(old(STATUS,FROZEN))[PHASE]
 for k in ['baseline','existing_candidate','existing_branch','ledger_rows','conditions_frozen','excluded','invariants','owned_surface','interfaces_allowed_to_change','interfaces_held_fixed']:require(p[k]==frozen[k],'frozen condition drift '+k)
 base=json.loads(old(STATUS))
 for k in base:
  if k!='next_action':require(s[k]==base[k],'prior admission metadata modified '+k)
 for name in ['integration/audits/MC_IRR01_STATUS.json']:
  require((ROOT/name).read_bytes()==old(name),'parallel authority drift '+name)
 expected={'dramet3_contract','dramet3_runtime','dislayer_runtime','signed_runtime','response_baseline','response_current'}
 rows=r['runtime']['results']+r['defaults']['results']
 require(len(rows)==12 and{(x['case'],x['optimization'])for x in rows}=={(c,o)for c in expected for o in(0,2)},'missing native qualification')
 generated=extracted()
 for result in [r['runtime'],r['defaults']]:require(all(e['returncode']==0 for e in result['events']),'failed final qualification')
 for row in rows:
  require('-fcheck=all'in row['flags']and'-ffpe-trap=invalid,zero,overflow'in row['flags'],'unchecked native')
  require(row['compiler_identity']['launcher_sha256']and row['compiler_identity']['-print-prog-name=f951']['sha256'],'missing compiler identity')
  for path,h in row['inputs'].items():
   if Path(path).is_absolute():require(Path(path).name in generated and generated[Path(path).name]==h,'unqualified generated source')
   else:require(sha((ROOT/path).read_bytes())==h,'compiled dependency drift '+path)
  output=r['outputs'][row['case']+':'+str(row['optimization'])];require(sha(output.encode())==row['stdout_sha256'],'forged raw output')
  pair=next(x for x in rows if x['case']==row['case']and x['optimization']!=row['optimization']);require(pair['stdout_sha256']==row['stdout_sha256'],'optimization drift')
  if row['case']=='dramet3_contract':require('DRAMET3_COMPLETE_SOURCE_BINDER_CASES=3888'in output and'DRAMET3_INVALID_AND_UNDEFINED_CONTROLS=20'in output,'incomplete source matrix')
  if row['case']=='dramet3_runtime':
   require(output.count('DRAMET3_PHYSICAL=')==144 and output.count('DRAMET3_REJECT_REPLAY_RESTART=PASS')==2 and output.count('DRAMET3_TWO_COLUMN_ISOLATION=PASS')==2 and'DRAMET3_INVALID_RUNTIME_PREMUTATION=4 PASS'in output,'incomplete real lifecycle')
  if row['case']in ['dislayer_runtime','signed_runtime']:
   pref='SW431_'+('DISLAYER'if row['case']=='dislayer_runtime'else'SIGNED');count=288 if row['case']=='dislayer_runtime'else 24
   require(output.count(pref+'_SINGLE ')==count and output.count(pref+'_REJECT_REPLAY_RESTART=PASS')==(48 if count==288 else 4),'incomplete incumbent physical assertions')
  if row['case'].startswith('response_'):require('RESPONSE_DEFAULT_PRESERVATION_CASES=297'in output,'incomplete default binder')
 require(len({x['stdout_sha256']for x in rows if x['case'].startswith('response_')})==1,'old response output changed')
 for path,patches in r['default_body_projections'].items():
  lines=(ROOT/path).read_text().splitlines(True)
  for patch in reversed(patches):
   a,b=patch['range'];require(lines[a:b]==patch['current'],'projection drift '+path);lines[a:b]=patch['baseline']
  require(''.join(lines).encode()==old(path),'incumbent default body altered '+path)
 require(set(r['default_body_projections'])=={'src/runtime/mod_fmr_drainage_response_binding.f90','src/runtime/mod_fmr_serialized_reference_backend.f90','tests/fmig431/verify_dislayer_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'},'missing default body preservation')
 for path,h in p['qualification_inputs_sha256'].items():require(sha((ROOT/path).read_bytes())==h,'harness drift '+path)
 return True
@lru_cache(None)
def loaded():
 s=json.loads((ROOT/STATUS).read_text());p=s[PHASE];r=capsule(p['qualification_evidence']);verify(s,r)
 delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--',*SURFACE],cwd=ROOT,text=True).splitlines()}
 require(delta=={k:v['status']for k,v in p['successor_postimages'].items()},'foreign science change')
 for path,e in p['successor_postimages'].items():require(blob((ROOT/path).read_bytes())==e['blob'],'unqualified postimage '+path)
 return s,r
@lru_cache(None)
def incumbent(source_only=False):
 namespace=ROOT.parent/'dramet3-immutable-chain';namespace.mkdir(exist_ok=True);root=namespace/('incumbent-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'incumbent moved')
 code='import sys,json;sys.path.insert(0,"tests/fmig431");import verify_dislayer_successor as v;print(json.dumps(v.'+('verify_source'if source_only else'verify_qualification')+'()))'
 cp=subprocess.run([sys.executable,'-B','-c',code],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(namespace/'python-cache')})
 require(cp.returncode==0,'immutable original owner rejected '+cp.stderr[-2500:]);prior=json.loads(cp.stdout)
 if not source_only:require(prior['qualified']and prior['dislayer_successor']and prior['availability_successor'],'incomplete predecessor admission')
 return prior
def limit_successor():
 path=ROOT/'tests/mc-irr01/verify_depth_limit_successor.py'
 if not path.is_file():return None
 sys.path.insert(0,str(path.parent));import verify_depth_limit_successor as successor
 return successor
def verify_source(git_reader=None):
 successor=limit_successor()
 if successor:return successor.verify_source(git_reader)
 require(git_reader is None,'unregistered projection reader');loaded();prior=incumbent(True)
 return {**prior,'dramet3_successor':True,'qualified':False,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()}
def verify_qualification():
 successor=limit_successor()
 if successor:return successor.verify_qualification()
 loaded();prior=incumbent(False)
 return {**prior,'dramet3_successor':True,'qualified':True,'full_capability':True,'drainage_ledger_rows':prior['drainage_ledger_rows']+ROWS,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
def self_test():
 s,r=loaded();names=[]
 for name,edit in [('missing optimization',lambda a,b:b['runtime']['results'].pop()),('false qualification',lambda a,b:a[PHASE].__setitem__('qualified',False)),('relaxed condition',lambda a,b:a[PHASE]['conditions_frozen'].pop()),('expanded ledger',lambda a,b:a[PHASE]['ledger_rows'].append('SW431-DRAIN-DIV-TOPINTERFLOW')),('forged native',lambda a,b:b['outputs'].__setitem__('dramet3_runtime:0','forged')),('failed execution',lambda a,b:b['runtime']['events'][0].__setitem__('returncode',1)),('default projection removed',lambda a,b:b['default_body_projections'].pop('src/runtime/mod_fmr_serialized_reference_backend.f90')),('prior admission edited',lambda a,b:a['dislayer_phase_20261016'].__setitem__('qualified',False))]:
  a,b=copy.deepcopy(s),copy.deepcopy(r);edit(a,b)
  try:verify(a,b)
  except (ValueError,KeyError,StopIteration):names.append(name);continue
  raise ValueError('accepted '+name)
 print('DRAMET3_EVIDENCE_CORRUPTION_CONTROLS='+str(len(names)))
def main():
 successor=limit_successor()
 if successor:
  if '--self-test'in sys.argv:
   root=ROOT.parent/'limit-incumbent-636'
   ref='63658aa0835f13c64c2bc2562f0d0f820c77e97d'
   if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),ref],cwd=ROOT,check=True,capture_output=True)
   require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==ref,'LIMIT immutable DRAMET3 moved')
   cp=subprocess.run([sys.executable,'-B','tests/fmig431/verify_dramet3_successor.py','--self-test'],cwd=root,capture_output=True,text=True)
   require(cp.returncode==0,'original DRAMET3 controls rejected '+cp.stderr[-2000:]);print(cp.stdout,end='')
  successor.verify_qualification();print('MC_DRAIN01_DRAMET3_SOURCE_EVIDENCE=PASS');return
 ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 if a.self_test:self_test()
 verify_qualification();print('MC_DRAIN01_DRAMET3_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':main()
