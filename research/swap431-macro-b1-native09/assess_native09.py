"""Assess final native own-file routes and preserved boundaries; launches no model."""
from pathlib import Path
import hashlib,json,math,sys
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-retry07'
def fields(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
# Reuse the sealed independent primitive-inventory assessment, without running
# the earlier work unit's model-specific top-level assessment or rewriting it.
prior=(P/'assess_retry07.py').read_text();part=prior[prior.index('def inventory('):prior.index('\nresults=[]')]
ns=dict(math=math,eps=sys.float_info.epsilon);exec(compile(part,str(P/'assess_retry07.py'),'exec'),ns);inventory=ns['inventory']
results=[]
for opt in ['O2','O0']:
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
 t=R/'data'/opt/'B_TRIAL';r=R/'data'/opt/'B_RESTART';old=P/'data'/opt/'B_TRIAL'
 f=lambda d,n:fields(d/(n+'.txt'))
 assert (t/'outcome.txt').read_text().strip()=='REAL_REJECT_SMALL_RETRY_AND_CONTINUED'
 assert (r/'outcome.txt').read_text().strip()=='NATIVE_RESTART_ONE_STEP_EXECUTED'
 # All inherited ordinary rates/states and actual rejection are preserved.
 for n in ['origin','begin_1','returned_1','rollback_1','begin_2','returned_2','accepted_solver_return','checkpoint','continuous_next_begin','continuous_next_return','continuous_after_step','solver_1','solver_2','solver_3']:
  assert (t/(n+'.txt')).read_bytes()==(old/(n+'.txt')).read_bytes(),(opt,n)
 assert f(t,'solver_1')['outcome']==[4,31,1]
 assert f(t,'solver_2')['outcome']==[0,7,1]
 # Writer is read-only for all old and expanded persisted fields.
 for a,b in [('checkpoint','checkpoint_after_io'),('extended_checkpoint','extended_checkpoint_after_io')]:
  assert (t/(a+'.txt')).read_bytes()==(t/(b+'.txt')).read_bytes()
 for a,b in [('extended_checkpoint','native_installed'),('extended_continuous_next_begin','extended_restart_initialized'),('solver_3','solver_1'),('continuous_after_step','restart_after_step'),('extended_continuous_after_step','extended_restart_after_step')]:
  assert (t/(a+'.txt')).read_bytes()==(r/(b+'.txt')).read_bytes(),(opt,a,b)
 assert (t/'candidate.end').read_bytes()==(r/'own.end').read_bytes()
 begin=f(t,'continuous_next_begin');resbegin=f(r,'restart_initialized')
 different=[k for k in begin if begin[k]!=resbegin[k]]
 assert set(different)=={'macro_exchange','macro_rapid','matrix_exchange','matrix_vertical','boundary_rates','event'}
 # The new physical forcing and drainage/root rates agree before headcalc;
 # preceding-step top/bottom flux and evaporation estimates are recomputed
 # by real boundtop/vector_F, not restored as persistent state.
 for k in ['matrix_root','matrix_drains','matrix_ssdi','matrix_immob']:
  assert begin[k]==resbegin[k]
 assert begin['boundary_rates'][2:7]==resbegin['boundary_rates'][2:7]
 s=f(r,'solver_1');a=f(t,'checkpoint');end=f(r,'restart_after_step')
 assert a['controls'][0]==resbegin['controls'][0] and s['controls'][1]==1e-5
 assert max(a['clock'])==max(resbegin['clock']) and max(a['clock'])>.02
 first=inventory(f(t,'begin_2'),a,f(t,'accepted_solver_return'),f(t,'solver_2'))
 nextstep=inventory(begin,f(t,'continuous_after_step'),f(t,'continuous_next_return'),f(t,'solver_3'))
 restarted=inventory(resbegin,end,f(r,'restart_solver_return'),s)
 assert nextstep==restarted
 results.append(dict(optimization=opt,original_B_and_true_rejection_preserved_byte_exact=True,
  retry_iterations=7,checkpoint_time=a['controls'][0],next_dt=s['controls'][1],end_time=end['controls'][0],
  native_file_bytes=(t/'candidate.end').stat().st_size,own_file_sha256=hashlib.sha256((r/'own.end').read_bytes()).hexdigest(),
  committed_payload_exact_on_install=True,extended_pre_head_context_exact=True,solver_and_full_physical_step_byte_exact=True,
  clocks_restored_max_days=max(resbegin['clock']),pre_head_recomputed_previous_rates_and_flags=different,
  accepted_retry_inventory=first,continuous_step_inventory=nextstep,restarted_step_inventory=restarted))
for profile in ['B_TRIAL','B_RESTART']:
 for p in (R/'data/O2'/profile).glob('*.txt'):
  assert p.read_bytes()==(R/'data/O0'/profile/p.name).read_bytes(),str(p)
 for n in ['candidate.end','own.end']:
  p=R/'data/O2'/profile/n
  if p.exists():assert p.read_bytes()==(R/'data/O0'/profile/n).read_bytes()
negative=[]
for label,reason in [('MISSING','missing trailer'),('VERSION','version or identity mismatch'),('IDENTITY','version or identity mismatch'),('DIMENSION','dimensions mismatch'),('NONFINITE','nonfinite WaSrMpDm'),('INVENTORY','invalid inventory/history'),('TRUNCATED','incomplete trailer')]:
 q=json.loads((R/('O2_B_RESTART_'+label+'_RUN.json')).read_text());d=R/'data/O2'/('B_RESTART_'+label)
 assert q['returncode']!=0 and not q['censored'] and q['seconds']<20 and 'NATIVE09 '+reason in q['stderr']
 assert not (d/'native_installed.txt').exists() and not (d/'solver_1.txt').exists()
 negative.append(dict(label=label,reason=reason,returncode=q['returncode'],before_install_and_head=True,seconds=q['seconds']))
runs=[json.loads(p.read_text()) for p in R.glob('*_RUN.json')]
assert len(runs)==11 and all(not q['censored'] and q['seconds']<20 for q in runs)
for opt in ['O0','O2']:
 for mode in ['TRIAL','RESTART']:assert json.loads((R/(opt+'_B_'+mode+'_RUN.json')).read_text())['returncode']==0
report=dict(work_unit='SWAP431-MACRO-B1-NATIVE09',baseline='cd2bf853efeae56775a2e917f2f60701697ba34c',
 decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',native_own_restart='PASS_ORIGINAL_B_ACCEPTED_SUBDAY_ONE_STEP_O0_O2',
 original_rejection_rollback_retry='PASS_PRESERVED_30_ITER_REJECT_7_ITER_ACCEPT',
 own_file_exact_install=True,pre_head_extended_context_exact=True,equal_dt_end_time=True,full_physical_next_step_exact=True,O0_O2_byte_exact=True,
 independent_inventory='PASS_PRIMITIVE_MATRIX_MACRO_SURFACE_PAIRED_EXCHANGE',negative_file_guards=negative,
 final_routes=11,final_positive_routes=4,final_negative_initializations=7,preliminary_routes=15,preliminary_source_postimages=3,
 max_final_model_seconds=max(q['seconds'] for q in runs),total_final_model_seconds=sum(q['seconds'] for q in runs),model_cap_seconds=20,model_censored=0,
 results=results,additional_physics_or_solver_change=False,official_reference_promoted=False,production_changed=False,
 qualification_identity='Same ABI native binary and case-bound build fingerprint; launcher verifies all inherited bounded case hashes before documented SWINCO3/INIFIL edits. No arbitrary input-drift or cross-toolchain compatibility claim.',
 inherited_warning='Unchanged original readswap warns macro I/O is unsupported; that message describes the old native format. Only this research extension and versioned trailer are qualified here.',
 exclusions=['Only the exact original B accepted unscaled subday boundary and one next step',
 'No KWT/reduced/hysteresis/frost/other options, full day crossing or full trajectory qualification',
 'No exact cumulative/PEARL/output-ledger continuity; MacroIntegral local shadow history unchanged',
 'No generic input changes, foreign ABI, standard-format backward promotion or B1.12/canonical/release admission',
 'Dry/event and h0 handoff remain unqualified'],
 next_safe_step='Retain narrow physical own-restart qualification. Only select another original transition for a concrete dry/event/h0 or output-continuity question; do not broaden into a campaign or promote automatically.')
save(R/'RESULT.json',report)
print(json.dumps({k:v for k,v in report.items() if k not in ['results','negative_file_guards']},indent=2))
