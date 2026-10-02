"""Independent stationary vertical Darcy recurrence and confined-strip oracle."""
import argparse,ctypes,json
from pathlib import Path
import numpy as np
from component import Swap

def main():
 p=argparse.ArgumentParser();p.add_argument('--library',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();s=Swap(a.library);assert s.initialize(.1,-5,1e-7)==0
 ptr=ctypes.POINTER(ctypes.c_double);f=s.lib.strip_hydraulics;f.argtypes=[ptr]*3;f.restype=ctypes.c_int
 def evaluate(h):
  h=np.ascontiguousarray(h,dtype=np.float64);w=np.zeros(30);k=np.zeros(30);assert f(*[v.ctypes.data_as(ptr) for v in [h,w,k]])==0;return w,k
 def conductivity(h):return evaluate(np.full(30,h))[1][0]
 R=.1;ks=31.225016;mf=np.zeros(50);mf[0]=-5+50*.001/100
 for j in range(1,50):mf[j]=mf[j-1]+(50-j)*.001/2
 profiles=[];gwl=[];corrections=[];max_res=0
 for H in mf:
  bottom=100*(H+6);h=np.zeros(30);h[-1]=bottom-10+R*10/ks
  for j in range(28,-1,-1):
   lo=h[j+1]-20;hi=h[j+1];klow=conductivity(h[j+1])
   for _ in range(64):
    mid=(lo+hi)/2;flux=.5*(conductivity(mid)+klow)*((mid-h[j+1])/20+1)
    if flux>R:hi=mid
    else:lo=mid
   h[j]=(lo+hi)/2
  w,k=evaluate(h);fluxes=.5*(k[:-1]+k[1:])*((h[:-1]-h[1:])/20+1)
  bottom_flux=k[-1]*((h[-1]-bottom)/10+1);max_res=max(max_res,float(np.max(abs(fluxes-R))),abs(bottom_flux-R))
  index=np.flatnonzero(h>=0)[0];z=-10-20*np.arange(30);level=z[index-1]-h[index-1]*(z[index]-z[index-1])/(h[index]-h[index-1]);gwl.append(float(level));profiles.append(h.tolist())
  kface=.5*(k[index-1]+k[index]);corrections.append(.01*h[index]*(1/(1-R/kface)-1/(1-R/ks)))
 r=R/ks;darcy=(mf+6*r)/(1-r);gwl_m=np.array(gwl)*.01
 assert max_res<1e-11
 continuum_error=float(max(abs(gwl_m-darcy)))
 discrete_error=float(max(abs(gwl_m-darcy-np.array(corrections))))
 assert discrete_error<1e-10
 row=dict(mf_head_m=mf.tolist(),pressure_cm=profiles,gwl_cm=gwl,forcing_rain_m_day=.001,max_face_residual_cm_day=max_res,max_gwl_continuum_interpolation_difference_m=continuum_error,max_gwl_discrete_darcy_error_m=discrete_error,method='INDEPENDENT_SCALAR_DARCY_BISECTION_WITH_QUALIFIED_CONSTITUTIVE_PROVIDER')
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(row,indent=2)+'\n');print('STEADY_PROFILE_ORACLE_PASS',max_res,mf[0],mf[-1],(gwl_m-mf).min(),(gwl_m-mf).max(),continuum_error,discrete_error)
if __name__=='__main__':main()
