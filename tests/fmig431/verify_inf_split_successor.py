#!/usr/bin/env python3
"""Source/evidence admission for shared ordinary separate infiltration."""
from pathlib import Path
from functools import lru_cache
import argparse,base64,copy,gzip,hashlib,json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json';PHASE='inf_split_phase_20261016'
DEFAULT='src/process/mod_frost_divdra_drainage_effect.f90'
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def prior(base,p):return subprocess.check_output(['git','show',base+':'+p],cwd=ROOT)
def verify(s,r,reader=lambda p:(ROOT/p).read_bytes()):
 p=s[PHASE];require(p['qualified'] is True,'INF-SPLIT not qualified')
 frozen=json.loads(prior(p['frozen_conditions_commit'],STATUS))[PHASE]
 for key in ['baseline','existing_candidate','existing_branch','ledger_rows','conditions_frozen','excluded','invariants']:
  require(p[key]==frozen[key],'frozen condition drift '+key)
 require(p['ledger_rows']==['SW431-DRAIN-INF-SPLIT'],'INF ledger scope')
 cases={'inf_contract','multilevel_contract','signed_contract','positive_process','positive_binder','inf_runtime','multilevel_runtime','signed_runtime'}
 results=r['result']['results']
 require(len(results)==16 and {(x['case'],x['optimization'])for x in results}=={(c,o)for c in cases for o in (0,2)},'complete O0/O2 production records')
 for path,h in p['qualification_inputs_sha256'].items():require(sha(reader(path))==h,'harness drift '+path)
 def check_rows(rows,outputs):
  for x in rows:
   require('-fcheck=all'in x['flags']and'-ffpe-trap=invalid,zero,overflow'in x['flags'],'scientific flags')
   for path,h in x['inputs'].items():require(sha(reader(path))==h,'scientific input drift '+path)
   raw=outputs[x['case']+':'+str(x['optimization'])].encode();require(sha(raw)==x['stdout_sha256'],'raw integrity')
   pair=next(y for y in rows if y['case']==x['case']and y['optimization']!=x['optimization']);require(pair['stdout_sha256']==x['stdout_sha256'],'optimization drift')
   if x['case']=='inf_contract':
    for marker in [b'INF_SPLIT_SOURCE_CASES=15192 SAME_COMP=720 ZERO_SAT_HELD=360',b'INF_SPLIT_SINGLE_NODE=PASS',b'INF_SPLIT_SOURCE_SHARED_INTEGRAL_LITERAL_BINDER=PASS']:require(marker in raw,'source geometry matrix')
   if x['case'].endswith('_runtime'):
    inf=x['case']=='inf_runtime';prefix=b'SW431_INF'if inf else b'SW431_MULTI'if x['case']=='multilevel_runtime'else b'SW431_SIGNED'
    require(raw.count(prefix+b'_SINGLE ')==(48 if inf else 24),'runtime cases')
    require(raw.count(prefix+b'_REJECT_REPLAY_RESTART=PASS')==(8 if inf else 4),'transaction and restart')
    require(raw.count(prefix+b'_INACTIVE_EXACT_IDENTITY=PASS')==(4 if inf else 2),'inactive identity')
    require(raw.count(prefix+b'_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS')==(2 if inf else 1),'isolation')
    require(prefix+b'_FAIL_CLOSED_PREMUTATION_MATRIX=PASS'in raw,'preflight negatives')
 check_rows(results,r['outputs']);require(all(x['returncode']==0 for x in r['result']['events']),'failed/censored final science')
 guards=r['guards'];require(len(guards['results'])==2,'missing malformed-input guards');check_rows(guards['results'],r['guard_outputs'])
 require(all(x['returncode']==0 for x in guards['events']),'failed guards')
 b18=r['b18'];require(b18['status']=='PASS'and b18['accepted']==3240 and b18['held']==1296,'B18 scientific preservation')
 require(len(b18['results'])==4 and {(x['variant'],x['optimization'])for x in b18['results']}=={(c,o)for c in ['reference','typed']for o in (0,2)},'B18 complete native executions')
 require(all(x['returncode']==0 for x in b18['events']),'failed B18 native')
 for x in b18['results']:
  for path,h in x['inputs'].items():require(sha(reader(path))==h,'B18 input drift '+path)
  require(sha(r['b18_outputs'][x['variant']+':'+str(x['optimization'])].encode())==x['stdout_sha256'],'B18 raw output')
 original='tests/frost/run_ppa_wu05b18_divdra_component.py';require(reader(original)==prior(p['baseline'],original),'original B18 assertions altered')
 # Reconstruction is exact, with every changed and inserted range sealed in
 # the qualification capsule. All original default arithmetic/calls remain.
 for path,changes in r['incumbent_projections'].items():
  lines=reader(path).decode().splitlines(keepends=True)
  for op in reversed(changes):
   a,b=op['new_range'];require(lines[a:b]==op['postimage'],'changed qualified insertion '+path)
   lines[a:b]=op['preimage']
  require(''.join(lines).encode()==prior(p['baseline'],path),'incumbent body drift '+path)
 for path in ['src/process/mod_drainage_spatial_distribution.f90','src/runtime/mod_fmr_divdra_runtime_binding.f90']:
  require(reader(path)==prior(p['baseline'],path),'admitted ordinary body changed '+path)
 # B20 geometry correction is already admitted; inherit its exact unchanged
 # component/reference evidence rather than inventing another correction.
 authority='integration/audits/PPA_WU05B20_CURRENT_REVIEW.json';review=json.loads(reader(authority))
 require(review['reference_geometry_qualified']and review['reference_geometry_admitted']and review['admitted'],'B20 authority absent')
 manifest='reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03/manifest.json';m=json.loads(reader(manifest))
 require(m['qualified']and m['admitted']and sha(reader(m['materialized_reference']))==m['candidate_sha256'],'B20 component drift')
 for e in review['evidence'].values():require(sha(reader(e['path']))==e['sha256'],'B20 evidence drift')
 require(not subprocess.check_output(['git','diff',p['baseline'],'--','reference'],cwd=ROOT),'reference mutation')
 parallel=p.get('parallel_tcs6_reconciliation')
 if parallel:
  guard='tests/mc-irr01/verify_tcs6_successor.py';body=reader(guard).decode()
  for call in ['verify_source(git_reader)','verify_qualification()']:
   addition=' if (ROOT/"tests/fmig431/verify_inf_split_successor.py").exists():\n  sys.path.insert(0,str(ROOT/"tests/fmig431"));import verify_inf_split_successor as successor\n  return successor.'+call+'\n'
   require(body.count(addition)==1,'TCS6 delegation shape');body=body.replace(addition,'',1)
  require(body.encode()==prior(parallel['commit'],guard),'TCS6 original owner body changed')
  current=json.loads(reader('integration/audits/MC_IRR01_STATUS.json'))['tcs6_completion_20261016']
  frozen_record=json.loads(prior(parallel['commit'],'integration/audits/MC_IRR01_STATUS.json'))['tcs6_completion_20261016']
  require(current==frozen_record,'TCS6 admission authority changed')
  for path,h in parallel['unchanged_science_inputs'].items():
   raw=reader(path)
   if path==DEFAULT:
    lines=raw.decode().splitlines(True)
    for op in reversed(r['incumbent_projections'][path]):
     a,b=op['new_range'];require(lines[a:b]==op['postimage'],'TCS6 frost projection');lines[a:b]=op['preimage']
    raw=''.join(lines).encode()
   require(sha(raw)==h,'parallel TCS6 science drift '+path)

 return True

