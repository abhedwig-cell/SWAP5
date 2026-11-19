"""Read-only native roundtrip and matched bounded next-step refusal audit."""
from pathlib import Path
import json,math,hashlib,re,struct
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-georestore54';W=Path('C:/Users/Veldh012/swap431-native55-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def f(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def packet(p):
 b=p.read_bytes();at=0;records=[]
 while at<len(b):
  n=struct.unpack_from('<i',b,at)[0];assert n>=0 and at+n+8<=len(b)
  x=b[at+4:at+4+n];assert struct.unpack_from('<i',b,at+4+n)[0]==n;records.append(x);at+=n+8
 h=[x for x in records if x.startswith(b'SWAP431_MACRO_RESTART_V6')];assert len(h)==1 and len(h[0])==112
 version,n,nd=struct.unpack_from('<iii',h[0],32);phase=struct.unpack_from('<i',h[0],108)[0]
 assert [version,n,nd,phase]==[6,112,5,1] and records[-1].rstrip()==b'NATIVE09_COMPLETE'
 assert h[0][44:108].decode()=='5524115f66b68d26b40f42f25a1624c8da5d33cf435158ba1634ba8cbdec19f5'
 return dict(sha256=sha(p),bytes=len(b),records=len(records),version=version,phase=phase,numnod=n,NumDm=nd)
patch=(R/'NATIVE_HARNESS.patch').read_text()
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if '+++ NATIVE55/'+p.name+'\n' in patch:
  section=patch.split('+++ NATIVE55/'+p.name+'\n',1)[1].split('--- GEORESTORE54/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+']);assert s.count(new)==1;s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
