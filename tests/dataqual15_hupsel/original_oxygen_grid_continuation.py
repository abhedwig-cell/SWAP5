"""Append actual unmodified-original input refinements without replacing the oracle."""
import argparse,csv,hashlib,io,json,math,re,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
CAPS=(.000078125,.0000390625)
INPUTS=('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')
STRICT={'CRITDEVBALCP':'1e-8','CRITDEVBALTOT':'1e-7','CRITDEVH1CP':'1e-6','CRITDEVH2CP':'1e-6','CRITDEVPONDDT':'1e-6'}
sha=lambda raw:hashlib.sha256(raw).hexdigest()
PARENT_ARCHIVE='99adab40cc703f4533abc89befa5d16d76d6a36d1b7a09ef3e463becf997c1db'
ORIGINAL_EXECUTABLE='dc331cd6fe9bb0ef9cbf815f804283bed9e7d8841bf32262c9a844da6d5211b9'

def require_parent_identity(record):
 # These are the actual PR1526 source carriers, not caller-resealable pins.
 assert record['archive_sha256']==PARENT_ARCHIVE and not record['production_admission']

def parent_files():
 r=json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text());parts=[]
 require_parent_identity(r)
 for p in r['archive_parts']:
  raw=(BASE/p['name']).read_bytes();assert len(raw)==p['bytes'] and sha(raw)==p['sha256'];parts.append(raw)
 raw=b''.join(parts);assert sha(raw)==r['archive_sha256']
 names=['original/unobserved/RUN.json','reference-refinement/case/result_output.csv','reference-strict-balance/PREREGISTRATION.json',
        'original/unobserved/hupsel_profiles.csv',*['original/unobserved/'+n for n in INPUTS]]
 # One forward pass: repeated indexed reads in an xz stream otherwise
 # decompress the large inherited capsule again for backward seeks.
 files={};wanted=set(names)
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r|xz') as t:
  for member in t:
   if member.name in wanted:
    assert member.isfile() and member.name not in files
    files[member.name]=t.extractfile(member).read()
    if set(files)==wanted:break
 assert set(files)==wanted
 assert all(sha(b)==r['files_sha256'][n] for n,b in files.items())
 assert json.loads(files['original/unobserved/RUN.json'])['executable_sha256']==ORIGINAL_EXECUTABLE
 return files

def changes(cap,precision):
 assert cap in CAPS and precision in ('legacy','strict')
 return dict(DTMAX=cap,TEND='2003-08-07',**(STRICT if precision=='strict' else {}))

def inputs(parent,cap,precision='legacy'):
 changes(cap,precision)
 result={n:parent['original/unobserved/'+n] for n in INPUTS}
 raw,n=re.subn(rb'(?m)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+format(cap,'.10f').encode(),result['swap.swp']);assert n==1
 raw,n=re.subn(rb'(?m)^(\s*TEND\s*=\s*)2004-12-31',rb'\g<1>2003-08-07',raw);assert n==1
 if precision=='strict':
  assert STRICT==json.loads(parent['reference-strict-balance/PREREGISTRATION.json'])['parameters']
  for k,v in STRICT.items():
   raw,n=re.subn(rb'(?m)^(\s*'+k.encode()+rb'\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+v.encode(),raw);assert n==1
 result['swap.swp']=raw
 return result

def rows(raw):
 return list(csv.DictReader(l for l in raw.decode().splitlines() if not l.startswith('*')))

def run(parent,out,cap,timeout,precision='legacy'):
 sealed=parent_files();record=json.loads(sealed['original/unobserved/RUN.json'])
 exe=parent/'unobserved.exe';assert sha(exe.read_bytes())==record['executable_sha256']
 for n in INPUTS:assert (parent/'unobserved'/n).read_bytes()==sealed['original/unobserved/'+n]
 out.mkdir();case=out/'case';case.mkdir()
 actual=inputs(sealed,cap,precision)
 for n,raw in actual.items():(case/n).write_bytes(raw)
 registration=dict(cap_day=cap,executable_sha256=record['executable_sha256'],
  only_input_changes=changes(cap,precision),inputs_sha256={n:sha(b) for n,b in actual.items()},
  from_initialization=True,checkpoint_seed=None,timeout_seconds=timeout,production_admission=False)
 if precision!='legacy':registration['precision']=precision
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

def audit(files,sealed,cap,precision='legacy'):
 record=json.loads(files['REGISTRATION.json']);result=json.loads(files['RESULT.json'])
 assert cap in CAPS and record['cap_day']==cap
 assert record.get('precision','legacy')==precision and record['only_input_changes']==changes(cap,precision)
 assert not record['production_admission'] and not result['production_admission']
 assert set(record['inputs_sha256'])==set(INPUTS)
 assert record['from_initialization'] and record['checkpoint_seed'] is None
 assert record['executable_sha256']==json.loads(sealed['original/unobserved/RUN.json'])['executable_sha256']
 assert result['status']=='EXECUTED' and result['returncode']==100 and result['swap_ok']
 assert b'simulation succesfully terminated' in files['case/swap.ok']
 for n,raw in inputs(sealed,cap,precision).items():assert files['case/'+n]==raw and sha(raw)==record['inputs_sha256'][n]
 assert set(result['output_sha256'])=={'result_output.csv','hupsel_profiles.csv'}
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
 balances=[abs(float(r['BALDEV'])) for r in daily]
 return dict(cap_day=cap,precision=precision,actual_prefix_days=584,primitive_stock_maximum_publication_error_cm=largest,
  day584_oxygen_cm=float(daily[584]['TREDWET']),maximum_original_reported_balance_error_cm=max(balances),
  maximum_original_balance_error_day=balances.index(max(balances)),cumulative_original_reported_balance_error_cm=math.fsum(float(r['BALDEV']) for r in daily),
  original_warning_lines=sum(bool(l.strip()) for l in files['case/swap.wrn'].splitlines()),
  original_model_source_changed=False,production_admission=False,whole_scientific_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True)
 r=sub.add_parser('run');r.add_argument('--parent',type=Path,required=True);r.add_argument('--output',type=Path,required=True)
 r.add_argument('--cap',type=float,choices=CAPS,required=True);r.add_argument('--timeout',type=int,default=1800)
 r.add_argument('--precision',choices=['legacy','strict'],default='legacy')
 a=p.parse_args();run(a.parent.resolve(),a.output.resolve(),a.cap,a.timeout,a.precision)
