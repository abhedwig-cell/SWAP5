"""Portable actual-input evidence: reproduce measurements and preserve failed gates."""
import argparse,base64,csv,hashlib,io,json,lzma,math,re,subprocess,sys,tarfile,tempfile
from pathlib import Path,PurePosixPath
from inspect_profiles import profile
ROOT=Path(__file__).resolve().parents[2]
DIRECTORY=ROOT/'integration/dataqual15_hupsel'
sha=lambda b:hashlib.sha256(b).hexdigest()

def safe(name):
 p=PurePosixPath(name);assert not p.is_absolute()and '..'not in p.parts and '\\'not in name and ':'not in name;return p
def file_sha(path):
 d=hashlib.sha256()
 with path.open('rb')as f:
  while raw:=f.read(4*1024*1024):d.update(raw)
 return d.hexdigest()
def csv_rows(raw):return list(csv.DictReader(io.StringIO(raw.decode())))
def output_rows(path):
 lines=path.read_text().splitlines();header=next(l for l in lines if l.startswith('case,t0,'));return list(csv.DictReader([header,*[l for l in lines if re.match(r'^\d+,',l)]])),[l.split(',')for l in lines if l.startswith('CHAIN,')]
def check_sources(report):
 for name,pin in report.get('source_sha256',{}).items():
  safe(name)
  # This one dependency is an immutable experimental registration, not live status.
  owner=DIRECTORY/'UPTAKE_DIAGNOSIS_PREREGISTRATION.json'if name=='integration/dataqual15_hupsel/UPTAKE_DIAGNOSIS_STATUS.json'else ROOT/name
  assert file_sha(owner)==pin,('source/input binding',name)

