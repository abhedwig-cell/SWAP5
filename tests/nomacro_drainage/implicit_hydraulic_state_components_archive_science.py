"""Recompute mathematical derivative evidence from the original raw components."""
import json
from contextlib import ExitStack
from decimal import Decimal,localcontext
from implicit_hydraulic_state_local_archive_science import Original

def components(data):
 with ExitStack() as stack:
  store=Original(data,'IMPLICIT_HYDRAULIC_STATE11_MODEL5_CAUSAL_RAW_V1',stack);results=[]
  for opt,folder in [('O0','implicit-model5-ih11-derivative-math-v1'),('O2','implicit-model5-ih11-derivative-math-O2-v1')]:
   prefix='diagnostics/'+folder+'/';report=json.loads(store.get(prefix+'RESULT.json'));assert report['status']=='ACTUAL_MODEL5_CHAIN_RULE_MATCHES_INDEPENDENT_PRECISION80_ORIGINAL_EQUATION_PHYSICAL_FUNCTION_BYTES_AND_VALUES_UNCHANGED' and report['model_days']==0
   variants={}
   for variant in ['preceding','exact']:
    raw=store.get(prefix+variant+'.stdout');rows=[list(map(float,line.split()[4:])) for line in raw.decode().splitlines() if line.startswith('ACTUAL_BRANCH_QUERY ')];coefs=[line.split()[1:] for line in raw.decode().splitlines() if line.startswith('ACTUAL_MODEL5_COEFFICIENTS ')];assert len(rows)==len(coefs)==14;variants[variant]=(rows,coefs)
   observed=[]
   with localcontext() as ctx:
    ctx.prec=80
    for before,after,left_coefs,right_coefs in zip(*[variants['preceding'][0],variants['exact'][0],variants['preceding'][1],variants['exact'][1]]):
     assert before[:4]==after[:4] and before[5:]==after[5:] and left_coefs==right_coefs
     c=list(map(Decimal,right_coefs));ks,alpha,ll,nn,mm,h0=c[2],c[3],c[4],c[5],c[6],c[17];head=Decimal(str(after[0]))
     def power(x,p):return (p*x.ln()).exp()
     def original_k(h):
      if h>=0:return ks
      gamma=power(1+power(abs(alpha*h),nn),-mm);gamma0=power(1+power(abs(alpha*h0),nn),-mm);sc=(gamma-gamma0)/(1-gamma0);u=(1-power(gamma,1/mm))/(1-power(gamma0,1/mm));a=1-power(u,mm);return ks*power(sc,ll)*a*a
     if head<0:
      delta=abs(head)*Decimal('1e-8');independent=(original_k(head+delta)-original_k(head-delta))/(2*delta);error=abs(Decimal(str(after[4]))-independent)/abs(independent);assert error<Decimal('1e-10')
     else:independent=error=Decimal(0);assert after[4]==0
     observed.append(dict(head=str(head),actual_derivative=after[4],independent_original_equation_precision80_derivative=str(independent),relative_error=str(error),water_capacity_K_and_stencil_values_bit_identical=True))
   results.append(dict(optimization=opt,actual_component_source=report['actual_controller_source'],queries=observed))
  for opt,folder in [('O0','implicit-model5-ih11-exact-derivative-component-day1-v1'),('O2','implicit-model5-ih11-exact-derivative-component-day1-O2-v1')]:
   q=json.loads(store.get('diagnostics/'+folder+'/RESULT.json'));assert q['status']=='OBSERVATIONAL_COMPONENT_DAY1_ACCEPTED_NOT_ORIGINAL_SCIENCE_ADMISSION' and q['observed_day1']['committed'] and q['primary_prefix_and_full_periods_replayed']==0
  return dict(status='INDEPENDENT_ORIGINAL_MODEL5_PRECISION80_EQUATION_DERIVATIVE_RAW_COMPONENTS_PASS_UNCHANGED_PHYSICAL_FUNCTION_VALUES',archive_sha256=store.record['sha256'],observations=results,mathematical_queries=28,actual_historical_component_days_not_counted_again=2,new_model_executions=0,compiler_executions=0)
