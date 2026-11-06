"""Keep every actual exact-predecessor failure red and independently attributable."""
import argparse,io,json,zipfile
from pathlib import Path
import generation_publication_admission as owner
ROOT=owner.ROOT;DEST=ROOT/'integration/dataqual15_hupsel';STEM='GENERATION_PUBLICATION_BASELINE_POSIX_20261106';sha=owner.sha
SIGNATURES={'performance':'AssertionError: unreviewed delta','reference-vq':'"status": "FAIL"','d1':'D1 workunit changed production/reference source','d3':'D3 changed production/reference source','p2e06':'reference tree differs from P2E05 canonical base','p2e07':'P2E07 mutated src or reference','p2e08':'P2E08 mutated src or reference relative to reconciled canonical','p2e09':'PUB_P2E09_GATE_FAIL admitted P2E08 Reference replay','p2e10':'PUB_P2E10_GATE_FAIL solver contract drift','p2e02':'mod_drainage_dramet3_response','p2e04':'mod_drainage_dramet3_response','census':'mod_drainage_dramet3_response','thermal-owner':'==PATHS','logical-owner':'=={SOURCE}','native-layout':'unreviewed production paths'}

def audit(files):
 r=json.loads(files['RESULT.json']);assert r['baseline']==owner.BASE and r['tree']=='0abc22b8775e897608bcb05d89ea7e23901eb270'
 assert r['old_gate_pass_claim'] is False and r['current_scientific_promotion'] is False
 assert len(r['events'])==15 and {e['case'] for e in r['events']}==set(SIGNATURES)
 result={}
 for e in r['events']:
  name=e['case'];assert e['returncode'] not in (None,0) and e['censored'] is False
  for stream in ('stdout','stderr'):assert sha(files[name+'.'+stream])==e[stream+'_sha256']
  text=(files[name+'.stdout']+files[name+'.stderr']).decode(errors='replace');assert SIGNATURES[name] in text
  if name in ('p2e02','p2e04','census'):assert 'Cannot open module file' in text
  result[name]=dict(returncode=e['returncode'],signature=SIGNATURES[name],censored=False)
 return result

def run(seal=False):
 raw=(DEST/(STEM+'.zip')).read_bytes()
 with zipfile.ZipFile(io.BytesIO(raw)) as z:files={n:z.read(n) for n in z.namelist() if not n.endswith('/')}
 report=audit(files);refused=[]
 for kind in ('stream','baseline','verdict','promotion'):
  mutant=dict(files);r=json.loads(mutant['RESULT.json'])
  if kind=='stream':mutant['performance.stderr']+=b'!corrupt'
  else:
   if kind=='baseline':r['baseline']='0'*40
   if kind=='verdict':r['events'][0]['returncode']=0
   if kind=='promotion':r['old_gate_pass_claim']=True
   mutant['RESULT.json']=json.dumps(r).encode()
  try:audit(mutant)
  except (AssertionError,ValueError,KeyError):refused.append(kind)
  else:raise AssertionError('altered predecessor observation admitted: '+kind)
 record=dict(archive_sha256=sha(raw),members={n:sha(b)for n,b in files.items()},report=report,actual_refusals=refused,baseline=owner.BASE,run=42138604204,job=127632927702,artifact=13466564350,execution_source_head='769881b4a29ed1da2fe7ac0dd4f426816b54857d',old_gate_pass_claim=False,current_scientific_promotion=False)
 p=DEST/(STEM+'.json')
 if seal:p.write_text(json.dumps(record,indent=2)+'\n')
 else:assert record==json.loads(p.read_text())
 print('EXACT_PREDECESSOR15_UNCENSORED_FAILURES_AND_FOUR_EVIDENCE_REFUSALS_PASS_NO_OLD_PASS_CLAIM')

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--seal',action='store_true');a=p.parse_args();run(a.seal)
