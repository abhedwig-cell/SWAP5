"""No model calls: current solve, accepted hostcommit and independent inventory audit."""
from pathlib import Path
from collections import Counter
import json,hashlib,math,csv
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-combined62';P61=R.parent/'swap431-macro-b1-potential61'
def rows(p):return [[float(v) for v in s.split()] for s in p.read_text().splitlines() if s.strip()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines() if s.strip()}
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
linear=[];progress=[];results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 initial_data=R/'data_initial_payload_guarded'/opt/'RESTART_D2'
 at=rows(d/'attempt_trace.txt');assert at[0][:-1]==rows(initial_data/'attempt_trace.txt')[0][:-1]
 assert len(at)==2 and at[0][8:11]==[4,1,0] and at[1][8:11]==[0,0,0]
 assert at[1][3]==1e-5 and at[1][7]==3 and at[1][6]==1 and at[1][25]==1
 assert 'NATIVE55_RESTART_ONE_FULL_STEP' in (d/'outcome.txt').read_text()
 inp=json.loads((R/(opt+'_RESTART_D2_INPUT.json')).read_text());assert inp['own_end_sha256']==sha(d/'own.end')=='59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e'
 assert (d/'context_initial.txt').read_bytes()==(P/'data'/opt/'RESTART_D2/context_initial.txt').read_bytes()
 ini=fields(d/'context_initial.txt');retry=fields(d/'context_follow_begin_2.txt');assert {k for k in ini if ini[k]!=retry[k]}=={'dt','fldtmin'}
 assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_follow_begin_2.txt').read_bytes()
 assert not list(d.glob('*points.txt')) and not (d/'combined62_local.txt').exists()
 sol=fields(d/'solver_2.txt');assert sol['outcome']==[0,3,1] and sol['controls'][5:7]==[1e-6,1e-5]
 F=sol['residual'];assert len(F)==112 and max(map(abs,F))<1e-6 and abs(sum(F))<1e-5
 nt=rows(d/'node_iterations.txt');assert len([x for x in nt if x[0]==2 and x[2]==6])==1
 tr=rows(d/'jac63_trace.txt');assert len(tr)==33
 active=[x for x in tr if x[2]==1];assert len(active)==27 and all(x[3]==1 and x[26]==1 for x in active)
 assert Counter((int(x[0]),int(x[4])) for x in active)=={(1,1):24,(2,1):1,(2,2):2}
 assert Counter(int(x[2]) for x in tr if x[2]!=1)=={-5:6}
 # Independent reconstruction of each actual (A+UV')x=r, with all112 components.
 systems=rows(d/'jac63_systems.txt');assert len(systems)==10*len(active)
 assert systems[:250]==rows(initial_data/'jac63_systems.txt')[:250]
 reference=rows(P61/'data'/opt/'RESTART_D2/potential61_i53_points.txt');CD=reference[9];z=reference[10];rho=reference[0][21]
 nodes=rows(d/'iteration_nodes.txt');max_linear=0;max_mass=0
 for k in range(0,len(systems),10):
  hd,a,b,c,rhs,x,u1,v1,u2,v2=systems[k:k+10];attempt,it,n,branch,t,dt,seq=hd;assert n==112
  row=next(q for q in active if q[0:2]==[attempt,it]);meta=row[2:26];assert [branch,t,dt,seq]==[meta[2],meta[20],meta[21],meta[22]]
  dot1=math.fsum(v*y for v,y in zip(v1,x));dot2=math.fsum(v*y for v,y in zip(v2,x))
  res=[b[i]*x[i]-rhs[i]+(a[i]*x[i-1] if i else 0)+(c[i]*x[i+1] if i<111 else 0)+u1[i]*dot1+u2[i]*dot2 for i in range(112)]
  error=max(map(abs,res));assert error<1e-14;max_linear=max(max_linear,error)
  h50=next(q[5] for q in nodes if q[0:3]==[attempt,it,2] and q[4]==50);h51=next(q[5] for q in nodes if q[0:3]==[attempt,it,2] and q[4]==51)
  den=h51-h50;g0=(z[49]-z[50])*h51/den**2;g1=-(z[49]-z[50])*h50/den**2
  Lgrad=[0.]*112
  if branch==2:Lgrad[49]=rho*g0;Lgrad[50]=rho*g1
  f=meta[3]
  # D3local satdiag stays once; other domains/matrix are not subtracted.
  masserr=max(abs((f*CD[j] if 50<=j<=56 else 0)+math.fsum(u1)*v1[j]+math.fsum(u2)*v2[j]-Lgrad[j]/dt) for j in range(112));assert masserr<1e-10;max_mass=max(max_mass,masserr)
  assert row[-2]>1e-12 and math.isfinite(row[-2])
  linear.append([opt,int(attempt),int(it),int(branch),seq,row[-2],error,masserr])
 for q in nt:
  if q[2]==4:progress.append([opt,int(q[0]),int(q[1]),q[15],q[14],q[16],int(q[3]>4)])
 # Independent waterinventory from compartment fields, not precomputed domain delta.
 before=fields(d/'follow_begin_2.txt');after=fields(d/'follow_committed.txt');bctx=fields(d/'context_follow_begin_2.txt');actx=fields(d/'context_follow_committed.txt')
 iv=rows(d/'inventory_trace.txt');budget=rows(d/'step_budget.txt');assert len(iv)==len(budget)==1 and iv[0][1]==2 and iv[0][11]==1
 v=budget[0];accepted_dt=v[1];assert accepted_dt==1e-5 and v[16]==1
 dm=math.fsum((b-a)*dz*fr for a,b,dz,fr in zip(before['theta'],after['theta'],before['dz'],before['fraction']))
 dx=math.fsum(b-a for a,b in zip(before['macro_compartment'],after['macro_compartment']))
 dp=after['pond'][0]-before['pond'][0];dc=actx['sicact'][0]-bctx['sicact'][0]
 external=accepted_dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
 balance=dm+dx+dp+dc-external;limit=accepted_dt*sol['controls'][6]
 assert abs(balance)<limit and abs(balance-iv[0][9])<2e-15
 assert abs(balance-accepted_dt*sum(F))<2e-15
 domain_errors=[]
 for j in range(5):
  dw=math.fsum(b-a for a,b in zip(before['macro_compartment'][j::5],after['macro_compartment'][j::5]))
  expected=accepted_dt*(v[17+j]+v[22+j]-v[27+j])-(accepted_dt*v[12] if j==0 else 0)
  domain_errors.append(dw-expected)
 assert max(map(abs,domain_errors))<1e-14
 assert (d/'follow.end').exists() and sha(d/'follow.end')!=sha(d/'own.end')
 assert (d/'ledger_follow_committed.txt').read_bytes()==(d/'ledger_final.txt').read_bytes() and (d/'ledger_final.txt').read_bytes()!=(d/'ledger_initial.txt').read_bytes()
 assert abs(actx['t1900'][0]-(ini['t1900'][0]+accepted_dt))<1e-10
 results.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,attempts=2,original_larger_refusal=dict(dt=at[0][3],iterations=30,Fmax=at[0][18],sumF=at[0][17],node=int(at[0][19])),accepted_retry=dict(dt=accepted_dt,iterations=3,Fmax=max(map(abs,F)),sumF=sum(F),fresh_checks=1,IDecMpRat=0,FrReduQ=1,hostcommits=1,t1900=actx['t1900'][0]),correction_uses=27,branch_counts=dict(Counter(str(int(x[4])) for x in active)),actual_retry_W_then_V_branches=[int(x[4]) for x in active if x[0]==2],guarded_fallbacks=6,max_independent_linear_residual=max_linear,max_D3_mass_derivative_error=max_mass,larger_rejection_rollback_exact_except=['dt','fldtmin'],ledger_before_retry_exact=True,independent_water_inventory=dict(matrix_delta=dm,macro_compartment_delta=dx,pond_delta=dp,canopy_delta=dc,external=external,error_cm=balance,original_limit_cm=limit,error_minus_residual_times_dt_cm=balance-accepted_dt*sum(F),domain_error_cm=domain_errors),own_follow_packet_sha256=sha(d/'follow.end'),follow_packet_bytes=(d/'follow.end').stat().st_size))
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2'
files=[p.name for p in x.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
for n in files:assert (x/n).read_bytes()==(y/n).read_bytes(),n
assert sha(x/'follow.end')==sha(y/'follow.end')
assert [a[:-1] for a in rows(x/'attempt_trace.txt')]==[a[:-1] for a in rows(y/'attempt_trace.txt')]
for opt in ['O0','O2']:
 q=json.loads((R/('INITIAL_'+opt+'_RESTART_D2_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20
# Constitutive, clocks, hostintegration/native layout and nonlinearpolicy owners unchanged.
for n in ['macropore_native.f90','calcgwl_probe.f90','integral_canopy.f90','soilwater_native.f90','native_state.f90','meteo_native.f90','swap_native.f90','swapoutput_native.f90']:
 assert (R/n).read_bytes()==(P/n).read_bytes(),n
s=(R/'macrorate_node.f90').read_text();old=(P/'macrorate_node.f90').read_text();key='      subroutine SATFLOW';assert s[s.lower().index(key.lower()):]==old[old.lower().index(key.lower()):]
for name,cols,data in [('LINEAR_AUDIT.csv',['opt','attempt','iteration','branch','sequence','woodbury_det','independent_linear_error','D3_mass_derivative_error'],linear),('ITERATION_PROGRESS.csv',['opt','attempt','iteration','Fmax','sumF','objective','exhausted'],progress)]:
 with (R/name).open('w',newline='',encoding='utf-8') as f:w=csv.writer(f);w.writerow(cols);w.writerows(data)
q=dict(work_unit='SWAP431-MACRO-B1-COMBINED63',decision='GUARDED_COMBINED_D3_UPDATE_ACCEPTED_UNSCALED_DTMIN_RETRY_O0_O2',initial_guarded_payload_runs_preserved=2,final_qualification_routes=2,total_model_routes=4,hard_seconds_per_route=20,all_routes_uncensored=True,COMBINED62_nondoublecount_rank2_implemented=True,current_before_derivative_potential_payload_saved_and_sequence_stamped=True,scratch_payload_serializers_extended=True,no_new_native_physical_fields=True,O0_O2_physical_traces_and_follow_packet_exact=True,larger_original_attempt_still_rejected=True,dtmin_retry_converges_with_fresh_check=True,hostcommit_and_independent_inventory_qualified=True,physics_clock_criteria_dt_reduction_budgets_unchanged=True,no_provider_perturbations=True,forced_reject_direct_retry_generalrestart_period_not_qualified=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='MINIMAL_IMPLEMENTATION_TESTED_ACCEPTED_SINGLE_RETRY_HOSTCOMMIT',recovery='REPORT.md; RESULT.json; IMPLEMENTATION_CONTRACT.md; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps([dict(opt=x['optimization'],seconds=x['seconds'],accepted=x['accepted_retry'],watererror=x['independent_water_inventory']['error_cm'],linearerror=x['max_independent_linear_residual']) for x in results],indent=2))