def inspect(folder):
 capture=json.loads((folder/'capture/RESULT.json').read_text());paired=json.loads((folder/'paired/RESULT.json').read_text());controls=json.loads((folder/'precision/RESULT.json').read_text())
 assert capture['status']=='ACTUAL_ACCEPTED_UPTAKE_INPUTS_CAPTURED'and capture['literal_585_day_budget_and_crop_exact']
 assert paired['status']=='ACTUAL_ACCEPTED_IDENTICAL_INPUT_OWNERS_MEASURED'and controls['status']=='DECLARED_OXYGEN_PRECISION_CONTROLS_COMPLETE'
 for record in [capture,paired,controls]:check_sources(record)
 failed=json.loads((folder/'failed_prepare/RESULT.json').read_text());assert failed['events'][-1]['label']=='prepare'and failed['events'][-1]['returncode']==1
 assert not any(e['label']=='native'for e in failed['events'])
 assert 'prefix crosses original crop emergence/calendar'in(folder/'failed_prepare/prepare.stderr').read_text()
 from observe_uptake import generate
 generated=folder/'regenerated-observer';generated.mkdir(exist_ok=True);generate(generated)
 for name in ['observed_backend.f90','observed_main.f90']:assert(generated/name).read_bytes()==(folder/'capture'/name).read_bytes(),('output-only observer differs',name)
 assert all(e['returncode']==0 and not e.get('censored',False)for r in [capture,paired,controls]for e in r['events'])
 case=folder/'capture/case'
 for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:assert(case/name).read_bytes()==(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'/name).read_bytes(),name
 with tarfile.open(DIRECTORY/'UNION_C3_HUPSEL_EVIDENCE.tar.xz')as t:
  for name in ['budget.csv','crop.csv']:
   actual=csv_rows((case/name).read_bytes());golden=csv_rows(t.extractfile('cases/hupsel-full1096/'+name).read());assert actual and actual==golden[:len(actual)],name
 budget=csv_rows((case/'budget.csv').read_bytes());assert float(budget[-1]['t1_day'])==585 and float(budget[0]['t0_day'])==0
 endpoint=profile((case/'checkpoint.bin').read_bytes());assert endpoint['day']==585
 assert abs(endpoint['water_stock_cm']-float(budget[-1]['water_end_cm']))<1e-10
 assert abs(endpoint['solute_stock_mg_cm2']-float(budget[-1]['solute_end_mg_cm2']))<1e-10
 build=json.loads((folder/'capture/build/BUILD.json').read_text());assert file_sha(folder/'capture/build/swap5_hupsel_germination')==build['executable_sha256']==capture['executable_sha256']
 accepted={}
 for line in (folder/'capture/native.stdout').read_text().splitlines():
  f=line.split()
  if f and f[0]=='UPTAKE_ACCEPTED':
   v=list(map(float,f[1:]));key=tuple(round(x,12)for x in v[:2]);assert key not in accepted;accepted[key]=v
 nested=json.loads((folder/'RAW_TRIALS.json').read_text());assert file_sha(folder/'raw-trials.dat.xz')==nested['compressed_sha256'];selected={};digest=hashlib.sha256();count=size=0
 with lzma.open(folder/'raw-trials.dat.xz','rb')as stream:
  while header:=stream.readline():
   f=header.split();n=int(f[2]);assert n==34;block=[header,*[next(stream)for _ in range(n+3)]];count+=1
   for raw in block:digest.update(raw);size+=len(raw)
   key=tuple(round(float(x),12)for x in f[:2])
   if key in accepted:selected[key]=block
 assert digest.hexdigest()==nested['raw_sha256']and size==nested['raw_bytes']
 assert count==capture['selection']['total_trial_records']==65482 and set(selected)==set(accepted)
 recomputed=folder/'recomputed-inputs.dat'
 with recomputed.open('wb')as stream:
  for key,receipt in sorted(accepted.items()):
   block=selected[key];nodes=[list(map(float,l.split()))for l in block[4:]];assert all(len(r)==39 for r in nodes)
   assert abs(sum(row[33]for row in nodes)-receipt[3])<1e-12 and abs(float(block[0].split()[4])-receipt[2])<1e-12
   stream.writelines(block)
 batch_hash=file_sha(recomputed);assert batch_hash==file_sha(folder/'capture/accepted-inputs.dat')==capture['selection']['batch_sha256']==paired['input_batch_sha256']==controls['input_sha256']
 assert len(accepted)==5066
 for day in [583,584,585]:assert abs(math.fsum(v[1]-v[0]for v in accepted.values()if int(v[0])==day-1)-1)<1e-10
 original_gate={};daily={}
 for opt in ['O0','O2']:
  m=paired['paired'][opt];raw=folder/'paired'/opt/'paired.stdout';rows,_=output_rows(raw);assert len(rows)==m['cases']==5066
  assert file_sha(raw)==m['raw_stdout_sha256']and file_sha(folder/'paired'/opt/'paired')==m['binary_sha256']
  values=[{k:float(v)for k,v in row.items()}for row in rows]
  maxima={key:max(r[key]for r in values)for key in ['oxygen_max_error','current_replay_error','source_current_nodal_error','source_tight_nodal_error']};assert maxima==m['maxima']
  assert maxima['current_replay_error']==0 and all(r['source_checks']==3 and r['tight_status']==0 for r in values)
  assert m['existing_oxygen_gate_pass']==(maxima['oxygen_max_error']<=1e-4)is False
  assert m['existing_micro_gate_pass']==(maxima['source_current_nodal_error']<=2e-5)is False
  result={}
  for day in [583,584,585]:result[str(day)]={key:math.fsum(r[key]*(r['t1']-r['t0'])for r in values if int(r['t0'])==day-1)for key in ['observed_uptake','source_uptake','tight_uptake','source_current_total_error','source_tight_total_error']}
  assert result==m['daily'];daily[opt]=result;original_gate[opt]=dict(oxygen=False,micro=False)
 assert(folder/'paired/O0/paired.stdout').read_bytes()==(folder/'paired/O2/paired.stdout').read_bytes()
 precision={}
 for name,m in controls['controls'].items():
  raw=folder/'precision'/name/'paired.stdout';rows,chains=output_rows(raw);assert len(rows)==len(chains)==m['cases']==5066
  assert file_sha(raw)==m['stdout_sha256']and file_sha(folder/'precision'/name/'paired')==m['executable_sha256']and file_sha(folder/'precision'/name/'oxygenstress.f90')==m['provider_sha256']
  assert max(float(c[4])for c in chains)==m['max_original_current_oxygen']and max(float(c[5])for c in chains)==m['max_current_observed_oxygen']==0
  assert all(int(c[8])==3 for c in chains)and m['all_original_chain_checks']
  result={}
  for r,c in zip(rows,chains):
   assert int(r['case'])==int(c[1])and float(r['current_replay_error'])==0
   day=str(int(float(c[2]))+1);dt=float(c[3])-float(c[2]);v=result.setdefault(day,dict(duration=0.,observed_uptake=0.,original_micro_current_oxygen=0.,original_whole_chain=0.))
   v['duration']+=dt;v['observed_uptake']+=float(r['observed_uptake'])*dt;v['original_micro_current_oxygen']+=float(r['source_uptake'])*dt;v['original_whole_chain']+=float(c[6])*dt
  assert result==m['daily']and all(abs(v['duration']-1)<1e-10 for v in result.values())
  precision[name]=m['max_original_current_oxygen']
  if name.startswith('O0-'):assert raw.read_bytes()==(folder/'precision'/name.replace('O0-','O2-',1)/'paired.stdout').read_bytes()
 assert len(precision)==16
 # Each controlled original provider may change only these declared numerical
 # statements; the literal source and all model formula statements stay intact.
 baseline=(folder/'precision/O2-1.d-4/oxygenstress.f90').read_text()
 from original_sources import select_dec_branches
 authority=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(authority.read_bytes())))as original:
  oxygen=select_dec_branches(original.extractfile('SWAP/oxygenstress.f90').read().decode('cp1252')).replace('\r\n','\n')
  micro=select_dec_branches(original.extractfile('SWAP/RWU_micro.f90').read().decode('cp1252')).replace('\r\n','\n')
 assert baseline==oxygen,'literal original provider is not immutable B1.11'
 anchor='public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table';assert micro.count(anchor)==1
 for opt in ['O0','O2']:assert(folder/'paired'/opt/'visible_original_rwu.f90').read_text()==micro.replace(anchor,anchor+', RWU_micro, get_MFLP_K')
 for name,m in controls['controls'].items():
  accuracy=re.match(r'O[02]-(1\.d-\d+)',name)[1];expected=baseline.replace('        accuracy = 1.d-4','        accuracy = '+accuracy)
  if m['refresh_published_macro']:
   anchor='            SOLVE = ZBREND (myFUNC,a,b,Dif_a,Dif_b,accuracy)';assert expected.count(anchor)==1;expected=expected.replace(anchor,anchor+'\n            fxi = myfunc(SOLVE) ! observe concentration at the published root')
  if m['quadrature_precision']:
   anchor='      real(8), parameter         :: EPS   = 1.0d-5            ! 1.0D-8';assert expected.count(anchor)==1;expected=expected.replace(anchor,'      real(8), parameter         :: EPS   = '+m['quadrature_precision']+'            ! declared standard-MvG quadrature precision control')
  assert(folder/'precision'/name/'oxygenstress.f90').read_text()==expected,('unexpected original model change',name)
 # Re-evaluate the independent numerical witness, using two distinct methods.
 from waterfilm_high_precision import witness
 selected_cases=folder/'selected-cases.dat';reference=json.loads((folder/'WATERFILM_HIGH_PRECISION.json').read_text());assert file_sha(selected_cases)==reference['input_sha256']
 with selected_cases.open()as f:
  for expected in reference['records']:
   header=f.readline();n=int(header.split()[2]);lines=[next(f)for _ in range(n+3)];assert header.split()[0]==expected['t0']
   assert [witness(lines[3+6].split(),7,d)for d in [50,80]]==expected['witnesses']
 result=dict(status='SOURCE_BOUND_ACTUAL_UPTAKE_DIAGNOSIS_PASS',full_original_authority_unchanged=True,literal_native_prefix_days=585,trial_records=count,accepted_cases=len(accepted),current_nodal_replay_error=0.,original_component_gates=original_gate,precision_maxima=precision,daily_micro_isolation=daily,whole_scientific_qualification=False,production_promoted=False)
 return result

