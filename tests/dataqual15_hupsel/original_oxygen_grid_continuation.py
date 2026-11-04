"""Append actual unmodified-original input refinements without replacing the oracle."""
import argparse,csv,hashlib,io,json,math,re,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
CAPS=(.000078125,.0000390625)
INPUTS=('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def parent_files():
 r=json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text());parts=[]
 for p in r['archive_parts']:
  raw=(BASE/p['name']).read_bytes();assert len(raw)==p['bytes'] and sha(raw)==p['sha256'];parts.append(raw)
 raw=b''.join(parts);assert sha(raw)==r['archive_sha256']
 names=['original/unobserved/RUN.json','reference-refinement/case/result_output.csv',
        'original/unobserved/hupsel_profiles.csv',*['original/unobserved/'+n for n in INPUTS]]
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:files={n:t.extractfile(n).read() for n in names}
 assert all(sha(b)==r['files_sha256'][n] for n,b in files.items())
 return files

def inputs(parent,cap):
 assert cap in CAPS
 result={n:parent['original/unobserved/'+n] for n in INPUTS}
 raw,n=re.subn(rb'(?m)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+format(cap,'.10f').encode(),result['swap.swp']);assert n==1
 raw,n=re.subn(rb'(?m)^(\s*TEND\s*=\s*)2004-12-31',rb'\g<1>2003-08-07',raw);assert n==1
 result['swap.swp']=raw
 return result

def rows(raw):
 return list(csv.DictReader(l for l in raw.decode().splitlines() if not l.startswith('*')))

def run(parent,out,cap,timeout):
 sealed=parent_files();record=json.loads(sealed['original/unobserved/RUN.json'])
 exe=parent/'unobserved.exe';assert sha(exe.read_bytes())==record['executable_sha256']
 for n in INPUTS:assert (parent/'unobserved'/n).read_bytes()==sealed['original/unobserved/'+n]
 out.mkdir();case=out/'case';case.mkdir()
 actual=inputs(sealed,cap)
 for n,raw in actual.items():(case/n).write_bytes(raw)
 registration=dict(cap_day=cap,executable_sha256=record['executable_sha256'],
  only_input_changes=dict(DTMAX=cap,TEND='2003-08-07'),inputs_sha256={n:sha(b) for n,b in actual.items()},
  from_initialization=True,checkpoint_seed=None,timeout_seconds=timeout,production_admission=False)
 (out/'REGISTRATION.json').write_text(json.dumps(registration,indent=2)+'\n')
 start=time.monotonic()
 try:
  r=subprocess.run([str(exe)],cwd=case,capture_output=True,timeout=timeout)
  result=dict(status='EXECUTED' if r.returncode==100 and (case/'swap.ok').exists() else 'FAILED',
   returncode=r.returncode,seconds=time.monotonic()-start,swap_ok=(case/'swap.ok').exists())
  stdout,stderr=r.stdout,r.stderr
 except subprocess.TimeoutExpired as e:
  result=dict(status='CENSORED',returncode=None,seconds=time.monotonic()-start,swap_ok=False)
  stdout,stderr=e.stdout or b'',e.stderr or b''
 (out/'stdout').write_bytes(stdout);(out/'stderr').write_bytes(stderr)
 result['output_sha256']={n:sha((case/n).read_bytes()) for n in ('result_output.csv','hupsel_profiles.csv') if (case/n).exists()}
 result['production_admission']=False;(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 assert result['status']=='EXECUTED',result

def audit(files,sealed,cap):
 record=json.loads(files['REGISTRATION.json']);result=json.loads(files['RESULT.json'])
 assert cap in CAPS and record['cap_day']==cap
 assert record['from_initialization'] and record['checkpoint_seed'] is None
 assert record['executable_sha256']==json.loads(sealed['original/unobserved/RUN.json'])['executable_sha256']
 assert result['status']=='EXECUTED' and result['returncode']==100 and result['swap_ok']
 for n,raw in inputs(sealed,cap).items():assert files['case/'+n]==raw and sha(raw)==record['inputs_sha256'][n]
 for n,h in result['output_sha256'].items():assert sha(files['case/'+n])==h
 daily=rows(files['case/result_output.csv']);previous=rows(sealed['reference-refinement/case/result_output.csv'])
 assert len(daily)==len(previous)==585 and daily[584]['DATE']=='2003-08-07'
 assert [r['DATE'] for r in daily]==[r['DATE'] for r in previous]
 for r in daily:
  for k in ('WTOT','TREDWET','TPOT','TACT','BALDEV'):assert math.isfinite(float(r[k]))
  assert min(float(r[k]) for k in ('WTOT','TREDWET','TPOT','TACT'))>=0
 profiles=rows(files['case/hupsel_profiles.csv']);old=rows(sealed['original/unobserved/hupsel_profiles.csv'])[:34]
 assert len(profiles)==585*34
 largest=0.0
 for day in range(585):
  p=profiles[34*day:34*(day+1)]
  assert [int(r['node']) for r in p]==list(range(1,35)) and all(int(r['day'])==day for r in p)
  assert [(r['z_cm'],r['dz_cm']) for r in p]==[(r['z_cm'],r['dz_cm']) for r in old]
  for r in p:
   assert all(math.isfinite(float(r[k])) for k in ('z_cm','dz_cm','head_cm','water_content','temperature_c','concentration_mg_cm3'))
   assert float(r['dz_cm'])>0 and 0<=float(r['water_content'])<=1
  terms=[float(r['dz_cm'])*float(r['water_content']) for r in p];stock=math.fsum(terms)
  error=abs(stock-float(daily[day]['WTOT']));largest=max(largest,error)
  # One12-decimal publication rounding plus the standard positive-sum gamma
  # certificate. This is not a model balance/accuracy tolerance.
  gamma=36*sys.float_info.epsilon/(1-36*sys.float_info.epsilon)
  assert error<=.5e-12+gamma*stock
 return dict(cap_day=cap,actual_prefix_days=584,primitive_stock_maximum_publication_error_cm=largest,
  day584_oxygen_cm=float(daily[584]['TREDWET']),maximum_original_reported_balance_error_cm=max(abs(float(r['BALDEV'])) for r in daily),
  original_model_source_changed=False,production_admission=False,whole_scientific_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True)
 r=sub.add_parser('run');r.add_argument('--parent',type=Path,required=True);r.add_argument('--output',type=Path,required=True)
 r.add_argument('--cap',type=float,choices=CAPS,required=True);r.add_argument('--timeout',type=int,default=1800)
 a=p.parse_args();run(a.parent.resolve(),a.output.resolve(),a.cap,a.timeout)
