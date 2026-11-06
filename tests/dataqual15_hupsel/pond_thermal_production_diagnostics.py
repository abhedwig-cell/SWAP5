"""Independent actual source/before verdicts and deployed six-case raw physics."""
import argparse,hashlib,json,re,struct,zipfile,zlib
from pathlib import Path
import pond_thermal_production as owner
D=owner.ROOT/'integration/dataqual15_hupsel'
STEM='POND_THERMAL_PRODUCTION_'
sha=lambda b:hashlib.sha256(b).hexdigest()

def unzip(path):
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names))
  assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in names)
  return {n:z.read(n) for n in names}

def before(files,count):
 result=json.loads(next(b for n,b in files.items() if n.endswith('RESULT.json')))
 assert result['baseline']==owner.BASE and result['tree']==owner.git('rev-parse',owner.BASE+'^{tree}')
 assert result['whole_scientific_admission'] is False and result['old_gate_pass_claim'] is False
 assert len(result['events'])==count;data={}
 for e in result['events']:
  assert e['returncode'] not in (None,0) and e['censored'] is False
  streams=[]
  for stream in ('stdout','stderr'):
   blob=next(b for n,b in files.items() if n.endswith(e['case']+'.'+stream))
   assert sha(blob)==e[stream+'_sha256'];streams.append(blob.decode(errors='replace'))
  data[e['case']]='\n'.join(streams)
 return data

