#!/usr/bin/env python3
from __future__ import annotations
import json,math
import ahl26b_pdi_transform_diagnosis as pdi

HMIN=-1.0e7
HMAX=-1.0
THETA_TOL=1e-5
LOGC_TOL=1e-2
LN10=math.log(10.0)

def xh(h): return math.log10(-h)
def hx(x): return -(10**x)

def node(h,p):
    theta,c=pdi.exact(h,p)
    q=theta/p["ts"]
    if not (0.0<q<1.0):
        raise RuntimeError(f"invalid theta/thetas transform q={q} h={h}")
    z=math.log(q/(1-q))
    dzdh=(c/p["ts"])/(q*(1-q))
    return z,dzdh*h*LN10

def hermite(x,x0,x1,y0,y1,m0,m1):
    dx=x1-x0;t=(x-x0)/dx
    h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
    y=h00*y0+h10*dx*m0+h01*y1+h11*dx*m1
    dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
    dydx=(dh00*y0+dh10*dx*m0+dh01*y1+dh11*dx*m1)/dx
    return y,dydx

def interp(h,h0,h1,p):
    x=xh(h);x0=xh(h0);x1=xh(h1)
    z0,m0=node(h0,p);z1,m1=node(h1,p)
    z,dzdx=hermite(x,x0,x1,z0,z1,m0,m1)
    q=1/(1+math.exp(-z)) if z>=0 else math.exp(z)/(1+math.exp(z))
    theta=p["ts"]*q
    c=p["ts"]*q*(1-q)*dzdx/(h*LN10)
    return theta,max(c,1e-300)

def interval_error(h0,h1,p,fracs=(0.125,0.25,0.5,0.75,0.875)):
    mt=mc=0.0
    for f in fracs:
        h=hx(xh(h0)+f*(xh(h1)-xh(h0)))
        th,c=pdi.exact(h,p);thi,ci=interp(h,h0,h1,p)
        mt=max(mt,abs(thi-th)/p["ts"])
        mc=max(mc,abs(math.log(ci)-math.log(c)))
    return max(mt/THETA_TOL,mc/LOGC_TOL),mt,mc

def refine(h0,h1,p,depth=0):
    score,_,_=interval_error(h0,h1,p)
    if score<=1:return [h0,h1]
    if depth>=40:raise RuntimeError("refinement depth")
    hm=hx(0.5*(xh(h0)+xh(h1)))
    a=refine(h0,hm,p,depth+1);b=refine(hm,h1,p,depth+1)
    return a[:-1]+b

def dense_validate(knots,p):
    mt=mc=0.0
    min_c=1e300
    for a,b in zip(knots[:-1],knots[1:]):
        for j in range(1,50):
            f=j/50
            h=hx(xh(a)+f*(xh(b)-xh(a)))
            th,c=pdi.exact(h,p);thi,ci=interp(h,a,b,p)
            mt=max(mt,abs(thi-th)/p["ts"])
            mc=max(mc,abs(math.log(ci)-math.log(c)))
            min_c=min(min_c,ci)
    return mt,mc,min_c

def main():
    out={};status="PASS"
    for name,p in pdi.SETS.items():
        knots=sorted(set(refine(HMAX,HMIN,p)),key=xh)
        mt,mc,minc=dense_validate(knots,p)
        passed=mt<=THETA_TOL and mc<=LOGC_TOL and minc>0
        out[name]={
          "support_points":len(knots),
          "max_abs_theta_over_theta_s_error":mt,
          "max_abs_logC_error":mc,
          "min_interpolated_C":minc,
          "pass":passed
        }
        if not passed:status="FAIL"
    print(json.dumps({"work_unit":"F-AHL26C","status":status,"representation":"Hermite logit(theta/theta_s), C from same derivative","sets":out},indent=2))
if __name__=="__main__":main()
