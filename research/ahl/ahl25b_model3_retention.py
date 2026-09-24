#!/usr/bin/env python3
from __future__ import annotations
import base64,gzip,hashlib,json,math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/"reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64"
EXPECTED_SHA="4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"
HMIN=-1.0e6
HMAX=-1.0
THETA_TOL=1e-5
LOGC_TOL=1e-2
LN10=math.log(10.0)

SETS={
"M3_BALANCED":(0.03,0.46,0.02,1.6,0.375,0.0025,1.8,0.4444444444444444,0.55),
"M3_SEPARATED":(0.02,0.44,0.06,2.2,0.5454545454545454,0.001,1.45,0.31034482758620685,0.35),
"M3_DOMINANT_SECOND":(0.04,0.50,0.03,1.7,0.4117647058823529,0.004,2.4,0.5833333333333333,0.15)
}

def bind_source():
    raw=gzip.decompress(base64.b64decode(ASSET.read_bytes()))
    sha=hashlib.sha256(raw).hexdigest()
    if sha!=EXPECTED_SHA: raise SystemExit(f"source SHA mismatch {sha}")
    text=raw.decode()
    required=[
      "watcon = omega_1(node)/(1.0d0+(dabs(alfamg(node)*head))**n(node))**m(node)",
      "watcon = watcon + (1.0d0-omega_1(node))/(1.0d0+(dabs(alfa_2(node)*head))**n_2(node))**m_2(node)",
      "moiscap = omega_1(node)*alfanm(node)*(dabs(alfamg(node)*head))**nMIN1(node)",
      "moiscap = moiscap + (1.0d0-omega_1(node))*alfanm_2(node)*(dabs(alfa_2(node)*head))**nMIN1_2(node)"
    ]
    for token in required:
        if token not in text: raise SystemExit("model3 authority token missing")
    return sha

def exact(h,p):
    tr,ts,a1,n1,m1,a2,n2,m2,w=p
    if h>=0: return ts,0.0
    u1=abs(a1*h); u2=abs(a2*h)
    s1=(1+u1**n1)**(-m1)
    s2=(1+u2**n2)**(-m2)
    theta=tr+(ts-tr)*(w*s1+(1-w)*s2)
    c=(ts-tr)*(w*(a1*n1*m1)*(u1**(n1-1))*(1+u1**n1)**(-(m1+1)) +
               (1-w)*(a2*n2*m2)*(u2**(n2-1))*(1+u2**n2)**(-(m2+1)))
    return theta,max(c,1e-300)

def xh(h): return math.log10(-h)
def hx(x): return -(10**x)

def node(h,p):
    th,c=exact(h,p); tr,ts,*_=p; span=ts-tr
    se=min(max((th-tr)/span,1e-15),1-1e-15)
    z=math.log(se/(1-se))
    dzdh=(c/span)/(se*(1-se))
    return z,dzdh*h*LN10

def hermite(x,x0,x1,y0,y1,m0,m1):
    d=x1-x0;t=(x-x0)/d
    H00=2*t**3-3*t**2+1;H10=t**3-2*t**2+t;H01=-2*t**3+3*t**2;H11=t**3-t**2
    y=H00*y0+H10*d*m0+H01*y1+H11*d*m1
    dH00=6*t*t-6*t;dH10=3*t*t-4*t+1;dH01=-6*t*t+6*t;dH11=3*t*t-2*t
    dy=(dH00*y0+dH10*d*m0+dH01*y1+dH11*d*m1)/d
    return y,dy

def interp(h,h0,h1,p):
    x=xh(h);x0=xh(h0);x1=xh(h1)
    z0,m0=node(h0,p);z1,m1=node(h1,p)
    z,dzdx=hermite(x,x0,x1,z0,z1,m0,m1)
    se=1/(1+math.exp(-z)) if z>=0 else math.exp(z)/(1+math.exp(z))
    tr,ts,*_=p;span=ts-tr
    th=tr+span*se
    c=(span*se*(1-se)*dzdx)/(h*LN10)
    return th,max(c,1e-300)

def interval_error(h0,h1,p,fracs=(0.125,0.25,0.5,0.75,0.875)):
    span=p[1]-p[0]; mt=mc=0.0
    for f in fracs:
        x=xh(h0)+f*(xh(h1)-xh(h0));h=hx(x)
        th,c=exact(h,p);thi,ci=interp(h,h0,h1,p)
        mt=max(mt,abs(thi-th)/span);mc=max(mc,abs(math.log(ci)-math.log(c)))
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
    for a,b in zip(knots[:-1],knots[1:]):
        span=p[1]-p[0]
        for j in range(1,40):
            f=j/40
            h=hx(xh(a)+f*(xh(b)-xh(a)))
            th,c=exact(h,p);thi,ci=interp(h,a,b,p)
            mt=max(mt,abs(thi-th)/span);mc=max(mc,abs(math.log(ci)-math.log(c)))
    return mt,mc

def derivative_check(p):
    worst=0.0
    for j in range(1,101):
        x=xh(HMAX)+j/101*(xh(HMIN)-xh(HMAX));h=hx(x)
        eps=max(1e-7,abs(h)*1e-6)
        t1,_=exact(h+eps,p);t0,_=exact(h-eps,p);_,c=exact(h,p)
        fd=(t1-t0)/(2*eps)
        worst=max(worst,abs(fd-c)/max(abs(c),1e-30))
    return worst

def main():
    sha=bind_source(); out={}
    for name,p in SETS.items():
        knots=sorted(set(refine(HMAX,HMIN,p)),key=xh)
        mt,mc=dense_validate(knots,p)
        out[name]={
          "support_points":len(knots),
          "max_theta_span_error":mt,
          "max_abs_logC_error":mc,
          "source_formula_derivative_fd_max_relative_error":derivative_check(p),
          "pass":mt<=THETA_TOL and mc<=LOGC_TOL
        }
    print(json.dumps({"work_unit":"F-AHL25B","source_sha256":sha,"representation":"cubic Hermite logit(Se), C from same interpolant derivative","materials":out,"status":"PASS" if all(v["pass"] for v in out.values()) else "FAIL"},indent=2))
if __name__=="__main__":main()
