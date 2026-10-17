#!/usr/bin/env python3
"""Validate a diagnosed source defect; never grant production qualification."""
from pathlib import Path
import argparse,base64,copy,gzip,hashlib,json,math,subprocess
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json'
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def verify(s,r):
 p=s['dislayer_phase_20261016'];require(not p['qualified']and not p['admitted'],'false admission')
 require(p['ledger_rows']==['SW431-DRAIN-DISLAYER']and p['ledger_rows_closed']==[],'ledger scope')
 require(sha(json.dumps({k:p[k]for k in ['baseline','existing_candidate','existing_branch','ledger_rows','conditions_frozen','excluded','invariants']},sort_keys=True).encode())==r['frozen_conditions_sha256'],'frozen conditions changed')
 require(r['result']['qualified']is False and r['result']['admitted']is False and r['result']['ledger_rows_closed']==[],'diagnosis used as admission')
 rows=r['result']['results'];require(len(rows)==4 and {(x['case'],x['optimization'])for x in rows}=={(c,o)for c in ['b111','b20_admitted03']for o in(0,2)},'missing actual native variant')
 require(all(x['returncode']==0 for x in r['result']['events']),'failed terminal proof')
 for path,h in r['harness_inputs'].items():require(sha((ROOT/path).read_bytes())==h,'harness drift '+path)
 for x in rows:
  require('-fcheck=all'in x['flags']and'-ffpe-trap=invalid,zero,overflow'in x['flags'],'unchecked science')
  for path,h in x['inputs'].items():require(sha((ROOT/path).read_bytes())==h,'input drift '+path)
  output=r['outputs'][x['case']+':'+str(x['optimization'])];require(sha(output.encode())==x['stdout_sha256'],'raw output drift')
  observations=[line.split()for line in output.splitlines()if line.startswith('DISLAYER_OBSERVATION ')]
  require(len(observations)==24 and {(int(v[1]),int(v[2]),int(v[3]))for v in observations}=={(g,q,m)for g in(1,2)for q in(1,2,3,4)for m in(1,2,3)},'source matrix changed')
  bad=0
  for v in observations:
   g,rate,mode=map(int,v[1:4]);q,retained,native,candidate,residual=map(float,v[4:9]);expected_q=[.003,-.003,2e-9,-2e-9][rate-1]
   require(q==expected_q and all(math.isfinite(z)for z in [q,retained,native,candidate,residual]),'forcing/domain')
   expected_retained=q*6.5/(8 if g==1 else 1+7e-7)*(1 if g==1 else 1e-7)
   expected_native=q if g==1 and rate<=2 else q+q*6e-7/(1+7e-7)if g==2 and rate<=2 else expected_retained
   require(abs(retained-expected_retained)<1e-17 and abs(native-expected_native)<1e-17,'independent conductivity/thickness conservation witness')
   require(abs(native-candidate)<1e-17 and abs((native-q)-residual)<1e-17,'source/candidate residual')
   bad+=abs(residual)>1e-12
  require(bad==18,'defect count')
 require(len({x['stdout_sha256']for x in rows})==1,'reference or optimization drift')
 path='src/process/mod_drainage_discharge_layer_transform.f90'
 require((ROOT/path).read_bytes()==subprocess.check_output(['git','show',p['existing_candidate']+':'+path],cwd=ROOT),'candidate production changed before source resolution')
 require(not subprocess.check_output(['git','diff',p['baseline'],'--','reference'],cwd=ROOT),'reference changed')
 return True
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 s=json.loads((ROOT/STATUS).read_text());p=s['dislayer_phase_20261016'];raw=base64.b64decode((ROOT/p['evidence']['path']).read_bytes());require(sha(raw)==p['evidence']['sha256'],'archive drift');r=json.loads(gzip.decompress(raw));verify(s,r)
 if a.self_test:
  bad=[]
  for name,edit in [('missing native',lambda s,r:r['result']['results'].pop()),('false admission',lambda s,r:s['dislayer_phase_20261016'].__setitem__('qualified',True)),('relaxed conditions',lambda s,r:s['dislayer_phase_20261016']['conditions_frozen'].pop()),('forged stdout',lambda s,r:r['outputs'].__setitem__('b111:0','forged')),('failed event',lambda s,r:r['result']['events'][0].__setitem__('returncode',1))]:
   a,b=copy.deepcopy(s),copy.deepcopy(r);edit(a,b)
   try:verify(a,b)
   except (ValueError,KeyError):bad.append(name);continue
   raise ValueError('accepted '+name)
  print('DISLAYER_DEFECT_EVIDENCE_NEGATIVE_CONTROLS='+str(len(bad)))
 print('DISLAYER_SOURCE_DEFECT_EVIDENCE=PASS_PRODUCTION_ADMISSION_BLOCKED')
if __name__=='__main__':main()
