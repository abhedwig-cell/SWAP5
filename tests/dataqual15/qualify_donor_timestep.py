"""Refine only donor DTMAX with the authentic sealed original executable.

The literal .04-day run must reproduce all1827 stored scalar rows exactly.
Smaller DTMAX values are disclosed numerical counterfactuals, not replacements
for the original-input reference or new original-project qualifications.
"""
import argparse,csv,hashlib,io,json,math,re,subprocess,tarfile,time
from pathlib import Path
from grass_full_capsule import ROOT,verify
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 capsule=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz';manifest=ROOT/'integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json'
 verify(capsule,manifest)
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 with tarfile.open(capsule,'r:xz')as tar:
  spec=json.load(tar.extractfile('SPEC.json'));base=spec['reference_B0']
  binary=tar.extractfile('original431/swap431').read()
  inputs={name:tar.extractfile(base+'/'+name).read()for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']}
  baseline=tar.extractfile(base+'/result_output.csv').read().decode()
 executable=out/'swap431';executable.write_bytes(binary);executable.chmod(0o755)
 scalar=lambda text:list(csv.DictReader(line for line in text.splitlines()if line.strip()and not line.startswith('*')))
 expected=scalar(baseline)
 pattern=re.compile(r'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)([^\r\n]*)$')
 text=inputs['swap.swp'].decode();matches=list(pattern.finditer(text));assert len(matches)==1 and float(matches[0][2])==.04
 physical=lambda value:pattern.sub(r'\1NUMERICAL_DTMAX\3',value)
 report=dict(status='RUNNING',scope='DONOR_NUMERICAL_COUNTERFACTUAL_NOT_NEW_ORIGINAL_PROJECT',physical_input_changes=False,executable_sha256=sha(binary),capsule_sha256=sha(capsule.read_bytes()),runs={},scientific_equivalence=False)
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 measured=None
 for cap in [.04,.02,.01,.005,.0025]:
  case=out/('dtmax-'+str(cap));case.mkdir()
  changed=text if cap==.04 else pattern.sub(lambda m:m[1]+str(cap)+m[3],text)
  assert physical(changed)==physical(text)
  for name,raw in inputs.items():(case/name).write_bytes(changed.encode()if name=='swap.swp'else raw)
  budget=240 if measured is None else max(240,math.ceil(measured*.04/cap*3+60))
  record=dict(dtmax_day=cap,numerical_input_changes=[]if cap==.04 else['DTMAX'],physical_input_changes=False,wall_cap_seconds=budget,input_sha256={name:sha((case/name).read_bytes())for name in inputs})
  report['runs'][str(cap)]=record;save();print('DONOR_DTMAX_START',cap,'cap_seconds',budget,flush=True)
  start=time.monotonic()
  with (case/'stdout').open('wb')as stdout,(case/'stderr').open('wb')as stderr:
   try:r=subprocess.run([str(executable)],cwd=case,stdout=stdout,stderr=stderr,timeout=budget);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  record.update(returncode=code,censored=censored,seconds=time.monotonic()-start);save()
  assert code==100 and not censored and(case/'swap.ok').exists(),record
  rows=scalar((case/'result_output.csv').read_text());assert len(rows)==1828 and rows[-1]['DATE']=='1984-12-31'
  if cap==.04:assert rows==expected,'unmodified same-binary donor trajectory differs';measured=record['seconds']
  annual=[]
  for day,row in enumerate(rows):
   if day and(day==1827 or rows[day+1]['DATE'][:4]!=row['DATE'][:4]):annual.append(float(row['HRVDM']))
  record.update(completed_days=1827,scalar_sha256=sha((case/'result_output.csv').read_bytes()),literal_reference_exact=cap==.04,project_actual_harvest_kg_ha=math.fsum(annual),selected_days={str(day):{key:float(rows[day][key])for key in ['TPOT','TACT','TREDWET','TREDDRY','WRT','WLV','HRVDM','WTOT']}for day in [25,72,73,127,140,367,1827]})
  save();print('DONOR_DTMAX_COMPLETE',cap,'seconds',record['seconds'],'harvest',record['project_actual_harvest_kg_ha'],flush=True)
 report['status']='DONOR_TIMESTEP_REFINEMENT_MEASURED';save();print(json.dumps(report,indent=2))
if __name__=='__main__':main()
