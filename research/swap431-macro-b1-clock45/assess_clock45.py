"""Read-only adjudication of the same90zero-END-overlap clocks; no numerical intervention."""
from pathlib import Path
import json,math,hashlib,csv
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-trajectory44';W=Path('C:/Users/Veldh012/swap431-clock45-work/native')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cf(g,m,z,dz):
 top=min(z+dz/2,m);wet=max(0,top-(z-dz/2));return min(1,max(0,(top-max(z-dz/2,g))/wet)) if wet>0 else 0
for p in P.glob('*.f90'):
 if p.name not in ['diag_state.f90','soilwater_native.f90','macrorate_node.f90','macropore_native.f90']:assert p.read_bytes()==(R/p.name).read_bytes()
assert (R/'diag_state.f90').read_text().replace('real(8),save::start45(12)=0d0\n','',1)==(P/'diag_state.f90').read_text()
s=(R/'macrorate_node.f90').read_text().replace('      real(8)::get45_meta(24),get45_pot(2),get45_stamp(7)\n','',1).replace('      logical::get45_is_sorption\n','',1)
i=s.index('      entry clock45_rate_get(');e=s.index('      entry jac37_invalidate()',i);s=s[:i]+s[e:]
i=s.index('      entry clock45_abs_get(');e=s.index('      entry sense23_abs_io(',i);s=s[:i]+s[e:];assert s==(P/'macrorate_node.f90').read_text()
s=(R/'macropore_native.f90').read_text().replace('use DIAG19,only:repair43,attempts,start45','use DIAG19,only:repair43,attempts',1)
s=s.replace('      real(8)::meta45(24),pot45(2),stamp45(7),rate_geo45(3),rate_q45(4),pre_hist45(3),end_cf45,top45,span45\n      logical::chosen_sorp45,rate_end45\n      integer,save::clock_unit45\n      logical,save::clock_open45=.false.\n','',1)
i=s.index('! Observation before the native owner changes waterlevel/geometry/history.');e=s.index('!  -- Update water storage in entire macropore domains',i);s=s[:i]+s[e:]
i=s.index('! Buffered receipt for the same D3/node50 across all original accepted steps.');e=s.index('! --- Update factor for correcting vertical area wall for sorptivity calculations',i);s=s[:i]+s[e:];assert s==(P/'macropore_native.f90').read_text()
s=(R/'soilwater_native.f90').read_text().replace('active_in_attempt,apply37,repair43,start45','active_in_attempt,apply37,repair43',1).replace('use variables,only:t1900,dt,fldecdt,gwl,h,theta','use variables,only:t1900,dt,fldecdt',1).replace('use MOD_swap_mp,only:IDecMpRat,FlDecMpRat,GwlFlCpZo','use MOD_swap_mp,only:IDecMpRat,FlDecMpRat',1).replace('use MOD_macropore,only:MacroStateVar,ZWaLevDm,WaSrMpDm,FrMpWalWet,TimAbsCumDmCp,ThtSrpRefDmCp,SorpDmCp,QOutMtxUnsDmCp,FlEndSrpEvt','use MOD_macropore,only:MacroStateVar',1)
i=s.index(' start45=[gwl,');e=s.index(' call capture33()',i);s=s[:i]+s[e:];assert s==(P/'soilwater_native.f90').read_text()
result=[];events=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';old=P/'data'/opt/'TRAJ';a=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt');b=rows(d/'step_budget.txt');h=rows(d/'history44_trace.txt');cl=rows(d/'clock45_trace.txt')
 assert len(a)==len(b)==len(cl)==360 and all(len(x)==72 for x in cl)
 assert [x[:-1] for x in a]==[x[:-1] for x in oa]
 for p in old.glob('*.txt'):
  if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(d/p.name).read_bytes(),p.name
 assert all(x[41]==x[1] and x[42]==x[2] and x[43]==1 and x[44]==x[0] and x[45]==a[int(x[0])-1][7] and x[46:48]==[1,1] for x in cl)
 assert all(x[8]==prev[64] and x[5]==prev[58] for prev,x in zip(cl,cl[1:]))
 ids={int(x[0]) for x in h if x[12]==0 and x[13]==0};assert ids==set(range(36,126))
 selected=[x for x in cl if int(x[0]) in ids];assert len(selected)==90
 for x in selected:
  assert x[55:57]==[1,0] and x[39]/x[2]>1e-7 and x[51]>1e-7 and 0<x[30]<1
  assert x[51]==x[30]*x[39]/x[2] and x[52:55]==[0,0,0]
  assert x[60]==0 and x[59]>0 and x[58]==x[71]==x[33] and abs(x[57]-x[16])<1e-16
  assert -66<x[58]<-64 and x[68]<0 and x[67]==50
  assert cf(x[33],x[48],x[69],x[70])>0 and x[48]>x[33]
  assert abs(x[64]-x[61]-x[2])<1e-15 and x[65]==x[62] and x[66]==x[63]>0
  assert x[2]==.002 and x[61]==x[8]
  events.append(dict(optimization=opt,attempt=int(x[0]),time=x[1],dt=x[2],prehead_unsat_contact_factor=cf(x[3],x[5],x[69],x[70]),accepted_rate_unsat_contact_factor=cf(x[33],x[48],x[69],x[70]),END_unsat_contact_factor=x[60],END_macro_waterwet_fraction=x[59],potential_sorption_rate=x[39]/x[2],outflow_stock_factor=x[30],actual_sorption_rate=x[51],actual_sorption_amount=x[51]*x[2],rate_GWL=x[33],rate_macro_waterlevel=x[48],END_macro_waterlevel=x[58],event_time_before=x[61],event_time_after=x[64],reference_before=x[62],reference_after=x[65]))
 # Existing positive-END-contact continuation and real complete-drying controls; no new contexts.
 x126=cl[125];x128=cl[127];x129=cl[128]
 assert x126[59]>0 and x126[60]==1 and x126[64]>x126[61]>0
 assert x128[51]>0 and x128[59]==0 and x128[58]<-66 and x128[64:67]==[0,0,0]
 assert x129[51]==0 and x129[56]==1 and x129[64:67]==[0,0,0]
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==hh for name,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 result.append(dict(optimization=opt,seconds=run['seconds'],entire_trajectory44_numeric_outputs_byte_exact=True,same90attempts=[36,125],all90_actual_sorption_positive_and_gt_1e_minus7=True,actual_sorption_rate_range=[min(x[51] for x in selected),max(x[51] for x in selected)],potential_sorption_rate_range=[min(x[39]/x[2] for x in selected),max(x[39]/x[2] for x in selected)],outflow_factor_range=[min(x[30] for x in selected),max(x[30] for x in selected)],total_actual_sorption_amount_cm=math.fsum(x[51]*x[2] for x in selected),RATE_unsat_contact_factor_range=[min(cf(x[33],x[48],x[69],x[70]) for x in selected),max(cf(x[33],x[48],x[69],x[70]) for x in selected)],END_macro_waterwet_fraction_range=[min(x[59] for x in selected),max(x[59] for x in selected)],all90_END_waterstock_equals_minimum_within_cm=max(abs(x[57]-x[16]) for x in selected),elapsed_clock_increment_days=selected[-1][64]-selected[0][61],sum_used_dt_days=math.fsum(x[2] for x in selected),END_reference_increment_zero=True,step126_positive_unsat_contact_continues=True,step128_complete_macro_waterloss_resets_all_history=True,step129_no_sorption_and_clock_remains_zero=True,clock_rule_change_needed_for_these90=False))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
with (R/'SAME90_EVENTS.csv').open('w',newline='',encoding='utf-8') as fp:
 w=csv.DictWriter(fp,fieldnames=list(events[0]));w.writeheader();w.writerows(events)
q=dict(work_unit='SWAP431-MACRO-B1-CLOCK45',decision='PASS_CLOCK_CONTINUATION_JUSTIFIED_FOR_SAME90_CONTACT_EVENTS_O0_O2_NO_CHANGE',source_checkpoint='87e43fd47',model_routes=2,all_uncensored=True,hard_timeout_seconds=20,extra_provider_evaluations=0,O0_O2_non_timing_byte_exact=True,clock_limit_from_trajectory44_resolved_for_these90=True,adjudication='Elapsed age since first macropore-water contact ofcell, not ENDunsaturated-overlap integral. All90 have accepted actualsorption and continuing macropore-waterwetcell, although minimumstock leaves ENDwaterlevel=GWL. No automaticzero-overlap reset justified. Genuine completecellwaterloss resetsmemory at128.',no_clock_physics_solver_guard_dt_tolerance_MAXIT_reduction_change=True,END_geometric_reference_formula_physical_accuracy_separately_qualified=False,full_period_new_restart_or_general_event_clock_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
