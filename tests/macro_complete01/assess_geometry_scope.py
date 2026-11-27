from pathlib import Path
import json,hashlib,math,collections
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[];witness=[];traces=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);p=b/'SCOPE35_CONTEXT64TO65';a=list(map(float,(p/'original/macro_geometry_scope.txt').read_text().split()));i=0;frames=[]
 while i<len(a):
  hd=a[i:i+10];n,nd=map(int,hd[:2]);i+=10;v=[a[i+k*n:i+(k+1)*n] for k in range(7)];i+=7*n;cm=[a[i+24*k:i+24*(k+1)] for k in range(nd)];i+=24*nd;flow=[a[i+k*n*nd:i+(k+1)*n*nd] for k in range(6)];i+=6*n*nd
  cell,pt,pb=[int(x)-1 for x in hd[5:8]];gap=math.fsum(max(0.,v[2][j]-v[1][j])*v[4][j] for j in range(pb+1,cell));assert gap>.1
  internal=[math.fsum(flow[1][j*nd+d] for j in range(n)) for d in range(nd)];assert all(x>0 for x in internal)
  for d in range(nd):assert math.isclose(hd[3]*internal[d],cm[d][10]*cm[d][7],rel_tol=1e-12,abs_tol=1e-18)
  frames.append(dict(header=hd,separate_gap_air_inventory_cm=gap,internal_cm_day=internal,domain_factors=[dict(incoming=x[7],outgoing=x[15]) for x in cm],perched_node_geometry_frozen=v[5][pt]==0 and v[6][pt]==0))
 assert len(frames)==64 and i==len(a);witness.append(a)
 original=b/'GEOMETRY_V33_DAY65';q=json.loads((original/'RESULT.json').read_text());assert q['status']=='MODEL_CAP_REACHED' and not q['rows']
 tr=[list(map(float,l.split())) for l in (original/'original/jac37_trace.txt').read_text().splitlines() if len(l.split())==22];traces.append(tr)
 reports.append(dict(opt=opt,status=q['status'],elapsed_seconds=q['elapsed_seconds'],last_observed_time=tr[-1][0],solver_rows=len(tr),max_observed_iterations=max(x[2] for x in tr),helper_status_counts=dict(collections.Counter(str(int(x[3])) for x in tr)),first_scope_witness=frames[0],last_scope_witness=frames[-1],all64_witnesses_true_separate_airgap=True,no_day65_accepted_receipt=True,read_only_probe_status=json.loads((p/'RESULT.json').read_text())['status']))
assert witness[0]==witness[1];n=min(map(len,traces));assert traces[0][:n]==traces[1][:n]
q=dict(scope='Actualoriginalday65 firstgenuineperchedregime witness. First64excludedstates have airgap>original.1cm criticalinventory and positiveinternalinflowinall5domains; physicalclassificationretained. Exactcausalcontributionstofinalstallnotyetfullyqualified; no speculativephysicsfix.',results=reports,common_parent_trace_rows_exact=n,all_scope_witnesses_O0_O2_exact=True,models_launched=0,next_contract='Extend fullJacobian with originalSATFLOW internalincoming localpressure derivative, perchedlevel contactgeometry derivative, and internalpotential dI in every active stockprojection, subtracting existingnativecontributionsonce. Preserve originalperchedclassification, ABSORPTIONexclusion andbudgets. Validate actualcoupledFDandwaterinventory before claiming a remedy.')
(R/'BLOCK35_DAY65_PERCHED_SCOPE_DIAGNOSIS.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
