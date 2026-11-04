"""Independent accepted root receipt audit, preserving all original limits."""
import argparse,collections,copy,csv,hashlib,io,json,math,subprocess,sys,tarfile
from pathlib import Path
from full_profile_evidence import unpack
from scientific_followup import rows
from root_oxygen_observer import instrument,MAIN
from inspect_profiles import profile
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
STEM='ROOT_OXYGEN_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
def table(b):return list(csv.DictReader(io.StringIO(b.decode())))
def data(b,width):
 result=[list(map(float,line.split())) for line in b.splitlines()]
 assert result and all(len(r)==width and all(map(math.isfinite,r)) for r in result)
 return result
def audit(trace,nodes,budget):
 assert trace[0][0]==524 and trace[-1][1]==584
 assert all(a[1]==b[0] for a,b in zip(trace,trace[1:]))
 assert all(r[1]>r[0] and r[8]==1 and -1e-12<=r[7]<=1+1e-12 for r in trace)
 assert all(all(map(math.isfinite,r)) for r in trace+nodes)
 assert all(abs(r[2]-r[3]-r[4]-r[5]-r[6])<=1e-12 for r in trace)
 byday=collections.defaultdict(list)
 for r in trace:byday[int(math.ceil(r[1]))].append(r)
 assert sorted(byday)==list(range(525,585))
 columns=['potential_transpiration_cm','drought_reduction_cm','oxygen_reduction_cm','salinity_reduction_cm','actual_transpiration_cm']
 assert [float(r['t1_day']) for r in budget]==list(range(525,585))
 report=[];worst=0
 for r in budget:
  day=int(float(r['t1_day']));parts=byday[day]
  assert parts[0][0]==day-1 and parts[-1][1]==day and len(parts)==int(r['accepted_substeps'])
  integrated={name:math.fsum(s[i+2]*(s[1]-s[0]) for s in parts) for i,name in enumerate(columns)}
  defects={k:integrated[k]-float(r[k]) for k in columns}
  assert max(map(abs,defects.values()))<=1e-10
  worst=max(worst,max(map(abs,defects.values())))
  report.append(dict(day=day,accepted_leaves=len(parts),integrated=integrated,independent_daily_defects=defects,
   deepest_oxygen_factor_min=min(s[7] for s in parts),deepest_oxygen_factor_max=max(s[7] for s in parts)))
 selected=[r for r in trace if (524<=r[0] and r[1]<=525) or (583<=r[0] and r[1]<=584)]
 assert len(selected)==len(nodes)
 for s,n in zip(selected,nodes):
  assert s[:2]==n[:2] and len(n)==104
  assert all(0<=x<=1 for x in n[36:70]) and all(x>=-1e-12 for x in n[70:104])
  assert abs(math.fsum(n[70:104])-s[6])<=1e-10
 return dict(accepted_leaves=len(trace),observed_node_leaves=len(nodes),nodes_per_leaf=34,
  maximum_independent_daily_defect_cm=worst,daily=report)
