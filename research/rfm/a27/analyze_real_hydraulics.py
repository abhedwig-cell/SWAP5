"""Adjudicate actual-provider domain and saturated pressure counterexamples."""
import csv,json,sys
from pathlib import Path
hyd_path,darcy_path,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=True)
def read(p):
    with p.open() as f:return list(csv.DictReader(f))
r=read(hyd_path);q=read(darcy_path)
assert len(r)==1296 and len(q)==576
codes=sorted({x['code'] for x in r});assert len(codes)==36
table=[];unsaturated=[]
for code in codes:
    a=[x for x in r if x['code']==code and float(x['head_cm'])>=0]
    assert len({float(x['theta']) for x in a})==1 and len({float(x['K_cm_day']) for x in a})==1
    assert all(float(x['retention_derivative_cm_inv'])==0 and int(x['physical_D_defined'])==0 for x in a)
    fixed=[x for x in a if float(x['head_cm'])==1]
    d=[float(x['provider_K_over_C_cm2_day']) for x in fixed]
    assert abs(max(d)/min(d)-1000)<1e-8
    b=[x for x in q if x['code']==code and float(x['dt_day'])==.1]
    assert len({float(x['theta']) for x in b})==1
    error=max(abs(float(x['actual_macro_to_matrix_rate_cm_day'])-float(x['analytic_rate_cm_day'])) for x in b)
    rates={float(x['matrix_head_cm']):float(x['actual_macro_to_matrix_rate_cm_day']) for x in b}
    assert rates[0]>0 and rates[1]>0 and rates[5]==0 and rates[9]<0
    table.append(dict(code=code,theta_s=float(a[0]['theta']),Ks_cm_day=float(a[0]['K_cm_day']),dt_ratio=max(float(x['dt_day']) for x in fixed)/min(float(x['dt_day']) for x in fixed),provider_D_min_cm2_day=min(d),provider_D_max_cm2_day=max(d),provider_D_ratio=max(d)/min(d),source_Darcy_to_matrix_h0=rates[0],source_Darcy_to_matrix_h1=rates[1],source_Darcy_to_matrix_h5=rates[5],source_Darcy_to_matrix_h9=rates[9],theta_only_saturated_diffusion_rate=0.,signed_source_algebra_error_cm_day=error,theta_only_general_route_falsified=1,provider_K_C_physical_mapping_falsified=1))
    for x in r:
        if x['code']!=code or float(x['head_cm'])>=0:continue
        c=float(x['provider_C_cm_inv']);deriv=float(x['retention_derivative_cm_inv'])
        unsaturated.append(dict(code=code,dt_day=float(x['dt_day']),head_cm=float(x['head_cm']),retention_derivative_cm_inv=deriv,provider_C_cm_inv=c,relative_derivative_discrepancy=abs(c-deriv)/deriv,physical_D_cm2_day=float(x['physical_D_cm2_day'])))
for name,rows in [('real_domain_counterexamples.csv',table),('real_unsaturated_derivative.csv',unsaturated)]:
    with (out/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
summary={'materials':36,'hydraulic_rows':len(r),'actual_signed_source_rows':len(q),'theta_only_general_route_falsified_materials':36,'timestep_dependent_provider_K_C_materials':36,'saturated_provider_D_ratio':1000.,'max_unsaturated_relative_derivative_discrepancy':max(x['relative_derivative_discrepancy'] for x in unsaturated),'max_source_Darcy_algebra_error_cm_day':max(x['signed_source_algebra_error_cm_day'] for x in table),'positive_zero_reverse_source_signs':'PASS','scope':'default MvG without physical elastic storage, all repository catalog Ks values; source primitives, not production A/B/C','production_qualified':False,'canonical_admitted':False}
(out/'real_hydraulics_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
print('A27_REAL_DOMAIN_FALSIFIERS_VERIFIED=PASS')
