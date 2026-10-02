#!/usr/bin/env python3
"""Source-bound branch-local residual reconstruction; no global root claim."""
import csv,hashlib,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[2];log=Path('/tmp/top03-frozen.log')
lines=log.read_text().splitlines();blocks=[];records=[];header=None
for l in lines:
 if l.startswith('FROZEN_COEFFICIENTS,'):blocks.append({'coefficients':list(map(float,l.split(',')[1:])),'nodes':[]})
 elif l.startswith('FROZEN_HEADER,'):blocks[-1]['header']=list(map(float,l.split(',')[1:]))
 elif l.startswith('FROZEN_NODE,'):blocks[-1]['nodes'].append(list(map(float,l.split(',')[1:])))
 elif l.startswith('geometry,'):header=l.split(',')
 elif l.startswith('2,7,'):records.append(dict(zip(header,next(csv.reader([l])))))
assert len(blocks)==2 and blocks[0]==blocks[1] and len(records)==2
stable=lambda r:{k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
assert stable(records[0])==stable(records[1])
baseline=list(csv.DictReader((root/'integration/sw-rib-top03/evidence/terminal_trace/strict_geometry2_O0.csv').open()))
b=next(r for r in baseline if r['bottom_mode']=='7' and r['profile']=='1' and r['history']=='3' and r['steps']=='2048')
assert stable(b)==stable(records[0]) and b['completed']=='85' and b['stop_code']=='1'
d=blocks[0];c=np.array([0.]+d['coefficients']);a=np.array(d['nodes']);n,dt,hsurf,qtop,qbot=d['header'];assert n==4
dz=a[:,2];dist=a[:,3];origin=a[:,4];head=a[:,5];theta_dump=a[:,6];kf=a[:,7];residual_dump=a[:,8];sources=a[:,9]-a[:,10]+a[:,11]
assert np.all(sources==0) and c[9]>-.01
def theta(h):
 if h>=0:return c[2]
 if h>-.01:return min(c[26]+c[27]*(h+.01),c[2])
 return c[1]+c[25]/(1+abs(c[4]*h)**c[6])**c[7]
def conductivity(h):
 se=(theta(h)-c[1])/c[25]
 if se>1-1e-6:return c[3]
 return min(c[3]*se**c[5]*(1-(1-se**c[32])**c[7])**2,c[3])
def residual(h):
 t=np.array([theta(x) for x in h]);flux=kf*((np.r_[hsurf,h[:-1]]-h)/dist+1)
 return (t-origin)*dz/dt+np.r_[flux[1:],conductivity(h[-1])]-flux+sources
assert np.max(np.abs(np.array([theta(h) for h in head])-theta_dump))<=1e-14
reconstruction=float(np.max(np.abs(residual(head)-residual_dump)));assert reconstruction<1e-12
assert abs(-qbot-conductivity(head[-1]))<1e-12
assert abs(-qtop-kf[0]*((hsurf-head[0])/dist[0]+1))<1e-12
# Upper heads are constrained to the saturated branch, hence theta=theta_s there.
# Solve their three linear residual rows for each prescribed bottom head.
def eliminated(hbottom):
 def upper_residual(u):
  h=np.r_[u,hbottom];flux=kf*((np.r_[hsurf,h[:-1]]-h)/dist+1)
  return (c[2]-origin[:3])*dz[:3]/dt+flux[1:]-flux[:3]+sources[:3]
 offset=upper_residual(np.zeros(3));matrix=np.column_stack([upper_residual(np.eye(3)[i])-offset for i in range(3)])
 u=np.linalg.solve(matrix,-offset);h=np.r_[u,hbottom]
 assert min(u)>0 and max(abs(residual(h)[:3]))<1e-12
 return h,float(residual(h)[-1])
cut=-((1-1e-6)**(-1/c[7])-1)**(1/c[6])/c[4]
samples=[]
for hb in [-.02]+[cut-sign*10.**(-j) for j in range(4,10) for sign in (1,-1)]+[0.]:
 h,r=eliminated(hb);samples.append({'bottom_head_cm':hb,'upper_heads_cm':h[:3].tolist(),'bottom_residual_cm_day':r,'Kbottom_cm_day':conductivity(hb)})
left=next(x for x in samples if x['bottom_head_cm']==cut-1e-9)
right=next(x for x in samples if x['bottom_head_cm']==cut+1e-9)
assert left['bottom_residual_cm_day']<0<right['bottom_residual_cm_day']
hc,_=eliminated(cut)
incoming=kf[-1]*((hc[-2]-cut)/dist[-1]+1)
se_cut=1-1e-6;theta_cut=c[1]+c[25]*se_cut
common=(theta_cut-origin[-1])*dz[-1]/dt-incoming+sources[-1]
kleft_limit=c[3]*se_cut**c[5]*(1-(1-se_cut**c[32])**c[7])**2
left_limit=common+kleft_limit;right_limit=common+c[3]
assert left_limit<0<right_limit
assert abs(conductivity(cut-1e-9)-4.570054653885331)<1e-12
assert conductivity(cut+1e-9)==4.75
result={'scope':'single failed fixed-origin trial; exact linear elimination on saturated upper-node branch',
 'production_qualified':False,'global_root_absence_claim':False,
 'source_checkpoint':'e2608a343799021b21e37bf3bed3659c6a100019',
 'decision':'BRANCH_LOCAL_RESIDUAL_GAP_CONFIRMED__NEWTON_TUNING_CANNOT_SUPPLY_MISSING_BRANCH_ROOT',
 'O0_O2_identity':True,'instrumentation_preserves_trajectory':True,'failed_step':86,
 'residual_reconstruction_max_error_cm_day':reconstruction,
 'bottom_head_interval_cm':[-.02,0.],'cut_head_cm':cut,
 'left_residual_cm_day':left['bottom_residual_cm_day'],'right_residual_cm_day':right['bottom_residual_cm_day'],
 'left_limit_residual_cm_day':left_limit,'right_limit_residual_cm_day':right_limit,
 'branch_argument':'Upper saturated rows are linear and uniquely eliminated. Bottom storage and K are nondecreasing on each branch; eliminated incoming flux decreases with bottom head, hence bottom residual is strictly increasing on each branch. Left limit is negative, right limit positive: no zero in [-.02,0] under this saturated-upper branch. Upper heads remain positive at both interval endpoints and are affine, so the entire interval satisfies that branch assumption. Other branches or global roots are not excluded.',
 'sampled_eliminated_states':samples,'frozen_trial':d,
 'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
 'source_sha256':{}}
for p in ['tests/fapp/make_top03_frozen_origin_probe.py','tests/fapp/run_sw_rib_top03_frozen_origin.sh','tests/fapp/analyze_sw_rib_top03_frozen_origin.py','src/legacy/b1_10_port/headcalc.f90','src/solver/mod_b110_default_mvg_provider.f90']:
 result['source_sha256'][p]=hashlib.sha256((root/p).read_bytes()).hexdigest()
out=root/'integration/sw-rib-top03/evidence/frozen_origin';out.mkdir(parents=True,exist_ok=True)
(out/'observations_O0_O2.txt').write_text('\n'.join(l for l in lines if l.startswith(('FROZEN_','ITER,','STOP,','geometry,','2,7,','TOP03_TRANSITION_O')))+'\n')
(out/'frozen_trial_O0_O2.json').write_text(json.dumps(d,indent=2)+'\n')
(out/'eliminated_branch_samples.json').write_text(json.dumps(samples,indent=2)+'\n')
(root/'integration/sw-rib-top03/TOP03_FROZEN_ORIGIN_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('sampled_eliminated_states','frozen_trial','source_sha256')},indent=2))
