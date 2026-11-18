"""Read-only feedback qualification; no model launches."""
from pathlib import Path
import json, math, hashlib, csv, re
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-contact47';W=Path('C:/Users/Veldh012/swap431-feedback48-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
patch=(R/'IMPLEMENTATION.patch').read_text()
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if '+++ FEEDBACK48/'+p.name+'\n' in patch:
  section=patch.split('+++ FEEDBACK48/'+p.name+'\n',1)[1].split('--- CONTACT47/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+'])
   assert s.count(new)==1;s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
# Clock/event rules and all physical flux formulas are untouched by the source patch.
assert not any('TimAbsCumDmCp(id,ic) =' in l for l in patch.splitlines() if l.startswith(('+','-')))
results=[];events=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';old=P/'data'/opt/'TRAJ'
 a=rows(d/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');c=rows(d/'clock45_trace.txt');z=rows(d/'reference46_trace.txt');h=rows(d/'history44_trace.txt');t=rows(d/'feedback48_trace.txt')
 assert len(a)==len(b)==len(iv)==len(c)==len(z)==344
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert all(x[0]==x[1]==n and x[4:7]==[0,0,1] and x[8:17]==[0]*9 and x[25]==1 and x[18]<=1e-6 and abs(x[17])<=1e-5 for n,x in enumerate(a,1))
 assert all(x[41]==x[1] and x[42]==x[2] and x[43]==1 and x[44]==x[0] and x[45]==a[int(x[0])-1][7] and x[46:48]==[1,1] for x in c)
 assert not list(d.glob('*refus*')) and not list(d.glob('*.bin'))
 for n,(x,v,w) in enumerate(zip(a,b,iv),1):
  assert w[:2]==[n,n] and w[2]==v[0] and w[3]==v[1]==x[3] and x[6]==v[16]==w[11]==1
  ext=v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  assert w[8]==ext and abs(math.fsum(w[4:8])-ext-w[9])<=8*math.ulp(max(abs(y) for y in w[4:9]))
  assert abs(w[9])<v[1]*1e-5 and abs(w[9]-w[10])<1e-15 and abs(w[10]-v[1]*x[17])<1e-18
  assert max(abs(y) for y in w[13:])<1e-13
 ini=fields(d/'initial.txt');fin=fields(d/'final.txt');ci=fields(d/'context_initial.txt');cf=fields(d/'context_final.txt')
 assert ini['controls'][0]==35797 and fin['controls'][0]==b[-1][0] and b[-2][0]<35797.490<=b[-1][0]
 assert ini['fraction']==fin['fraction'] and ini['dz']==fin['dz']
 for name in ['initial','context_initial','ledger_initial','begin','context_begin','ledger_begin']:assert (d/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes(),name
 stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(ini['theta'],fin['theta'],ini['dz'],ini['fraction']))+math.fsum(y-x for x,y in zip(ini['macro_domain'],fin['macro_domain']))+fin['pond'][0]-ini['pond'][0]+cf['sicact'][0]-ci['sicact'][0]
 external=math.fsum(x[8] for x in iv);error=stock-external;limit=math.fsum(x[3]*1e-5 for x in iv)
 assert abs(error)<limit and abs(error-math.fsum(x[9] for x in iv))<1e-14
 L0=fields(d/'ledger_begin.txt');L1=fields(d/'ledger_final.txt');inc={}
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
  inc[key]=L1[key][0]-L0[key][0]-math.fsum(v[1]*v[col] for v in b);assert abs(inc[key])<1e-12
 receipts={(int(x[0]),int(x[3]),int(x[4])):x for x in t};assert len(receipts)==len(t)==136
 continuing=[x for x in h if x[13]==0];assert len(continuing)==len(t)
 for x in h:
  if x[13]==1:assert x[15]==x[17]==x[19]==0
  else:
   rr=receipts[(int(x[0]),int(x[3]),int(x[4]))]
   assert rr[:5]==x[:5] and rr[5:7]==[x[14],x[16]] and x[17]==rr[8]==rr[6]+rr[7]
   assert abs(x[15]-x[14]-x[2])<1e-15 and x[19]==x[18]
 ids={int(x[0]) for x in h if x[12]==0 and x[13]==0};assert ids==set(range(36,126))
 selected=[];oldc=rows(old/'clock45_trace.txt');oldz=rows(old/'reference46_trace.txt')
 for v,x in zip(z,c):
  if int(x[0]) not in ids:continue
  att=int(x[0]);rr=receipts[(att,3,50)]
  assert v[0]==v[3]==x[0] and v[4]==x[45] and v[5]==a[att-1][20] and v[7]==v[26]==1
  assert v[1:3]==x[1:3]==oldc[att-1][1:3] and v[8]==x[61] and v[11]==x[62]
  assert x[60]==0 and x[51]>0 and x[55]==1 and 0<x[30]<1 and v[25]==v[24]==x[39]
  active=v[15]*((v[11]-v[12])/(v[13]-v[14]))**v[16];assert active==v[9]
  ds=math.sqrt(v[8]+v[2])-math.sqrt(v[8]);delta=v[17]*v[18]*(4/v[20])*v[21]*v[22]*v[10]*ds
  assert math.isclose(delta,rr[7],rel_tol=1e-14) and x[65]==x[62]+rr[7]>x[62] and abs(x[65]-x[62]-delta)<=math.ulp(x[62])
  assert v[10]==oldz[att-1][10] and x[64]==oldc[att-1][64] and x[66]==x[63]>0
  bottom=x[69]-x[70]/2;top=min(x[69]+x[70]/2,x[48]);contact=max(0,top-max(bottom,x[33]))/x[70]
  assert math.isclose(contact,v[21]*v[22],rel_tol=1e-12)
  assert v[23]<1e3*v[2]*v[19] and math.isclose(delta*active/v[10],v[24]/v[19],rel_tol=1e-14)
  cfactive=v[15]*((oldc[att-1][62]-v[12])/(v[13]-v[14]))**v[16]
  assert active>cfactive and v[11]>oldc[att-1][62]
  selected.append(dict(optimization=opt,attempt=att,time=v[1],dt=v[2],tau_before=x[61],tau_after=x[64],initial_sorptivity=v[10],active_sorptivity=active,active_sorptivity_with_parent_reference_same_candidate_theta=cfactive,reference_before=x[62],reference_after=x[65],implemented_delta=rr[7],stored_delta=x[65]-x[62],END_contact=x[60],RATE_contact=v[22],actual_sorption_rate=x[51]))
 assert len(selected)==90
 # Successive accepted rates see the previously committed history, without grafting a parent state.
 assert all(x[8]==prev[64] and x[9]==prev[65] and x[10]==prev[66] for prev,x in zip(c,c[1:]))
 assert c[127][59]==0 and c[127][64:67]==[0,0,0] and c[128][51]==0 and c[128][64:67]==[0,0,0]
 # First commit changes reference; the next rate and actual flux respond autonomously.
 assert c[0][65]!=oldc[0][65] and z[1][9]!=oldz[1][9] and c[1][51]!=oldc[1][51]
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 assert sha(d/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
 events.extend(selected)
 results.append(dict(optimization=opt,seconds=run['seconds'],commits=len(b),head_attempts=len(a),refusals=0,reduced_commits=0,Newton_iterations=int(sum(x[7] for x in a)),iteration_range=[min(x[7] for x in a),max(x[7] for x in a)],end_t1900=b[-1][0],same90_attempt_range=[36,125],same90_initial_sorptivity_and_clock_exact_parent=True,theoretical_delta_sum=math.fsum(x['implemented_delta'] for x in selected),stored_delta_sum=math.fsum(x['stored_delta'] for x in selected),reference_selected_start=selected[0]['reference_before'],reference_selected_end=selected[-1]['reference_after'],active_sorptivity_range=[min(x['active_sorptivity'] for x in selected),max(x['active_sorptivity'] for x in selected)],isolated_reference_feedback_activeSP_increase_range=[min(x['active_sorptivity']-x['active_sorptivity_with_parent_reference_same_candidate_theta'] for x in selected),max(x['active_sorptivity']-x['active_sorptivity_with_parent_reference_same_candidate_theta'] for x in selected)],maximum_accepted_residual=max(x[18] for x in a),maximum_absolute_sum_residual=max(abs(x[17]) for x in a),max_step_inventory_error_cm=max(abs(x[9]) for x in iv),max_step_inventory_limit_fraction=max(abs(x[9])/(x[3]*1e-5) for x in iv),segment_stock_change_cm=stock,segment_external_cm=external,segment_inventory_error_cm=error,segment_inherited_residual_envelope_cm=limit,postreset_ledger_increment_errors_cm=inc,main_cell_updates=len(t),complete_cell_drying_reset128_preserved=True,step129_no_sorption_zero_clock=True,first_reference_difference_commit=1,first_rate_flux_difference_attempt=2))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
with (R/'SAME90_FEEDBACK_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=list(events[0]));w.writeheader();w.writerows(events)
q=dict(work_unit='SWAP431-MACRO-B1-FEEDBACK48',decision='PASS_MINIMAL_CONTACT47_REFERENCE_FEEDBACK_SAME90_O0_O2_BOUNDED',source_checkpoint='4bf3e9c12',model_routes=2,hard_timeout_seconds=20,O0_O2_non_timing_byte_exact=True,clock_and_physical_flux_laws_solver_guards_budget_rules_unchanged=True,reference_update_implemented=True,own_feedback_from_original_checkpoint=True,no_additional_provider_evaluations_or_probes=True,real_refusal_rollback_new_restart_not_tested=True,full_period_BAL_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
