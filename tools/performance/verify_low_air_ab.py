#!/usr/bin/env python3
"""Fail-closed validator of bounded complete original highest low-air A/B evidence.

This validates the executed original assertions; it does not authorize F-CI or
canonical admission and never compares an unmatched historical runtime.
"""
import argparse,hashlib,json,math,pathlib,re

def verify(folder):
 folder=pathlib.Path(folder);r=json.loads((folder/'RESULTS.json').read_text())
 candidate_only=r.get('scope')=='GUARDED_CANDIDATE_ORIGINAL_HIGHEST_QUALIFICATION'
 policies=['candidate'] if candidate_only else ['baseline','candidate']
 expected={(round_index,family,policy)for round_index in range(r['repeat'])for family in range(1,7)for policy in policies}
 if not r.get('complete_single_optimization_candidate' if candidate_only else 'complete_single_optimization_ab'):raise ValueError('incomplete execution')
 seen=set();physical={};summary={};max_head=max_temperature=0.
 for run in r['runs']:
  key=(run['round'],run['family'],run['policy'])
  if key not in expected or key in seen:raise ValueError('duplicate or foreign trajectory')
  seen.add(key)
  if run['exit']!=0 or not run['complete']:raise ValueError('nonterminal or failed trajectory')
  for field in ['wall_seconds','cpu_seconds']:
   if not math.isfinite(run[field])or run[field]<=0:raise ValueError('invalid measurement')
  stem=f'{key[0]}-{key[1]}-{key[2]}.stdout';raw=(folder/stem).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=run['stdout_sha256']:raise ValueError('stdout drift')
  text=raw.decode()
  if text.count('_RUNTIME=PASS')!=1 or text.count('FINE_COMPARISON')!=6:raise ValueError('missing original full fine comparisons')
  for marker in ['PPA_WU05B15_EXTENDED_APPLICATION=PASS','PPA_WU05B15_ACTUAL_CONTROL_PREFLIGHT=PASS']:
   if marker not in text:raise ValueError('missing application/negative authority')
  for head,temperature in re.findall(r'FINE_COMPARISON head_cm=\s*(\S+) temperature_c=\s*(\S+)',text):
   head=float(head);temperature=float(temperature)
   if not(0<=head<=1.e-6 and 0<=temperature<=1.e-4):raise ValueError('original fine budgets failed')
   max_head=max(max_head,head);max_temperature=max(max_temperature,temperature)
  previous=physical.setdefault((key[1],key[2]),run['stdout_sha256'])
  if previous!=run['stdout_sha256']:raise ValueError('repeat scientific output drift')
 if seen!=expected:raise ValueError('missing trajectory')
 for rnd in range(r['repeat']):
  summary[rnd]={name:sum(x['wall_seconds']for x in r['runs']if x['round']==rnd and x['policy']==name)for name in policies}
  summary[rnd]['native_sum_speedup']='UNKNOWN' if candidate_only else summary[rnd]['baseline']/summary[rnd]['candidate']
 return {'scope':r['scope'],'rounds':summary,'trajectories':len(seen),'fine_comparisons':6*len(seen),'max_head_error_cm':max_head,'max_temperature_error_c':max_temperature,'physical_sha256':{str(k):v for k,v in physical.items()},'canonical_admission':False,'full_fci_preservation':'UNKNOWN','physics_exclusive_times':'UNKNOWN','historical_hardware_comparability':'UNKNOWN'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder');a=p.parse_args();print(json.dumps(verify(a.folder),indent=2))
