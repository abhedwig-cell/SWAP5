"""Read-only bounded own repaired-trajectory qualification, including explicit history-policy scope."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-repair43';W=Path('C:/Users/Veldh012/swap431-trajectory44-work/native')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p in P.glob('*.f90'):
 if p.name not in ['macropore_native.f90','soilwater_native.f90']:assert p.read_bytes()==(R/p.name).read_bytes()
s=(R/'macropore_native.f90').read_text();old=(P/'macropore_native.f90').read_text()
s=s.replace('use DIAG19,only:repair43,attempts','use DIAG19,only:repair43',1).replace('use variables,     only: dt,h,t1900','use variables,     only: dt,h',1)
s=s.replace('      real(8)::old_time44,old_ref44,old_sorp44,awl_before44\n      integer,save::history_unit44\n      logical,save::history_open44=.false.\n','',1)
s=s.replace('               old_time44=TimAbsCumDmCp(id,ic);old_ref44=ThtSrpRefDmCp(id,ic)\n               old_sorp44=SorpDmCp(id,ic);awl_before44=AwlCorFac(ic)\n','',1)
i=s.index('               if(repair43.and.swmbf==1.and.ic==ICpTpSatZon) then\n                  if(.not.history_open44) then');e=s.index('               end if\n            end do',i)+len('               end if\n');s=s[:i]+s[e:];assert s==old
src=(R/'soilwater_native.f90').read_text();driver=src[src.index('logical function retry07_driver'):src.index('subroutine retry07_checkpoint')]
assert driver.index('repair43=.true.')<driver.index('call headcalc') and 'contract43_calibrate' not in driver and 'target_attempt' not in driver
result=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';pd=P/'data'/opt/'TRAJ_FINAL';a=rows(d/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac37_trace.txt');j24=rows(d/'jac24_trace.txt');hist=rows(d/'history44_trace.txt')
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert 'BOUNDED_CONTACT_REPAIRED_TRAJECTORY' in (d/'outcome.txt').read_text()
 assert len(a)==len(b)==len(iv)==360 and len(j)==2262 and len(j24)==2001
 assert all(x[0]==x[1]==n and x[4:7]==[0,0,1] and x[8:17]==[0]*9 and x[25]==1 and x[18]<=1e-6 and abs(x[17])<=1e-5 for n,x in enumerate(a,1))
 active=collections.Counter(int(x[0]) for x in j if x[2]==1);legacy=collections.Counter(int(x[0]) for x in j24 if x[2]==1)
 assert sum(active.values())==261 and sum(legacy.values())==226 and len(active)==66 and len(legacy)==90
 assert all(x[16]==1 for x in j) and all(x[27]<1e-12 and abs(x[24])>1e-12 for x in j if x[2]==1)
 for n,(x,v,w) in enumerate(zip(a,b,iv),1):
  assert w[:2]==[n,n] and w[2]==v[0] and w[3]==v[1]==x[3] and x[6]==v[16]==w[11]==1
  assert abs(v[0]-x[2]-v[1])<5e-12 and w[12]==active[n]+legacy[n]
  ext=v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  assert w[8]==ext and abs(math.fsum(w[4:8])-ext-w[9])<=8*math.ulp(max(abs(y) for y in w[4:9]))
  assert abs(w[9])<v[1]*1e-5 and abs(w[9]-w[10])<1e-15 and abs(w[10]-v[1]*x[17])<1e-18
  assert max(abs(y) for y in w[13:])<1e-13
 ini=f(d/'initial.txt');fin=f(d/'final.txt');ci=f(d/'context_initial.txt');cf=f(d/'context_final.txt')
 assert ini['controls'][0]==35797 and fin['controls'][0]==b[-1][0]==35797.491000009170
 assert b[-2][0]<35797.490<=b[-1][0] and b[-1][0]>35797.487000006880 and b[-1][1]==fin['controls'][1]==.002
 assert ini['fraction']==fin['fraction'] and ini['dz']==fin['dz']
 for name in ['initial','context_initial','ledger_initial','begin','context_begin','ledger_begin']:assert (d/(name+'.txt')).read_bytes()==(pd/(name+'.txt')).read_bytes(),name
 oa=rows(pd/'attempt_trace.txt');ob=rows(pd/'step_budget.txt');assert a[0][:-1]!=oa[0][:-1] and b[0]!=ob[0] # Own new trajectory from first accepted head, no grafted prefix.
 stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(ini['theta'],fin['theta'],ini['dz'],ini['fraction']))+math.fsum(y-x for x,y in zip(ini['macro_domain'],fin['macro_domain']))+fin['pond'][0]-ini['pond'][0]+cf['sicact'][0]-ci['sicact'][0]
 external=math.fsum(x[8] for x in iv);error=stock-external;limit=math.fsum(x[3]*1e-5 for x in iv)
 assert abs(error)<limit and abs(error-math.fsum(x[9] for x in iv))<1e-14 and abs(error-math.fsum(x[10] for x in iv))<1e-14
 L0=f(d/'ledger_begin.txt');L1=f(d/'ledger_final.txt');inc={}
 assert L0['sicini']==ci['sicact'] and L0['sicini'][0]>0 and L0['cgrai']==[0.]
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
  inc[key]=L1[key][0]-L0[key][0]-math.fsum(v[1]*v[col] for v in b);assert abs(inc[key])<1e-12
 domains=[]
 for k in range(5):
  de=fin['macro_domain'][k]-ini['macro_domain'][k]-math.fsum(v[1]*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0)) for v in b);assert abs(de)<1e-13;domains.append(de)
 assert len(hist)==154 and len(set(x[0] for x in hist))==137
 continued=[x for x in hist if x[13]==0];ended=[x for x in hist if x[13]==1];zero=[x for x in continued if x[12]==0]
 assert len(continued)==137 and len(ended)==17 and len(zero)==90 and all(x[3:5]==[3,50] for x in zero)
 ref_errors=[]
 for x in hist:
  att=int(x[0]);assert x[1]==a[att-1][2] and x[2]==a[att-1][3] and x[4]==x[5] and x[6]<0
  wet_top=min(x[8]+.5*x[9],x[10]);wet=max(0,wet_top-(x[8]-.5*x[9]));overlap=max(0,wet_top-max(x[8]-.5*x[9],x[7]));ratio=min(1,max(0,overlap/wet)) if wet>0 else 0
  assert abs(x[12]-ratio)<1e-14
  if x[13]==1:assert x[15]==x[17]==x[19]==0
  else:
   assert abs(x[15]-x[14]-x[2])<1e-15 and x[19]==x[18]
   delta=x[12]*x[20]*x[11]*x[21]*(4/x[22])*x[18]*(math.sqrt(x[14]+x[2])-math.sqrt(x[14]));er=abs(x[17]-x[16]-delta);assert er<1e-16;ref_errors.append(er)
   if x[12]==0:assert x[17]==x[16]
 assert not list(d.glob('*.bin')) and not (d/'frozen42_base.bin').exists() and not (d/'probe42_points.txt').exists() and not list(d.glob('*refus*'))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==h for name,h in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 assert sha(d/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
 result.append(dict(optimization=opt,seconds=run['seconds'],commits=360,head_attempts=360,refusals=0,reduced_commits=0,first_difference_from_old_trajectory_attempt=1,end_t1900=b[-1][0],original357_time_crossed=True,last_used_and_next_dt=.002,total_Newton_iterations=2262,iteration_range=[int(min(x[7] for x in a)),int(max(x[7] for x in a))],extra_line_search_trials=int(sum(x[24]-x[21] for x in a)),new_geometry_corrected_iterations=261,old_rank1_corrected_iterations=226,combined_corrected_Jacobian_iterations=487,maximum_accepted_residual=max(x[18] for x in a),maximum_absolute_sum_residual=max(abs(x[17]) for x in a),max_step_inventory_error_cm=max(abs(x[9]) for x in iv),max_step_inventory_limit_fraction=max(abs(x[9])/(x[3]*1e-5) for x in iv),segment_stock_change_cm=stock,segment_external_cm=external,segment_inventory_error_cm=error,segment_inherited_residual_envelope_cm=limit,segment_domain_errors_cm=domains,postreset_ledger_increment_errors_cm=inc,history_records=154,history_contact_cells=dict(collections.Counter(int(x[4]) for x in hist)),continuing_history_records=137,ended_history_records=17,history_rule_ref_increment_max_error=max(ref_errors),zero_END_contact_continuing_events=90,zero_END_contact_policy='Native potential-sorption event flag continues elapsedclock while ENDgeometry factor0 leaves referenceincrement0; observed implementation fidelity, physical contact-loss event semantics not independently qualified'))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
q=dict(work_unit='SWAP431-MACRO-B1-TRAJECTORY44',decision='PASS_SHORT_OWN_REPAIRED_TRAJECTORY_BEYOND_ORIGINAL357_WITH_HISTORY_POLICY_LIMIT_O0_O2',source_checkpoint='d336ecfc0',model_routes=2,all_uncensored=True,external_hard_seconds=20,O0_O2_non_timing_byte_exact=True,continuous_contact_repair_from_first_head=True,no_frozen_probes_or_calibration_used=True,repair43_physical_and_numerical_rules_unchanged=True,history_native_rule_fidelity_qualified=True,physical_event_semantics_at_zero_END_contact_independently_qualified=False,no_full_period_new_restart_or_general_admission=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