results=[];runs=[]
for opt in ['O0','O2']:
 c=R/'data'/opt/'CONT_D2';d=R/'data'/opt/'RESTART_D2';old=P/'data'/opt/'TRIAL_D2'
 ca=rows(c/'attempt_trace.txt');ra=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt')
 assert len(ca)==6 and len(ra)==2 and [x[:-1] for x in ca[:4]]==[x[:-1] for x in oa]
 assert [x[2:-1] for x in ca[4:]]==[x[2:-1] for x in ra]
 assert ra[0][3]==2.0951312035156963e-5 and ra[0][7]==31 and ra[0][9]==1 and ra[0][5]==0
 assert ra[1][3]==1e-5 and ra[1][7]==61 and ra[1][5]==1 and ra[1][10]==1 and ra[1][25]==0
 for n,previous in [('checkpoint','committed'),('context_checkpoint','context_committed'),('ledger_checkpoint','ledger_committed')]:
  assert (c/(n+'.txt')).read_bytes()==(old/(previous+'.txt')).read_bytes()
 for a,b in [('checkpoint','checkpoint_after_io'),('context_checkpoint','context_checkpoint_after_io'),('ledger_checkpoint','ledger_checkpoint_after_io')]:assert (c/(a+'.txt')).read_bytes()==(c/(b+'.txt')).read_bytes()
 assert (c/'context_checkpoint.txt').read_bytes()==(d/'native_installed.txt').read_bytes()==(d/'context_initial.txt').read_bytes()
 assert (c/'ledger_checkpoint.txt').read_bytes()==(d/'ledger_installed.txt').read_bytes()==(d/'ledger_initial.txt').read_bytes()
 for i in [1,2]:
  for name in ['context_follow_begin_','context_follow_returned_','ledger_follow_begin_','ledger_follow_returned_','origin_follow_begin_']:
   assert (c/(name+str(i)+'.txt')).read_bytes()==(d/(name+str(i)+'.txt')).read_bytes(),name
  assert (c/('solver_'+str(i+4)+'.txt')).read_bytes()==(d/('solver_'+str(i)+'.txt')).read_bytes()
  for dd in [c,d]:
   origin=f(dd/('origin_follow_begin_'+str(i)+'.txt'));state=f(dd/('context_follow_begin_'+str(i)+'.txt'))
   assert origin['stamp']==[state['t1900'][0],112,5,1]
   for x,y in [('reference','thtsrprefdmcp'),('sorptivity','sorpdmcp'),('dynamic','vlmpdycp'),('subsidence','subsidcp')]:assert origin[x]==state[y]
   assert rows(dd/('cache_follow_begin_'+str(i)+'.txt'))[0][:3]==[0,0,0]
  # Initial output work fields differ; actual current forcing components match.
  x=f(c/('follow_begin_'+str(i)+'.txt'));y=f(d/('follow_begin_'+str(i)+'.txt'))
  if i==1:
   assert {k for k in x if x[k]!=y[k]}=={'macro_in_vert','macro_exchange','macro_rapid','matrix_exchange','matrix_vertical','boundary_rates','event'}
   assert [j for j,(a,b) in enumerate(zip(x['boundary_rates'],y['boundary_rates'])) if a!=b]==[0,7]
  x=f(c/('follow_returned_'+str(i)+'.txt'));y=f(d/('follow_returned_'+str(i)+'.txt'));assert {k for k in x if x[k]!=y[k]}=={'matrix_vertical'}
 cp=rows(c/'provider49_trace.txt');rp=rows(d/'provider49_trace.txt');assert [x[1:] for x in cp if x[0]>=5]==[x[1:] for x in rp]
 cg=rows(c/'geometry53_trace.txt');rg=rows(d/'geometry53_trace.txt');assert [x[1:] for x in cg if x[0]>=5]==[x[1:] for x in rg]
 assert (c/'context_final.txt').read_bytes()==(d/'context_final.txt').read_bytes()
 checkpoint=f(c/'context_checkpoint.txt');end=f(c/'context_final.txt');assert {k for k in checkpoint if checkpoint[k]!=end[k]}=={'dt','dtold'}
 assert (c/'ledger_checkpoint.txt').read_bytes()==(c/'ledger_final.txt').read_bytes()==(d/'ledger_final.txt').read_bytes()
 assert len(rows(c/'step_budget.txt'))==1 and len(rows(d/'step_budget.txt'))==0
 iv=rows(c/'inventory_trace.txt');assert len(iv)==1 and abs(iv[0][9])<iv[0][3]*1e-5
 for dd in [c,d]:
  assert 'NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED' in (dd/'outcome.txt').read_text() and not (dd/'follow.end').exists()
  assert f(dd/'final.txt')['controls'][0]==checkpoint['t1900'][0]
 info=packet(c/'candidate.end');inp=json.loads((R/(opt+'_RESTART_D2_INPUT.json')).read_text());assert inp['own_end_sha256']==info['sha256']==sha(d/'own.end')
 assert sha(c/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 results.append(dict(optimization=opt,checkpoint_t1900=checkpoint['t1900'][0],checkpoint_next_dt=checkpoint['dt'][0],own_native_packet=info,checkpoint_write_no_state_or_ledger_change=True,installed_native_context_and_ledger_byte_exact=True,both_first_follow_origin_buffers_rebuilt_exact=True,all_follow_solver_provider_geometry_suffix_exact_after_attempt_index=True,follow_first_unscaled_refusal=dict(dt=ra[0][3],max_residual=ra[0][18],sum_residual=ra[0][17],node=int(ra[0][19]),iterations=30),follow_dtmin_scale_request=dict(dt=ra[1][3],max_residual=ra[1][18],sum_residual=ra[1][17],node=int(ra[1][19]),iterations=60,requested_IDecMpRat=1,FrReduQ=ra[1][6]),follow_accepted_commits=0,no_time_advance_or_ledger_commit_for_failed_follow=True,checkpoint_inventory_error_cm=iv[0][9],checkpoint_inventory_limit_cm=iv[0][3]*1e-5,initial_nonpersistent_work_field_differences=['macro_in_vert','macro_exchange','macro_rapid','matrix_exchange','matrix_vertical','boundary_rates_qtop_reva','event'],after_actual_solver_only_matrix_vertical_work_differs=True))
 for mode in ['CONT','RESTART']:
  q=json.loads((R/(opt+'_'+mode+'_D2_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20
  runs.append(dict(optimization=opt,mode=mode,seconds=q['seconds'],terminal='SCALED_REQUEST_EXCLUDED_NO_FOLLOW_COMMIT'))
for mode in ['CONT','RESTART']:
 d0=R/'data/O0'/(mode+'_D2');d2=R/'data/O2'/(mode+'_D2')
 for p in d0.glob('*.txt'):
  if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(d2/p.name).read_bytes(),(mode,p.name)
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
assert (R/'data/O0/CONT_D2/candidate.end').read_bytes()==(R/'data/O2/CONT_D2/candidate.end').read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-NATIVE55',decision='PARTIAL_OWN_NATIVE_V6_SUBDAY_TRANSFER_AND_MATCHED_FOLLOW_REFUSAL_O0_O2_PASS_FULL_ACCEPTED_FOLLOW_BLOCKED_DTMIN_SCALE_REQUEST',baseline='1b6e02b9fc8101ebcb06e2ed360dcd8e56ca446c',source_checkpoint='9d05ab908',model_routes=4,hard_seconds_per_route=20,no_physics_solver_clock_dt_reduction_or_budget_rule_changes=True,bounded_native_V6_phase1_variant_added=True,old_V5_completed_day_and_coverage_guards_retained=True,new_persistent_physical_state_fields=False,own_file_fresh_process_install_origin_buffers_and_solver_attempts_exact=True,O0_O2_non_timing_byte_exact=True,full_simultaneous_accepted_followstep_qualified=False,reason='Both continuous and fresh native restart request flux reduction on dtmin; same bounds exclude it. No follow hostcommit/timeadvance/ledgerintegration.',new_follow_waterbalance_or_fullperiod_daycrossing_general_restart_admission=False,no_broad_campaign=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results,runs=runs)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
