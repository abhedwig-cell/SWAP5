from pathlib import Path
import json,zipfile,hashlib,sys
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[];hashes={}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);paths=[b/x for x in ['ORDINARY_V27_FIXED_DAY27','PROFILER30_CONTEXT26TO27','PREPARED_V31_CONTEXT26TO27']];traces=[]
 for p in paths:traces.append([list(map(float,l.split())) for l in (p/'original/jac37_trace.txt').read_text().splitlines() if len(l.split())==22])
 assert traces[1]==traces[2] and traces[0]==traces[1][:len(traces[0])]
 pq,nq=[json.loads((p/'RESULT.json').read_text()) for p in paths[1:]];assert pq['rows']==nq['rows'];assert nq['elapsed_seconds']<20
 assert nq['qualification_context']['source_differences']==[] and nq['qualification_context']['object_differences']==[]
 assert not (paths[2]/'restart_publish.dll').exists()
 row=nq['rows'][0];assert row['committed'] and abs(row['independent_residual_cm'])<=1e-6 and row['budget_step_retries']==0
 with zipfile.ZipFile(paths[1]/'accepted-column-1-day-27.zip') as a,zipfile.ZipFile(paths[2]/'accepted-column-1-day-27.zip') as c:
  assert json.loads(a.read('checkpoint.json'))['receipt']==json.loads(c.read('checkpoint.json'))['receipt']
  for name in ['macro.bin','result.end']:
   assert a.read(name)==c.read(name);v=hashlib.sha256(c.read(name)).hexdigest()
   if opt=='O0':hashes[name]=v
   else:assert hashes[name]==v
 last=list(map(float,(paths[1]/'original/macro_runtime_profile.txt').read_text().splitlines()[-1].split()))
 reports.append(dict(opt=opt,profile_route_seconds=pq['elapsed_seconds'],prepared_route_seconds=nq['elapsed_seconds'],observed_solver_rows=len(traces[2]),capped_parent_trace_exact_rows=len(traces[0]),full_profile_prepared_trace_receipt_native_exact=True,independent_residual_cm=row['independent_residual_cm'],budget_step_retries=row['budget_step_retries'],profile_last_observation=dict(count=last[0],time=last[1],wall_span=last[4],terms=last[5],solve=last[6],logging=last[7],outside=last[8],cpu=last[9]),no_library_compiled_in_model_output=True))
sys.path.insert(0,str(ROOT/'app/hybrid_water'));import daily_host as h
negative=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])/'worker-coupled-prepared-publisher-v31';identity=json.loads((b/'BUILD.json').read_text())['identity']['restart_publisher']
 for field in ['source_sha256','library_sha256']:
  try:h.validate_restart_publisher(b,{**identity,field:'0'*64})
  except ValueError:negative.append(dict(opt=opt,field=field,rejected=True))
  else:raise AssertionError('Changed publisher admitted')
out=dict(scope='Runtime-only preparedpublisher on exact fixedV27 physicalcode from own26. Originalday27 passes; oldcappedroute remains censored. No prefix relabel or full481claim.',results=reports,negative_controls=negative,native_sha256=hashes,models_launched=0,physics_tolerances_and_20s_route_budget_unchanged=True)
(R/'BLOCK31_PREPARED_PUBLICATION_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
