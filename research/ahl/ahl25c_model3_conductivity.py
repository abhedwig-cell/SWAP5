#!/usr/bin/env python3
from __future__ import annotations
import base64,gzip,hashlib,json,math
from pathlib import Path
import ahl25b_model3_retention as m3

ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/"reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64"
EXPECTED_SHA="4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"
HMIN=-1.0e6
HMAX=-1.0
LOGK_TOL=1e-3
MAX_POINTS=500

def bind_source():
    raw=gzip.decompress(base64.b64decode(ASSET.read_bytes()))
    sha=hashlib.sha256(raw).hexdigest()
    if sha!=EXPECTED_SHA: raise SystemExit(f"source SHA mismatch {sha}")
    text=raw.decode()
    required=[
      "s1 = (1.0d0+(dabs(alfamg(node)*head))**n(node))**(-m(node))",
      "s2 = (1.0d0+(dabs(alfa_2(node)*head))**n_2(node))**(-m_2(node))",
      "hconduc = ksatfit(node) * (omega_1(node)*s1+(1.0d0-omega_1(node))*s2)**lambda(node)",
      "hconduc = hconduc * (1.0d0 - (term1+term2)/(omega_1(node)*alfamg(node)+(1.0d0-omega_1(node))*alfa_2(node)))**2"
    ]
    for token in required:
        if token not in text: raise SystemExit("model3 K authority token missing")
    return sha

# Extend the F-AHL25B stress vectors with ksat, lambda for K.
SETS={
 "M3_BALANCED":(0.03,0.46,0.02,1.6,0.375,0.0025,1.8,0.4444444444444444,0.55,25.0,0.5),
 "M3_SEPARATED":(0.02,0.44,0.06,2.2,0.5454545454545454,0.001,1.45,0.31034482758620685,0.35,40.0,-0.5),
 "M3_DOMINANT_SECOND":(0.04,0.50,0.03,1.7,0.4117647058823529,0.004,2.4,0.5833333333333333,0.15,10.0,1.0)
}

def exact_k(h,p):
    tr,ts,a1,n1,m1,a2,n2,m2,w,ksat,lam=p
    if h>=0:return ksat
    s1=(1+abs(a1*h)**n1)**(-m1)
    s2=(1+abs(a2*h)**n2)**(-m2)
    se=w*s1+(1-w)*s2
    if se>=1:return ksat
    t1=w*a1*(1-s1**(1/m1))**m1
    t2=(1-w)*a2*(1-s2**(1/m2))**m2
    den=w*a1+(1-w)*a2
    k=ksat*(se**lam)*(1-(t1+t2)/den)**2
    return max(k,1e-300)

def xh(h):return math.log10(-h)
def hx(x):return -(10**x)

def interp(h,h0,h1,p):
    x=xh(h);x0=xh(h0);x1=xh(h1)
    y0=math.log(exact_k(h0,p));y1=math.log(exact_k(h1,p))
    f=(x-x0)/(x1-x0)
    return math.exp(y0+f*(y1-y0))

def interval_error(h0,h1,p,fracs=(0.125,0.25,0.5,0.75,0.875)):
    mx=0.0
    for f in fracs:
        h=hx(xh(h0)+f*(xh(h1)-xh(h0)))
        mx=max(mx,abs(math.log(interp(h,h0,h1,p))-math.log(exact_k(h,p))))
    return mx

def refine(h0,h1,p,depth=0):
    e=interval_error(h0,h1,p)
    if e<=LOGK_TOL:return [h0,h1]
    if depth>=40:raise RuntimeError("refinement depth")
    hm=hx(0.5*(xh(h0)+xh(h1)))
    a=refine(h0,hm,p,depth+1);b=refine(hm,h1,p,depth+1)
    out=a[:-1]+b
    if len(out)>MAX_POINTS:raise RuntimeError("support point ceiling")
    return out

def dense_validate(knots,p):
    mx=0.0
    for a,b in zip(knots[:-1],knots[1:]):
        for j in range(1,40):
            f=j/40
            h=hx(xh(a)+f*(xh(b)-xh(a)))
            mx=max(mx,abs(math.log(interp(h,a,b,p))-math.log(exact_k(h,p))))
    return mx

def main():
    sha=bind_source(); out={}; status="PASS"
    for name,p in SETS.items():
        try:
            knots=sorted(set(refine(HMAX,HMIN,p)),key=xh)
            err=dense_validate(knots,p)
            passed=err<=LOGK_TOL and len(knots)<=MAX_POINTS
            out[name]={"support_points":len(knots),"max_abs_logK_error":err,"pass":passed}
            if not passed:status="FAIL"
        except Exception as e:
            out[name]={"status":"BUILD_FAIL","error":str(e),"pass":False}
            status="FAIL"
    print(json.dumps({"work_unit":"F-AHL25C","source_sha256":sha,"status":status,"materials":out},indent=2))
if __name__=="__main__":main()
