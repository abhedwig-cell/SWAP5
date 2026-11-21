"""Independently recompute measured water and conserved AGE amount/moment ledgers."""
import json
from decimal import Decimal,localcontext


def read(rows,initial):
 """Use measured cumulative states; never import a producer ledger/tolerance."""
 D=lambda value:Decimal.from_float(float(value))
 previous=tuple(map(D,initial));assert len(previous)==11 and all(value.is_finite() for value in previous)
 origin=previous;maximum_water=Decimal(0);maximum_daily=Decimal(0);maximum_prefix=Decimal(0);prefix_within=True;count=0
 with localcontext() as context:
  context.prec=100
  epsilon=Decimal(2)**-52;factor=Decimal(8192)*epsilon
  assert abs(previous[0]+previous[1]-previous[2])<=factor*max(Decimal(1),*map(abs,previous[:3]))
  for count,row in enumerate(rows,1):
   assert row['day']==count and row['committed'] is True
   current=tuple(map(D,row['age_state_cm_day']));assert len(current)==11 and all(value.is_finite() for value in current)
   assert all(current[i]>=0 for i in (0,1,2,3,4,5,8,9,10)) and all(current[i]>=previous[i] for i in (3,4,5,8,9,10))
   actual_delta=[current[i]-previous[i] for i in range(3,11)];reported=tuple(map(D,row['age_ledger_cm_day']));assert len(reported)==8
   assert all(float(a)==float(b) for a,b in zip(actual_delta,reported)),'Measured AGE flux differs from actual cumulative-state increment'
   limit=factor*max(Decimal(1),*map(abs,previous[:3]),*map(abs,current[:3]),*map(abs,reported))
   assert float(row['age_tolerance_cm_day'])==float(limit),'Producer reported a different owning AGE tolerance'
   prod,pondprod,incoming,drain,bottom,root,runoff,infil=reported
   soil=current[0]-previous[0]-prod-infil-bottom+drain+root
   pond=current[1]-previous[1]-pondprod-incoming+infil+runoff
   combined=current[2]-previous[2]-prod-pondprod-incoming-bottom+drain+root+runoff
   assert abs(current[0]+current[1]-current[2])<=limit
   assert max(map(abs,(soil,pond,combined)))<=limit,'Independent AGE amount/moment conservation failed'
   assert float(row['age_start_cm_day'])==float(previous[2]) and float(row['age_end_cm_day'])==float(current[2])
   maximum_daily=max(maximum_daily,*map(abs,(soil,pond,combined)))
   flow=[current[i]-origin[i] for i in range(3,11)];prod,pondprod,incoming,drain,bottom,root,runoff,infil=flow
   prefix=[current[0]-origin[0]-prod-infil-bottom+drain+root,current[1]-origin[1]-pondprod-incoming+infil+runoff,current[2]-origin[2]-prod-pondprod-incoming-bottom+drain+root+runoff]
   prefix_limit=factor*max(Decimal(1),*map(abs,origin[:3]),*map(abs,current[:3]),*map(abs,flow));maximum_prefix=max(maximum_prefix,*map(abs,prefix));prefix_within &= max(map(abs,prefix))<=prefix_limit
   # Keep the additional cumulative metric explicit. The unchanged owning
   # AGE policy above is the daily amount/moment ledger, with no invented
   # absolute global bound and no silently increased tolerance.
   decimal=lambda value:Decimal(str(value))
   water=sum(map(decimal,row['stock_start_cm']))-sum(map(decimal,row['stock_end_cm']))+sum(map(decimal,row['external_flux_cm'][:7]))-sum(map(decimal,row['external_flux_cm'][7:]));assert abs(water)<=Decimal('1e-10') and abs(decimal(row['kernel_residual_cm']))<=Decimal('1e-10');maximum_water=max(maximum_water,abs(water))
   effluent=tuple(map(D,row['age_effluent']));assert len(effluent)==24 and all(value.is_finite() for value in effluent)
   for water,amount,mean in zip(effluent[:8],effluent[8:16],effluent[16:]):
    assert water>=0 and amount>=0
    if water==0:assert amount==0 and mean==Decimal(-9999)
    else:assert abs(amount/water-mean)<=factor*max(Decimal(1),abs(mean))
   previous=current
 assert count>0
 return dict(status='INDEPENDENT_MEASURED_WATER_AND_AGE_DAILY_AMOUNT_MOMENT_EFFLUENT_LEDGER_PASS',actual_days=count,water_daily_max_decimal=str(maximum_water),AGE_daily_moment_max_decimal=str(maximum_daily),AGE_additional_cumulative_moment_max_decimal=str(maximum_prefix),AGE_additional_cumulative_moment_within_scaled_policy=bool(prefix_within),AGE_additional_cumulative_metric_is_owning_acceptance_gate=False,owning_AGE_policy='8192 * binary64 epsilon * max(1, actual previous/current stocks and measured interval fluxes)',water_absolute_limit=1e-10,compiler_executions=0,model_executions=0)


def profile(path):
 rows=[json.loads(line) for line in (path/'trajectory/daily.jsonl').read_text().splitlines()]
 initial=next(tuple(map(float,line.split()[1:])) for line in (path/'trajectory/original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_AGE_CUMULATIVE '))
 return read(rows,initial)
