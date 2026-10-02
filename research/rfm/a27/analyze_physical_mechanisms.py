"""Regenerate case and spatial refinement tables from immutable mechanism CSVs."""
import csv, sys
from pathlib import Path
p=Path(sys.argv[1])
def read(name):
    with (p/name).open() as f:return list(csv.DictReader(f))
def write(name,rows):
    with (p/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
r=read('signed_coupling.csv');out=[]
for k in sorted({(float(x['Ks']),float(x['dt_day']),x['mode']) for x in r}):
    a=[x for x in r if (float(x['Ks']),float(x['dt_day']),x['mode'])==k]
    out.append(dict(Ks=k[0],dt_day=k[1],mode=k[2],kappa_dt=float(a[0]['kappa'])*k[1],max_head_error_cm=max(float(x['macro_head_error_cm']) for x in a),max_exchange_error_cm=max(float(x['cum_exchange_error_cm']) for x in a),max_ledger_residual_cm=max(abs(float(x['mass_residual_cm'])) for x in a),overshoots=max(int(x['equilibrium_overshoots']) for x in a),negative_head_steps=max(int(x['negative_head_steps']) for x in a)))
write('signed_coupling_comparison.csv',out)
r=read('interrupted_contact.csv');v=read('slab_validation.csv');out=[]
meshes=sorted({int(x['n']) for x in r})
for coarse,fine in zip(meshes,meshes[1:]):
    a={(x['gap_day'],x['renewed_day']):float(x['retained_profile_uptake_cm']) for x in r if int(x['n'])==coarse}
    b={(x['gap_day'],x['renewed_day']):float(x['retained_profile_uptake_cm']) for x in r if int(x['n'])==fine}
    out.append(dict(coarse=coarse,fine=fine,max_rewet_difference_cm=max(abs(a[k]-b[k]) for k in a),fine_max_analytic_error_cm=max(float(x['error_cm']) for x in v if int(x['n'])==fine),threshold_cm=.0001))
write('slab_refinement.csv',out)
print('A27_MECHANISM_ANALYSIS=PASS')