def measure(files,prior,builds,reference):
 reports={}
 for opt in ('O0','O2'):
  f={n[len(opt)+1:]:b for n,b in files.items() if n.startswith(opt+'/')}
  build=json.loads(f['build/BUILD.json']);assert build['baseline']==builds[opt]
  original_main=next(h for n,h in builds[opt]['source_sha256'].items() if n.replace('\\','/').endswith('/'+MAIN))
  assert build['source_before']==original_main
  assert f['build/main.f90'].decode()==instrument((ROOT/MAIN).read_text())
  assert sha(f['build/main.f90'])==build['source_after'] and sha(f['build/main.o'])==build['object_sha256']
  assert sha(f['build/observed.exe'])==build['executable_sha256'] and sha(f['build/link.args'])==build['link_response_sha256']
  assert all(e['returncode']==0 for e in build['events'])
  for phase in ('whole','unobserved','strict-own-537'):
   run=json.loads(f[phase+'/RESULT.json']);assert run['returncode']==0 and not run['from_start']
   seed=prior['case/checkpoint-524.bin'] if phase!='strict-own-537' else f['whole/checkpoint-537.bin']
   assert run['restart_sha256']==sha(seed)
   assert run['executable_sha256']==(builds[opt]['executable_sha256'] if phase=='unobserved' else build['executable_sha256'])
   assert run['scope']==('STRICT_SAME_BUILD_RESTART_MEASUREMENT' if phase=='strict-own-537' else 'INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION')
   for n,h in run['inputs'].items():assert sha(f[phase+'/'+n])==h and f[phase+'/'+n]==prior['case/'+n]
  assert f['whole/checkpoint.bin']==f['unobserved/checkpoint.bin']==f['strict-own-537/checkpoint.bin']
  assert profile(f['whole/checkpoint-537.bin'])['day']==537 and profile(f['whole/checkpoint.bin'])['day']==584
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   whole=table(f['whole/'+name]);assert whole==table(f['unobserved/'+name])
   assert [r for r in whole if float(r[clock])>537]==table(f['strict-own-537/'+name])
   if opt=='O2':
    original=[r for r in table(prior['case/'+name]) if 524<float(r[clock])<=584]
    if name=='budget.csv':assert whole==original
    else:
     differences=[dict(day=x['day'],fields={k:dict(restarted=x[k],full=y[k]) for k in x if x[k]!=y[k]}) for x,y in zip(whole,original)]
     assert len(differences)==60 and all(set(r['fields'])=={'pressure_average_cm'} for r in differences)
     assert all(float(r['fields']['pressure_average_cm']['restarted'])==0 and float(r['fields']['pressure_average_cm']['full'])!=0 for r in differences)
     assert json.loads(f['RETAINED_FULL_CROP_DIAGNOSTIC_FAILURE.json'])==dict(exact_full_crop_comparison=False,differences=differences)
  if opt=='O2':assert f['whole/checkpoint.bin']==prior['case/checkpoint-584.bin']
  for n in ('root_accepted.dat','root_nodes.dat'):
   assert [r for r in f['whole/'+n].splitlines() if float(r.split()[0])>=537]==f['strict-own-537/'+n].splitlines()
  trace=data(f['whole/root_accepted.dat'],9);nodes=data(f['whole/root_nodes.dat'],104);budget=table(f['whole/budget.csv'])
  seed_state=profile(prior['case/checkpoint-524.bin'])
  assert nodes[0][2:36]==seed_state['head_cm'] and nodes[0][36:70]==seed_state['theta']
  for r in budget:
   for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
    assert abs(float(r[prefix+'_end_'+unit])-float(r[prefix+'_start_'+unit])-float(r[prefix+'_in_'+unit])+float(r[prefix+'_out_'+unit]))<=1e-10
  report=audit(trace,nodes,budget);controls=[]
  for label in ('missing_leaf','duplicate_leaf','oxygen','root_sink','nonfinite','daily_ledger','node_sink'):
   t,n,b=copy.deepcopy((trace,nodes,budget))
   if label=='missing_leaf':t.pop(1)
   elif label=='duplicate_leaf':t.insert(1,t[0])
   elif label=='oxygen':t[0][4]+=1e-6
   elif label=='root_sink':t[0][6]+=1e-6
   elif label=='nonfinite':t[0][2]=float('nan')
   elif label=='daily_ledger':b[0]['oxygen_reduction_cm']=str(float(b[0]['oxygen_reduction_cm'])+1e-6)
   else:n[0][70]+=1e-6
   try:audit(t,n,b)
   except AssertionError:controls.append(label)
   else:raise AssertionError('accepted injected root defect '+label)
  report['rejected_defect_controls']=controls
  if opt=='O2':report['retained_full_crop_diagnostic_failure']=json.loads(f['RETAINED_FULL_CROP_DIAGNOSTIC_FAILURE.json'])
  reports[opt]=report
 source=rows(reference['original/dtmax-0.0003125/result_output.csv'])
 bounds=json.loads(reference['science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json']);limit=bounds['oxygen']['limit']
 original=dict(enumerate(source));assert len(original)==1097
 grouped=collections.defaultdict(list)
 for r in table(prior['case/budget.csv']):grouped[int(math.ceil(float(r['t1_day'])-1e-9))].append(float(r['oxygen_reduction_cm']))
 assert sorted(grouped)==list(range(1,1097))
 errors=[(abs(math.fsum(parts)-float(original[day]['TREDWET'])),day) for day,parts in sorted(grouped.items())]
 crossing=next(d for e,d in errors if e>limit);worst=max(errors)
 assert crossing==525 and worst[1]==584
 profiles=collections.defaultdict(list)
 for r in rows(reference['original/dtmax-0.0003125/hupsel_profiles.csv']):profiles[int(r['day'])].append(r)
 nodes=data(files['O2/whole/root_nodes.dat'],104);states={}
 for day in (525,584):
  first=next(r for r in nodes if r[0]==day-1);ref=profiles[day-1]
  assert len(ref)==34 and [int(r['node']) for r in ref]==list(range(1,35))
  states[str(day)]=dict(clock=day-1,native_head_cm=first[2:36],native_theta=first[36:70],
   original_head_cm=[float(r['head_cm']) for r in ref],original_theta=[float(r['water_content']) for r in ref],
   maximum_absolute_head_difference_cm=max(abs(x-float(r['head_cm'])) for x,r in zip(first[2:36],ref)),
   maximum_absolute_theta_difference=max(abs(x-float(r['water_content'])) for x,r in zip(first[36:70],ref)))
 return dict(status='ACCEPTED_ROOT_OXYGEN_RECEIPTS_AND_STRICT_CONTINUATIONS_PASS',builds=reports,
  original_oxygen_comparison=dict(unchanged_frozen_limit_cm_day=limit,first_crossing_day=crossing,worst_day=worst[1],maximum_error_cm_day=worst[0]),
  same_clock_start_states=states,interpretation='Different trajectory environments measured, not identical forcing or a causal Bartholomeus defect. No thermal or root-density oracle qualification.',
  production_correction_qualified=False,whole_scientific_admission=False)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/native_refinement_evidence.py')],cwd=ROOT,check=True)
 def archive(stem):
  r=json.loads((BASE/(stem+'.json')).read_text());path=BASE/(stem+'.tar.xz');assert sha(path.read_bytes())==r['archive_sha256']
  return unpack(path,r['files_sha256'])
 prior=archive('FULL_PROFILE_EVIDENCE_20261104');old=archive('CORRECTED_ROTATION_EVIDENCE_20261103')
 builds={o:json.loads(old[('build-O0' if o=='O0' else 'build')+'/BUILD.json']) for o in ('O0','O2')}
 m=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());path=BASE/m['archive'];assert sha(path.read_bytes())==m['archive_sha256']
 with tarfile.open(path) as t:ref={n:t.extractfile(n).read() for n in ('original/dtmax-0.0003125/result_output.csv','original/dtmax-0.0003125/hupsel_profiles.csv','science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json')}
 assert all(sha(b)==m['members'][n] for n,b in ref.items())
 if a.capture:
  files={f.relative_to(a.capture.resolve()).as_posix():f.read_bytes() for f in a.capture.resolve().rglob('*') if f.is_file() and f.suffix not in ('.mod',)}
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text())
  assert not record['whole_scientific_admission']
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  path=BASE/(STEM+'.tar.xz');assert sha(path.read_bytes())==record['archive_sha256'];files=unpack(path,record['files_sha256'])
 result=measure(files,prior,builds,ref)
 if a.capture:
  files['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode();path=BASE/(STEM+'.tar.xz')
  with tarfile.open(path,'w:xz') as t:
   for n,b in sorted(files.items()):
    entry=tarfile.TarInfo(n);entry.size=len(b);entry.mtime=0;t.addfile(entry,io.BytesIO(b))
  deps=dict(json.loads((BASE/'NATIVE_REFINEMENT_EVIDENCE_20261104.json').read_text())['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/root_oxygen_observer.py','tests/dataqual15_hupsel/root_oxygen_evidence.py','.github/workflows/hupsel-root-oxygen.yml','integration/dataqual15_hupsel/ROOT_OXYGEN_PREREGISTRATION_20261104.json','integration/dataqual15_hupsel/ROOT_OXYGEN_SCOPE_FINDING_20261104.json'):deps[n]=norm(ROOT/n)
  (BASE/(STEM+'.json')).write_text(json.dumps(dict(status=result['status'],archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},normalized_repository_dependency_sha256=deps,whole_scientific_admission=False),indent=2)+'\n')
 else:assert result==json.loads(files['AUDIT.json'])
 print(result['status']);print(json.dumps({o:dict(accepted_leaves=r['accepted_leaves'],maximum_daily_defect=r['maximum_independent_daily_defect_cm']) for o,r in result['builds'].items()}))
if __name__=='__main__':main()