def verify():
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/verify_sprint03.py')],cwd=ROOT,check=True)
 m=json.loads((DIRECTORY/'UPTAKE_EVIDENCE_MANIFEST.json').read_text())
 for name,pin in m['source_sha256'].items():safe(name);assert file_sha(ROOT/name)==pin,name
 with tempfile.TemporaryDirectory(prefix='hupsel-uptake-')as tmp:
  folder=Path(tmp);cap=folder/'capsule.tar.xz'
  with cap.open('wb')as dest:
   for part in m['archive_parts']:
    safe(part['path']);source=DIRECTORY/part['path'];assert source.stat().st_size==part['bytes']and file_sha(source)==part['sha256']
    with source.open('rb')as stream:
     while raw:=stream.read(4*1024*1024):dest.write(raw)
  assert file_sha(cap)==m['archive_sha256']and cap.stat().st_size==m['archive_bytes']
  with tarfile.open(cap)as t:
   names=t.getnames();assert len(names)==len(set(names))and set(names)==set(m['members'])
   for member in t.getmembers():
    path=safe(member.name);assert member.isfile();target=folder.joinpath(*path.parts);target.parent.mkdir(parents=True,exist_ok=True)
    with t.extractfile(member)as source,target.open('wb')as dest:
     while raw:=source.read(4*1024*1024):dest.write(raw)
    assert file_sha(target)==m['members'][member.name],member.name
  result=inspect(folder);assert result==json.loads((folder/'ANALYSIS.json').read_text())
 print(json.dumps(result,indent=2))
if __name__=='__main__':verify()
