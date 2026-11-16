"""Read-only sensitivity, chain rule and transaction restoration qualification."""
from pathlib import Path
import json,hashlib,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-fresh22'
def read(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME_IEEE';old=P/'data'/opt/'RESUME'
 for p in old.glob('*.txt'):
  if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
  assert p.read_bytes()==(d/p.name).read_bytes(),p.name
 a=read(d/'attempt_trace.txt');b=read(old/'attempt_trace.txt')
 assert [x[:-1] for x in a]==[x[:-1] for x in b] and len(a)==38
 assert (d/'swap.wrn').read_bytes()==(old/'swap.wrn').read_bytes()
 base=sha(d/'trial23_base.bin');restores=list(d.glob('trial23_restored_*.bin'))
 assert len(restores)==14 and all(sha(p)==base for p in restores)
 assert sha(d/'trial23_final.bin')==base
 fp=read(d/'probe_fp_status.txt');assert len(fp)==16 and all(x[1:]==fp[0][1:] for x in fp)
 lim=read(d/'probe_limit.txt');flux=read(d/'probe_flux.txt');assert len(lim)==len(flux)==14
 assert lim[0][1:]==lim[-1][1:] and flux[0][1:]==flux[-1][1:]
 assert all(len(x)==46 for x in lim)
 vals=[x[3:] for x in lim];v0=vals[0]
 assert all(0<x[23]<1 and x[39]==1 and x[40]==1 for x in vals)
 assert all(x[10]==50 and x[13]<x[12] and x[37]==0 and x[20]==1 for x in vals)
 assert all(x[16]==v0[16] for x in vals) # domain volume unchanged in these perturbations
 ctx={s.split()[0]:list(map(float,s.split()[1:])) for s in (d/'probe_context.txt').read_text().splitlines()}
 h50,h51,h52=ctx['h'];dist=ctx['disnod51'][0];rho=ctx['volume_density3_50'][0];dt=ctx['dt'][0]
 assert ctx['swkimpl']==[0] # original frozen matrix conductivity policy preserved
 analytic={50:dist*h51/(h51-h50)**2,51:-dist*h50/(h51-h50)**2,52:0.}
 deriv=[]
 for eps in [1e-4,5e-5]:
  for node in [50,51,52]:
   plus=next(x[3:] for x in lim if x[1]==node and x[2]==eps)
   minus=next(x[3:] for x in lim if x[1]==node and x[2]==-eps)
   pf=next(x for x in flux if x[1]==node and x[2]==eps)
   mf=next(x for x in flux if x[1]==node and x[2]==-eps)
   diff=lambda j:(plus[j]-minus[j])/(2*eps)
   dg,dL,dI,dO,do,df=map(diff,[9,13,17,18,30,23])
   assert abs(dg-analytic[node])<1e-8
   assert abs(dL-rho*dg)<1e-10
   E=v0[22];O=v0[18];f=v0[23];o=v0[30]
   chain_df=-(dL-dI+dO)/O+E*dO/O**2
   chain_dq=(f*do+o*chain_df)/dt
   dQ3=(pf[4]-mf[4])/(2*eps);dQ=(pf[3]-mf[3])/(2*eps)
   assert abs(df-chain_df)<1e-6 and abs(dQ3-chain_dq)<1e-8
   deriv.append(dict(node=node,epsilon_cm=eps,dGWL_dh=dg,analytic_dGWL_dh=analytic[node],dMinimumStock_dh=dL,dInPotential_dh=dI,dOutPotential_dh=dO,dNodeOutPotential_dh=do,dFactor_dh=df,chain_dFactor_dh=chain_df,dQ3node52_dh=dQ3,chain_dQ3node52_dh=chain_dq,dAggregateMacroQ52_dh=dQ,existing_macro_J52_50=ctx['existing_macro_J52_50'][0] if node==50 else None))
 for node in [50,51,52]:
  ds=[x for x in deriv if x['node']==node]
  assert abs(ds[0]['dAggregateMacroQ52_dh']-ds[1]['dAggregateMacroQ52_dh'])<1e-7
 assert abs(next(x['dAggregateMacroQ52_dh'] for x in deriv if x['node']==50))>.8
 # The initial repeat equals the actually evaluated original state (rates from the Jacobian call).
 original_limits=read(old/'domain3_limit.txt')
 original=next(x for x in original_limits if x[0]==38 and x[1]==30 and x[4]==2 and x[5]==3)
 assert vals[0][6:]==original[6:]
 for mode in ['RESUME_VERIFIED','RESUME_IEEE']:
  run=json.loads((R/(opt+'_'+mode+'_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert (d/'probe_limit.txt').read_bytes()==(R/'data'/opt/'RESUME_VERIFIED/probe_limit.txt').read_bytes()
 assert (d/'probe_flux.txt').read_bytes()==(R/'data'/opt/'RESUME_VERIFIED/probe_flux.txt').read_bytes()
 setup=json.loads((R/(opt+'_RESUME_RUN.json')).read_text());assert setup['returncode']==3 and not setup['censored'] and setup['seconds']<20
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==v for n,v in identity['sources'].items())
 results.append(dict(optimization=opt,seconds=json.loads((R/(opt+'_RESUME_IEEE_RUN.json')).read_text())['seconds'],probe_evaluations=14,snapshot_bytes=(d/'trial23_base.bin').stat().st_size,snapshot_sha256=base,all_14_restores_and_final_byte_exact=True,IEEE_status_at_probe_entry_restored_each_time=True,repeated_base_exact=True,original_numerical_continuation_exact=True,branch_preserved='PARTIAL_OUTFLOW_LIMIT_MINIMUM_IS_VOLUME_UNDER_GWL',derivatives=deriv))
for name in ['probe_limit.txt','probe_flux.txt','probe_context.txt','trial23_base.bin']:
 assert sha(R/'data/O0/RESUME_IEEE'/name)==sha(R/'data/O2/RESUME_IEEE'/name),name
q=dict(work_unit='SWAP431-MACRO-B1-SENSE23',decision='LOCAL_SENSITIVITY_AND_SCOPED_RESTORE_PASS_NONLOCAL_GWL_COUPLING_CONFIRMED',final_optimization_routes=2,model_process_invocations=6,setup_failures=2,pre_IEEE_positive_invocations=2,final_positive_invocations=2,hard_timeout_seconds_per_invocation=20,all_uncensored=True,physics_solver_policy_changes=False,probe_scope='MACRORATE at original current-operator attempt38 iteration30; not complete residual Jacobian',full_second_period_qualification=False,official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
print(json.dumps(dict(decision=q['decision'],results=[dict(optimization=x['optimization'],seconds=x['seconds'],restore_sha=x['snapshot_sha256'],derivatives=[d for d in x['derivatives'] if d['epsilon_cm']==5e-5]) for x in results]),indent=2))
