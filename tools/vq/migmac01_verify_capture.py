import csv,json,math,hashlib
from pathlib import Path
r=list(csv.reader(open('reference-run/case/migmac01_authority.csv')))
a={int(x[1]):list(map(float,x[2:])) for x in r if x[0]=='ORIGIN_NODE'}
e={int(x[1]):list(map(float,x[2:])) for x in r if x[0]=='END_NODE'}
d=[(int(x[1]),int(x[2]),list(map(float,x[3:]))) for x in r if x[0]=='END_DOMAIN']
dt=float(next(x for x in r if x[0]=='META')[2]);nd=5;top=3
covered=sum(map(float,next(x for x in r if x[0]=='TOP_COVERED_RATE')[1:]))*dt
sink=sum(v[8] for id,ic,v in d if ic==2)*dt
before=sum(sum(v[37+8*i+4] for i in range(nd)) for v in a.values())
after=sum(v[4] for id,ic,v in d)
exchange=sum(v[8] for id,ic,v in d if ic>=top)*dt
rapid=sum(v[6] for v in e.values())*dt
v=a[top][10]+a[top][36];r0=5*(1-math.sqrt(1-v));w=1/(1+10/(3.14159*.5)*math.log(10/(3.14159*r0))+100/6)
result=dict(schema_version=1,label='MODIFIED_ANDELST_COVERED_TOP',preregistration_head='a20b15ed3e45cd9ccba491ed00e64223c3cd1e38',time=float(next(x for x in r if x[0]=='META')[1]),dt=dt,top_node=top,domains=nd,nodes=112,h_cover_origin=a[2][2],h_cover_accepted=e[2][0],covered_cm=covered,cover_matrix_sink_cm=sink,cover_ownership_residual_cm=covered+sink,macro_before_cm=before,macro_after_cm=after,other_macro_to_matrix_cm=exchange,rapid_drain_cm=rapid,macro_balance_residual_cm=after-before-covered+exchange+rapid,final_head_b111_potential_cm=w*(e[2][0]/.5+1)*dt,reference_final_head_receipt_exact=False,reference_final_head_receipt_note='Legacy converged receipt is lagged by last nonlinear iteration; do not demand exact final-head equivalence from this extraction.',source_manifest_sha256='24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2',capture_sha256=hashlib.sha256(Path('reference-run/case/migmac01_authority.csv').read_bytes()).hexdigest(),swap5_qualified=False)
assert covered>0 and e[2][0]>0 and abs(covered+sink)<1e-15 and abs(result['macro_balance_residual_cm'])<1e-12
Path('reference-run/source_checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