def mc(files):
 def current(inputs):
  for path,digest in inputs.items():assert sha(owner.normal((owner.ROOT/path).read_bytes()))==digest,path
 def values(text,label):return [float(x) for x in re.search('^'+label+'=(.*)$',text,re.M)[1].split()]
 proper=0;fresh=0;semantic=0
 expected=json.loads((D/(STEM+'POSIX_20261106.json')).read_text())
 for exponent in ('1','0.5','0.8','1.0005','1.5','2'):
  prefix='physical-'+exponent+'/';qp='qualified-'+exponent+'/'
  r=json.loads(files[prefix+'result.json']);q=json.loads(files[qp+'result.json'])
  assert r['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
  assert q['status']=='DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED'
  assert q['physical_sha256']==sha(files[prefix+'result.json'])
  assert r['exponent']==float(exponent) and r['results']['O0']==r['results']['O2']
  assert all(e['returncode']==0 for e in r['events'])
  assert all(e['returncode']==e['expected_returncode'] for e in q['events'])
  current(r['inputs']);current(q['inputs'])
  for opt in ('O0','O2'):
   masses=[];decays=[]
   for mesh in (2,4,8,16,32,64,128,256):
    row=r['results'][opt][str(mesh)];text=row['stdout'][0]
    assert 'THERMAL_PHYSICAL_LITERAL_RESTART=PASS' in text
    assert values(text,'MAX_SOLUTE_RESIDUAL')[0]<1e-11
    masses.append(values(text,'MASS_VECTOR'));decays.append(values(text,'DECAY')[0])
    full=files[prefix+f'{opt}/{mesh}/full.bin'];resumed=files[prefix+f'{opt}/{mesh}/resumed.bin']
    assert full==resumed and sha(full)==row['endpoint_sha256'];fresh+=1
    path=f'{opt}/{mesh}/restart.bin';blob=files[prefix+path]
    assert zlib.crc32(blob[:-4])==struct.unpack_from('=I',blob,len(blob)-4)[0];proper+=1
    if exponent=='1':assert sha(blob)==expected['members']['physical/'+path]
   md=[max(abs(a-b) for a,b in zip(x,y)) for x,y in zip(masses,masses[1:])]
   dd=[abs(a-b) for a,b in zip(decays,decays[1:])]
   assert all(a>b>0 for a,b in zip(md,md[1:])) and all(a>b>0 for a,b in zip(dd,dd[1:]))
   assert dd[-1]/decays[-1]<1e-3 and md[-1]/max(masses[-1])<1e-6
   assert q['results'][opt]['mass_delta']==md and q['results'][opt]['decay_delta']==dd
   assert q['results'][opt]['kill_before_after_generation_exact'] is True
   semantic+=len(q['results'][opt]['semantic_negatives'])
   assert r['results'][opt]['controls']=='THERMAL_REJECTION_RETRY_HEAT_OFF=PASS\n'
   # The existing MC collector retains .bin but omits .before/.after files.
   # Preserve that limit: independent raw byte equality comes from the complete
   # current original-build capsule, not invented MC members.
   if exponent=='1':
    names=expected['members'];control='physical/'+opt+'/controls/control.'
    assert names[control+'before']==names[control+'after']
    assert names[control+'initial']==names[control+'hydraulic']
 annual=json.loads(files['annual/result.json']);incumbent=json.loads(files['incumbent/result.json'])
 assert annual['status']=='PHYSICAL_LONG_FILE_RUNS_PASS_ACCURACY_ASSESSMENT_REQUIRED'
 assert len(annual['events'])==30 and all(e['returncode']==0 for e in annual['events']);current(annual['inputs'])
 assert incumbent['status']=='PASS' and len(incumbent['events'])==86
 assert incumbent['test_sha256']==sha(owner.normal((owner.ROOT/'tests/nut-sol/test_column_input.py').read_bytes()))
 assert incumbent['runner_sha256']==sha(owner.normal((owner.ROOT/'tools/solute/run_column.py').read_bytes()))
 for opt in ('O0','O2'):current(json.loads(files['column-'+opt+'/build-complete.json'])['input_sha256'])
 assert proper==fresh==96
 return dict(six_actual_exponents=True,proper_native_crc=proper,exact_fresh_endpoints=fresh,semantic_refusals=semantic,
             original_incumbent_events=86,annual_physical_events=30,annual_accuracy_admission=False,whole_scientific_admission=False)

def adjudicate(flows,prior):
 mapping={
 'PUB-P2E10 broad E0 paired matrix':('p2e10','P2E10 mutated src or reference'),
 'PUB-P2E09 Reference-only threshold freeze':('p2e09','P2E09 mutated src or reference relative to current canonical merge-base'),
 'PUB-P2E08 Reference valid calibration domain':('p2e08','P2E08 mutated src or reference relative to reconciled canonical'),
 'PUB-P2E07 Reference cancellation floor':('p2e07','P2E07 mutated src or reference'),
 'PUB-P2E06 Reference local-balance scaling':('p2e06','reference tree differs from P2E05 canonical base'),
 'PUB-ME D1 transition authority':('d1','D1 workunit changed production/reference source'),
 'PUB-ME D3 origin authority':('d3','D3 changed production/reference source'),
 'PUB-P2E02 Reference uncertainty':('p2e02','Cannot open module file'),
 'PUB-P2E04 Reference B/C sweeps':('p2e04','Cannot open module file'),
 'PUB-P2E04 Reference failure census':('census','Cannot open module file'),
 'SWAP5-PERF01 exact implementation admission':('performance','AssertionError: unreviewed delta'),
 'MC-SOL01 dynamic thermal pond and file application':('pond-source','AssertionError: unreviewed delta'),
 'Hupsel production native crop logical successor':('logical-owner',".splitlines())=={SOURCE}"),
 'Hupsel production diagnostic source successor':('logical-owner',".splitlines())=={SOURCE}"),
 'Registered Grassgrowth thermal production profile':('thermal-owner',".splitlines())==PATHS"),
 'DATAQUAL15 original Grassgrowth sprint':('native-layout','unreviewed production paths')}
 rows=[];staging=[];seen=set()
 for flow in flows:
  name=flow['workflow'];seen.add(name)
  for job in flow['jobs']:
   text=job['log'];assert job['conclusion']=='failure' and flow['head']=='6603af42f6e138b06146e049c30eba6a58f240e0'
   if name=='Unmodified original pond thermal build qualification':
    assert 'AssertionError: input drift: '+owner.SOURCE in text
    staging.append(dict(job=job['id'],reason='UNCHANGED_PRIVATE_SOURCE_GUARD_REFUSAL_CORRECTED_BY_EXACT_PREDECESSOR_PROJECTION',verdict='FAILED_RETAINED'));continue
   if name=='F-CI canonical qualification':
    assert 'FileNotFoundError' in text and 'POND_THERMAL_PRODUCTION_POSIX_20261106.json' in text
    staging.append(dict(job=job['id'],reason='POSIX_EXECUTION_CAPSULE_NOT_YET_VERSIONED_AT_INITIAL_HEAD',verdict='FAILED_RETAINED'));continue
   case,signature=mapping[name];assert signature in text
   classification='SAME_ACTUAL_PREDECESSOR_FAILURE_RETAINED'
   if signature not in prior[case]:
    if case=='p2e09':assert 'PUB_P2E09_GATE_FAIL admitted P2E08 Reference replay' in prior[case]
    elif case=='p2e10':assert 'PUB_P2E10_GATE_FAIL solver contract drift' in prior[case]
    else:raise AssertionError('unexplained changed failure: '+name)
    classification='EARLIER_CURRENT_SOURCE_REFUSAL_DISTINCT_FROM_LATER_PREDECESSOR_FAILURE'
   rows.append(dict(run=flow['run'],job=job['id'],workflow=name,case=case,current_signature=signature,classification=classification,verdict='FAILED_RETAINED'))
 assert seen==set(mapping)|{'Unmodified original pond thermal build qualification','F-CI canonical qualification'}
 assert len(rows)==19 and len(staging)==2
 return rows,staging

def observe(self_test=False):
 original=D/(STEM+'EXACT_BEFORE_20261106.zip');assert sha(original.read_bytes())=='a893a1432822ac0a9801169ec7aa21ed3c49773c453da2dd0057bb7cc9d86f20'
 prior=before(unzip(original),16)
 extra=json.loads((D/(STEM+'BEFORE_POND_SOURCE_20261106.json')).read_text())
 extra_zip=D/(STEM+'BEFORE_POND_SOURCE_20261106.zip');assert sha(extra_zip.read_bytes())==extra['zip_sha256'];prior.update(before(unzip(extra_zip),1))
 meta=json.loads((D/(STEM+'INITIAL_FAILURES_20261106.json')).read_text());zpath=D/(STEM+'INITIAL_FAILURES_20261106.zip');assert sha(zpath.read_bytes())==meta['zip_sha256']
 raw=unzip(zpath);assert {n:sha(b) for n,b in raw.items()}==meta['members'];flows=[]
 for n,b in raw.items():
  if n.endswith('/workflow.json'):
   flow=json.loads(b)
   for job in flow['jobs']:job['log']=raw[str(flow['run'])+'/'+str(job['id'])+'.log'].decode()
   flows.append(flow)
 rows,staging=adjudicate(flows,prior)
 mcp=D/(STEM+'CURRENT_MC_20261106.zip');assert sha(mcp.read_bytes())=='407d0cb17f4363e7db4f3a51a932822a6504c770bdab76554a05ecbd6e570ce3'
 files=unzip(mcp);physical=mc(files)
 if self_test:
  path='physical-1/O0/2/restart.bin';saved=files[path];files[path]=b''
  try:mc(files)
  except (AssertionError,struct.error):pass
  else:raise AssertionError('corrupt current native accepted')
  files[path]=saved
  text=prior['p2e10'];prior['p2e10']=''
  try:adjudicate(flows,prior)
  except AssertionError:pass
  else:raise AssertionError('missing actual distinct predecessor failure accepted')
  prior['p2e10']=text
 return dict(predecessor=owner.BASE,before_cases=17,all_before_verdicts='FAILED_RETAINED_UNCENSORED',source_head='6603af42f6e138b06146e049c30eba6a58f240e0',adjudicated=rows,initial_staging_refusals=staging,current_physical=physical,old_red_pass_claim=False,whole_scientific_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--seal',action='store_true');p.add_argument('--self-test',action='store_true');a=p.parse_args();owner.guard();result=observe(a.self_test);path=D/(STEM+'DIAGNOSTICS_20261106.json')
 if a.seal:path.write_text(json.dumps(result,indent=2)+'\n')
 else:assert result==json.loads(path.read_text())
 print(json.dumps(dict(before_cases=result['before_cases'],failed_source_jobs=len(result['adjudicated']),initial_staging_refusals=len(result['initial_staging_refusals']),current_physical=result['current_physical'],old_red_pass_claim=False),sort_keys=True))
