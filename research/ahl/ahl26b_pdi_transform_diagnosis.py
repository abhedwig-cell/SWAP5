#!/usr/bin/env python3
from __future__ import annotations
import json,math

SETS={
"PDI8_REFERENCE":{
 "model":8,"tr":0.05,"ts":0.45,"a1":0.02,"n1":1.6,"m1":0.375,
 "h0":1e7,"ha":1e4,"apar":-1.5,"omegaK":0.01
},
"PDI10_BIMODAL":{
 "model":10,"tr":0.04,"ts":0.46,"a1":0.03,"n1":1.8,"m1":0.4444444444444444,
 "a2":0.003,"n2":1.6,"m2":0.375,"w1":0.6,"w2":0.4,
 "h0":1e7,"ha":1e4,"apar":-1.2,"omegaK":0.02
}
}

def b(p):
    nn=p["n1"]
    if p["model"] in (10,11) and p["a2"]>p["a1"]: nn=p["n2"]
    return 0.1+0.2/nn**2*(1-math.exp(-((p["tr"]/(p["ts"]-p["tr"]))**2)))

def sad(abs_h,p):
    xa=math.log10(p["ha"]);x0=math.log10(p["h0"]);x=math.log10(abs_h);bb=b(p)
    return 1+(x-xa+bb*math.log1p(math.exp((xa-x)/bb)))/(xa-x0)

def dsad_dh_abs(abs_h,p):
    xa=math.log10(p["ha"]);x0=math.log10(p["h0"]);x=math.log10(abs_h);bb=b(p)
    return -1.0/(abs_h*math.log(10.0)*(xa-x0)*(1+math.exp((xa-x)/bb)))

def gamma(abs_h,a,n,m): return (1+(a*abs_h)**n)**(-m)
def c_mode(abs_h,a,n,m): return a*n*m*(a*abs_h)**(n-1)*(1+(a*abs_h)**n)**(-m-1)

def exact(h,p):
    if h>=0:return p["ts"],0.0
    ah=abs(h)
    if p["model"]==8:
        scap=gamma(ah,p["a1"],p["n1"],p["m1"])
        theta=sad(ah,p)*p["tr"]+scap*(p["ts"]-p["tr"])
        c=(p["ts"]-p["tr"])*c_mode(ah,p["a1"],p["n1"],p["m1"])+p["tr"]*dsad_dh_abs(ah,p)
    else:
        g1=gamma(ah,p["a1"],p["n1"],p["m1"]);g2=gamma(ah,p["a2"],p["n2"],p["m2"])
        scap=p["w1"]*g1+p["w2"]*g2
        theta=sad(ah,p)*p["tr"]+scap*(p["ts"]-p["tr"])
        c=(p["ts"]-p["tr"])*(p["w1"]*c_mode(ah,p["a1"],p["n1"],p["m1"])+p["w2"]*c_mode(ah,p["a2"],p["n2"],p["m2"]))+p["tr"]*dsad_dh_abs(ah,p)
    return theta,c

def main():
    out={}
    for name,p in SETS.items():
        heads=[-(10**(i/1000*7)) for i in range(0,7001)]
        vals=[exact(h,p) for h in heads]
        theta=[v[0] for v in vals];cap=[v[1] for v in vals]
        se=[(t-p["tr"])/(p["ts"]-p["tr"]) for t in theta]
        q=[t/p["ts"] for t in theta]
        first_below=None
        for h,t in zip(heads,theta):
            if t<p["tr"]:
                first_below=h;break
        monotone=all(theta[i+1]<=theta[i]+1e-15 for i in range(len(theta)-1))
        positive_c=min(cap)>0
        # central finite-difference source consistency over representative log points
        max_rel=0.0
        for j in range(10,6990,35):
            h=heads[j];eps=max(abs(h)*1e-6,1e-8)
            tp=exact(h+eps,p)[0];tm=exact(h-eps,p)[0];fd=(tp-tm)/(2*eps)
            c=exact(h,p)[1]
            max_rel=max(max_rel,abs(fd-c)/max(abs(c),1e-30))
        out[name]={
          "min_theta":min(theta),
          "theta_r":p["tr"],
          "theta_s":p["ts"],
          "first_head_theta_below_theta_r_cm":first_below,
          "legacy_Se_range":[min(se),max(se)],
          "theta_over_theta_s_range":[min(q),max(q)],
          "theta_monotone_with_drying":monotone,
          "capacity_positive":positive_c,
          "source_formula_derivative_fd_max_relative_error":max_rel,
          "legacy_logit_valid_everywhere":min(se)>0 and max(se)<1,
          "theta_over_theta_s_logit_valid_everywhere":min(q)>0 and max(q)<1
        }
    status="LEGACY_TRANSFORM_REJECTED" if all(not v["legacy_logit_valid_everywhere"] for v in out.values()) else "MIXED"
    print(json.dumps({"work_unit":"F-AHL26B","status":status,"sets":out},indent=2))
if __name__=="__main__":main()
