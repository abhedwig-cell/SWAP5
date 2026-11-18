"""Separate twelve-field direct-soil age ledger; no project activation yet."""
import math
from conserved_original_age import validate as validate_original,tolerance


def validate(values):
    if len(values)!=12:
        raise ValueError('Direct soil age requires its twelve-field state')
    validate_original(values[:11])
    if not math.isfinite(values[11]) or values[11]<0:
        raise ValueError('Invalid cumulative direct soil age input')
    return values


def ledger(previous,current):
    validate(previous);validate(current)
    if any(current[i]<previous[i] for i in (3,4,5,8,9,10,11)):
        raise ValueError('Direct soil age cumulative source/loss moved backward')
    prod,pondprod,external,drain,bottom,root,runoff,infil,direct=flows=[math.fsum([current[i],-previous[i]]) for i in range(3,12)]
    soil=math.fsum([current[0],-previous[0],-prod,-infil,-bottom,drain,root,-direct])
    pond=math.fsum([current[1],-previous[1],-pondprod,-external,infil,runoff])
    combined=math.fsum([current[2],-previous[2],-prod,-pondprod,-external,-bottom,drain,root,runoff,-direct])
    limit=tolerance(*previous[:3],*current[:3],*flows)
    if any(not math.isfinite(v) or abs(v)>limit for v in (soil,pond,combined)):
        raise ValueError('Direct soil age candidate exceeds accepted age balance policy')
    return dict(age_state_cm_day=current,age_start_cm_day=previous[2],age_end_cm_day=current[2],
                age_ledger_cm_day=flows,age_direct_soil_input_cm_day=direct,
                age_soil_residual_cm_day=soil,age_pond_residual_cm_day=pond,
                age_combined_residual_cm_day=combined,age_tolerance_cm_day=limit)
