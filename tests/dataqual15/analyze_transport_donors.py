"""Independent selected-interval water/energy-data inventory; no invented donors."""
import argparse,collections,json,math
from pathlib import Path
from analyze_native_thermal_receipts import analyze as thermal_audit

def analyze(thermal_raw,transport_raw):
 thermal={};matrix={};macro=collections.defaultdict(list)
 for line in thermal_raw.decode().splitlines():
  r=line.split(',');v=list(map(float,r[1:]));thermal[(v[0],v[1],int(v[2]))]=v
 for line in transport_raw.decode().splitlines():
  r=line.split(',');v=list(map(float,r[1:]));assert all(math.isfinite(x) for x in v)
  if r[0]=='MATRIX':
   assert len(v)==11;k=(v[0],v[1],int(v[2]));assert k not in matrix;matrix[k]=v
  else:
   assert r[0]=='MACRO' and len(v)==10;macro[(v[0],v[1],int(v[3]))].append(v)
 assert matrix.keys()==thermal.keys()==macro.keys()
 intervals=sorted({k[:2] for k in matrix});cursor=0.;previous_macro={};max_macro_cell=max_macro_face=max_matrix_closure=0.
 sums=collections.defaultdict(float);counts=collections.Counter();root_cases=[]
 weighted_stock=macro_equal_temperature_stock=0.
 for t0,t1 in intervals:
  assert t0==cursor and t1>t0;cursor=t1;dt=t1-t0
  previous_faces={};matrix_faces=[];qdown=None
  for node in range(1,113):
   key=(t0,t1,node);th=thermal[key];m=matrix[key]
   _,_,_,a,b,w0,w1,dz,capacity,left,right,root,drain,source,exchange,phi,fq,fc,fo,*flags=th
   _,_,_,area,top,bottom,net,rr,dd,ss,xx=m
   assert 0<area<=1 and [rr,dd,ss,xx]==[root,drain,source,exchange]
   assert abs(net-(source-drain-root+exchange))<1e-13
   if node==1:qdown=-top;matrix_faces.append(qdown);sums['matrix_top_net_into_cm']-=top*dt
   delta=area*dz*(w1-w0)
   qdown=qdown+net-delta/dt;matrix_faces.append(qdown)
   if node==112:
    max_matrix_closure=max(max_matrix_closure,abs((qdown+bottom)*dt));sums['matrix_bottom_net_into_cm']+=bottom*dt
   solid=(fq*2660*800+fc*2650*900+fo*1300*1920)*1e-6
   cp0=solid+4.18*w0+.001212*(phi-w0);cp1=solid+4.18*w1+.001212*(phi-w1)
   weighted_stock+=area*dz*(cp1*b-cp0*a)
   sums['matrix_liquid_storage_change_cm']+=delta
   sums['root_out_cm']+=root*dt;sums['drain_out_cm']+=drain*dt;sums['lateral_net_into_cm']+=source*dt
   sums['root_endpoint_mean_enthalpy_out_j_cm2']+=4.18*root*dt*.5*(a+b)
   if root*dt!=0:root_cases.append([root*dt,.5*(a+b),4.18*root*dt*.5*(a+b)])
   for v in macro[key]:
    _,_,domain,nn,v0,v1,ql,qr,qx,qe=v;domain=int(domain);assert nn==node and min(v0,v1)>=0
    max_macro_cell=max(max_macro_cell,abs(v1-v0-dt*(ql-qr-qx-qe)))
    if node>1:max_macro_face=max(max_macro_face,abs(ql-previous_faces[domain]))
    previous_faces[domain]=qr
    if (domain,node) in previous_macro:assert v0==previous_macro[(domain,node)]
    previous_macro[(domain,node)]=v1
    sums['macro_liquid_storage_change_cm']+=v1-v0
    sums['macro_to_matrix_positive_cm']+=dt*max(0.,qx);sums['matrix_to_macro_positive_cm']+=dt*max(0.,-qx)
    sums['macro_external_out_cm']+=dt*qe
    if node==1:sums['macro_top_net_into_cm']+=dt*ql
    if node==112:sums['macro_bottom_net_out_cm']+=dt*qr
    counts['macro_positive_exchange_missing_macro_temperature']+=int(qx>0)
    counts['macro_negative_exchange_matrix_endpoint_temperature_only']+=int(qx<0)
    counts['macro_nonzero_vertical_missing_donor_temperature']+=int(ql!=0 or qr!=0)
    macro_equal_temperature_stock+=4.18*(v1*b-v0*a)
   assert abs(sum(v[8] for v in macro[key])-exchange)<1e-12
  # Internal matrix water-face reconstruction is continuity-based, not an independent Darcy observation.
  sums['matrix_internal_abs_reconstructed_transport_cm']+=dt*sum(abs(q) for q in matrix_faces[1:-1])
 assert cursor==1. and max_macro_cell<1e-12 and max_macro_face<1e-12 and max_matrix_closure<1e-8
 total_storage=sums['matrix_liquid_storage_change_cm']+sums['macro_liquid_storage_change_cm']
 external=sums['matrix_top_net_into_cm']+sums['matrix_bottom_net_into_cm']+sums['macro_top_net_into_cm']-sums['macro_bottom_net_out_cm']+sums['lateral_net_into_cm']-sums['root_out_cm']-sums['drain_out_cm']-sums['macro_external_out_cm']
 assert abs(total_storage-external)<1e-8
 result=dict(status='ACTUAL_TRANSPORT_LEDGER_AND_MISSING_DONORS_VERIFIED',intervals=len(intervals),matrix_node_rows=len(matrix),macro_node_rows=sum(map(len,macro.values())),max_macro_cell_amount_residual_cm=max_macro_cell,max_macro_internal_face_rate_mismatch_cm_day=max_macro_face,max_matrix_reconstructed_boundary_residual_cm=max_matrix_closure,whole_liquid_water_residual_cm=total_storage-external,integrals=dict(sums),counts=dict(counts),matrix_area_weighted_profile_stock_change_j_cm2=weighted_stock,macro_liquid_stock_equal_matrix_temperature_scenario_j_cm2=macro_equal_temperature_stock,root_enthalpy_scope='Endpoint-mean donor-temperature scenario through real liquid enthalpy owner; not measured temporal quadrature',matrix_face_scope='Reconstructed from accepted water ledger, not independently measured Darcy faces',full_energy_balance_complete=False,missing=['Macro temperature/state and independent macro thermal transport','External rain/irrigation/lateral/bottom liquid donor temperature and substep quadrature','Gas flow/density and external donor temperature','Radiation/latent/vapor/phase process receipts'])
 return result,root_cases

def main():
 p=argparse.ArgumentParser();p.add_argument('folder',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 r,cases=analyze((a.folder/'actual-thermal.csv').read_bytes(),(a.folder/'actual-transport.csv').read_bytes());r['thermal']=thermal_audit((a.folder/'actual-thermal.csv').read_bytes());a.output.write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');a.output.with_suffix('.donors.dat').write_text(''.join(' '.join(format(v,'.17e') for v in row)+'\n' for row in cases),encoding='utf-8');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