def load_verified():
 s=json.loads((ROOT/STATUS).read_text());p=s[PHASE];e=p['evidence'];b=base64.b64decode((ROOT/e['path']).read_bytes())
 require(sha(b)==e['sha256'],'INF archive integrity');r=json.loads(gzip.decompress(b));verify(s,r)
 rows={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',p['baseline'],'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()}
 require(rows=={k:v['status']for k,v in p['successor_postimages'].items()},'foreign INF science')
 for path,v in p['successor_postimages'].items():require(blob((ROOT/path).read_bytes())==v['blob'],'unqualified INF postimage '+path)
 return s,r

@lru_cache(None)
def incumbent(source_only=False):
 p=json.loads((ROOT/STATUS).read_text())[PHASE];base=p.get('parallel_tcs6_reconciliation',{}).get('commit',p['baseline']);namespace=ROOT.parent/'inf-immutable-chain';namespace.mkdir(exist_ok=True);root=namespace/('incumbent-'+base[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),base],cwd=ROOT,check=True,capture_output=True)
 require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==base,'INF incumbent moved')
 module='tests/mc-irr01' if p.get('parallel_tcs6_reconciliation') else 'tests/fmig431';name='verify_tcs6_successor' if p.get('parallel_tcs6_reconciliation') else 'verify_multilevel_divdra_successor'
 command='import sys,json;sys.path.insert(0,"'+module+'");import '+name+' as v;print(json.dumps(v.'+('verify_source'if source_only else'verify_qualification')+'()))'
 cp=subprocess.run([sys.executable,'-B','-c',command],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(namespace/'python-cache')})
 require(cp.returncode==0,'original multilevel owner rejected '+cp.stderr[-2000:]);old=json.loads(cp.stdout)
 if not source_only:require(old['qualified']and old['multilevel_divdra_successor'],'unqualified incumbent')
 return old

def verify_source(git_reader=None):
 require(git_reader is None,'unregistered projected reader');load_verified();old=incumbent(True)
 return {**old,'inf_split_successor':True,'qualified':False,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()}
def verify_qualification():
 load_verified();old=incumbent(False)
 return {**old,'incumbent':old,'inf_split_successor':True,'qualified':True,'drainage_ledger_rows':['SW431-DRAIN-DIV-SIGNED','SW431-DRAIN-DIV-MULTI','SW431-DRAIN-INF-SPLIT'],'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args();s,r=load_verified()
 if a.self_test:
  controls=[]
  def reject(name,s,r,reader=lambda p:(ROOT/p).read_bytes()):
   try:verify(s,r,reader)
   except (ValueError,KeyError,StopIteration):controls.append(name);return
   raise AssertionError('accepted '+name)
  bad=copy.deepcopy(r);bad['result']['results'].pop();reject('missing optimization',s,bad)
  bad=copy.deepcopy(r);bad['outputs']['inf_runtime:0']='forged';reject('forged native',s,bad)
  bad=copy.deepcopy(r);bad['b18']['accepted']=1;reject('B18 removed',s,bad)
  bad=copy.deepcopy(r);bad['result']['events'][0]['returncode']=1;reject('failed compile',s,bad)
  bad=copy.deepcopy(s);bad[PHASE]['qualified']=False;reject('unqualified',bad,r)
  bad=copy.deepcopy(s);bad[PHASE]['ledger_rows'].append('SW431-DRAIN-DRAMET3');reject('scope expansion',bad,r)
  bad=copy.deepcopy(s);bad[PHASE]['conditions_frozen'].pop();reject('condition relaxation',bad,r)
  reject('default frost drift',s,r,lambda p:(ROOT/p).read_bytes()+(b'!corruption'if p==DEFAULT else b''))
  print('INF_SPLIT_EVIDENCE_CORRUPTION_CONTROLS='+str(len(controls)))
 verify_qualification();print('MC_DRAIN01_INF_SPLIT_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':main()
