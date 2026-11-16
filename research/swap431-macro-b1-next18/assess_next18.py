"""Read-only qualification of capped NEXT18 evidence; never launches a model."""
from pathlib import Path
import json, hashlib, struct
R=Path(__file__).resolve().parent
P=R.parent/'swap431-macro-b1-canopy17'
def fields(p):
 return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def rows(p):
 a=p.read_text().splitlines()
 return [s for s in a if len(s.split())==32]
out=[];streams=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'PREFIX';z=R/'data'/opt/'RESUME'
 first=rows(d/'step_budget.txt');resume=rows(z/'step_budget.txt')
 old=rows(P/'data'/opt/'PREFIX/step_budget.txt')
 assert first[:len(old)]==old and len(old)==1453
 after=[s for s in first if float(s.split()[0])>35797]
 n=min(len(after),len(resume));assert n>0 and after[:n]==resume[:n]
 a=fields(d/'begin.txt');b0=fields(z/'begin.txt')
 differences=[k for k in a if a[k]!=b0[k]]
 assert set(differences)=={'macro_exchange','macro_rapid','matrix_exchange','matrix_vertical','boundary_rates','event'}
 for name in ['context_begin','ledger_begin']:
  assert (d/(name+'.txt')).read_bytes()==(z/(name+'.txt')).read_bytes(),name
 assert (d/'context_period_initial.txt').read_bytes()==(z/'native_installed.txt').read_bytes()
 assert (d/'ledger_prior_period.txt').read_bytes()==(z/'ledger_installed.txt').read_bytes()
 assert (d/'midnight.end').read_bytes()==(z/'own.end').read_bytes()
 b=(d/'midnight.end').read_bytes();i=b.index(b'PATCH_FROM_BALANCE_ORIGIN')
 assert struct.unpack_from('<ddi',b,i-20)==(35795,35797,1)
 L=fields(d/'ledger_begin.txt');previous=fields(d/'context_period_initial.txt')
 assert L['sicini']==previous['sicact'] and L['sicini'][0]>0
 assert fields(d/'ledger_prior_period.txt')['sicini']==[0.]
 assert L['cgrai']==[0.] and L['caintc']==[0.]
 assert (d/'period_initial.txt').read_bytes()==(P/'data'/opt/'PREFIX/checkpoint.txt').read_bytes()
 for mode,a in [('PREFIX',first),('RESUME',resume)]:
  run=json.loads((R/(opt+'_'+mode+'_RUN.json')).read_text())
  assert run['censored'] and not (R/'data'/opt/mode/'period_final.txt').exists()
  x=[list(map(float,s.split())) for s in a]
  reduced=[v for v in x if v[16]<1]
  out.append(dict(optimization=opt,mode=mode,censored=True,timeout_seconds=20,observed_seconds=run['seconds'],complete_budget_rows=len(a),last_recorded_time=x[-1][0],minimum_flux_factor=min(v[16] for v in x),reduced_committed_rows=len(reduced),first_reduced_time=reduced[0][0] if reduced else None,BAL_bytes=(R/'data'/opt/mode/'result.bal').stat().st_size))
 streams.append(after)
 out.append(dict(optimization=opt,common_native_steps_byte_exact=n,original_first_period_rows_byte_exact=1453,native_install_exact=True,period_reset_exact=True,canopy_origin_cm=L['sicini'][0],pre_head_legacy_derived_dump_differences=differences))
n=min(map(len,streams));assert streams[0][:n]==streams[1][:n]
for name in ['begin','context_begin','ledger_begin','period_initial','context_period_initial','ledger_prior_period']:
 assert (R/'data/O0/PREFIX'/(name+'.txt')).read_bytes()==(R/'data/O2/PREFIX'/(name+'.txt')).read_bytes()
for p in R.glob('*.f90'):
 if p.name!='soilwater_native.f90':assert p.read_bytes()==(P/p.name).read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-NEXT18',decision='INCOMPLETE_CENSORED_NO_FULL_PERIOD_PASS',native_start_and_nonzero_period_reset='PASS_O0_O2',common_next_period_steps_O0_O2_byte_exact=n,checks=out,model_routes=4,timeout_seconds_per_route=20,physics_BAL_codec_changes=False,full_period_BAL_and_balance='NOT_QUALIFIED_NO_ENDPOINT',official_promotion=False)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
