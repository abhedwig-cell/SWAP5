#!/usr/bin/env python3
import math, pathlib, sys
rows=[]
vapor_rows=[]
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    q=line.split()
    if q[0]=="V":
        vapor_rows.append((int(q[1]),*map(float,q[2:])))
    else:
        rows.append((int(q[0]),*map(float,q[1:])))
C=[0.0]*22
C[1]=0.06; C[2]=0.44; C[3]=12.5; C[4]=0.018; C[5]=0.45; C[6]=1.62; C[7]=1-1/C[6]
C[13]=0.0035; C[14]=1.35; C[15]=1-1/C[14]; C[16]=0.63; C[17]=0.37
C[18]=1e6; C[19]=1e2; C[20]=-1.5; C[21]=0.04

def m2(h):
    th=max(1.0000001*C[1],C[1]+(C[2]-C[1])*math.exp(C[4]*h))
    cap=C[4]*(C[2]-C[1])*math.exp(C[4]*h)
    return th,C[3]*(th-C[1])/(C[2]-C[1]),cap

def calc(model,h):
    tr,ts,ks,a1,l,n1,m1=C[1],C[2],C[3],C[4],C[5],C[6],C[7]
    a2,n2,m2,w1,w2=C[13],C[14],C[15],C[16],C[17]
    h0,ha,apar,ok=C[18],C[19],C[20],C[21]
    ah=abs(h); g1=(1+(a1*ah)**n1)**(-m1)
    cp1=a1*n1*m1*(a1*ah)**(n1-1)*(1+(a1*ah)**n1)**(-m1-1)
    g2=(1+(a2*ah)**n2)**(-m2); cp2=a2*n2*m2*(a2*ah)**(n2-1)*(1+(a2*ah)**n2)**(-m2-1)
    if model==3:
      s=w1*g1+w2*g2; th=tr+(ts-tr)*s
      a=w1*a1*(1-g1**(1/m1))**m1+w2*a2*(1-g2**(1/m2))**m2
      return th,ks*s**l*(1-a/(w1*a1+w2*a2))**2,(ts-tr)*(w1*cp1+w2*cp2)
    if model==5:
      g01=(1+(a1*h0)**n1)**(-m1); s=(g1-g01)/(1-g01)
      th=tr+(ts-tr)*s
      k=ks*s**l*(1-((1-g1**(1/m1))/(1-g01**(1/m1)))**m1)**2
      return th,k,(ts-tr)*cp1/(1-g01)
    if model==6:
      s=w1*g1+w2*g2; th=tr+(ts-tr)*s
      a=w1*a1*(1-g1**(1/m1))**m1+w2*a2*(1-g2**(1/m2))**m2
      return th,ks*s**l*(1-a/(w1*a1+w2*a2))**2,(ts-tr)*(w1*cp1+w2*cp2)
    if model==7:
      g01=(1+(a1*h0)**n1)**(-m1); g02=(1+(a2*h0)**n2)**(-m2)
      s=(w1*g1+w2*g2-w1*g01-w2*g02)/(1-w1*g01-w2*g02); th=tr+(ts-tr)*s
      sA=(g1-g01)/(1-g01); sB=(g2-g02)/(1-g02)
      a=w1*a1*(1-g1**(1/m1))**m1+w2*a2*(1-g2**(1/m2))**m2
      b=w1*a1*(1-g01**(1/m1))**m1+w2*a2*(1-g02**(1/m2))**m2
      k=ks*(w1*sA+w2*sB)**l*(1-a/b)**2
      return th,k,(ts-tr)*(w1*cp1+w2*cp2)/(1-w1*g01-w2*g02)
    nn=n2 if model in (10,11) and a2>a1 else n1
    bb=0.1+0.2/nn**2*(1-math.exp(-((tr/(ts-tr))**2)))
    xa=math.log10(ha); x0=math.log10(h0); x=math.log10(ah)
    sad=1+(x-xa+bb*math.log(1+math.exp((xa-x)/bb)))/(xa-x0)
    ds=-1/(ah*math.log(10)*(xa-x0)*(1+math.exp((xa-x)/bb)))
    if model==8:
      s=g1; kc=s**l*(1-(1-s**(1/m1))**m1)**2; cp=(ts-tr)*cp1+tr*ds
    elif model==9:
      g01=(1+(a1*h0)**n1)**(-m1); s=(g1-g01)/(1-g01)
      kc=s**l*(1-((1-g1**(1/m1))/(1-g01**(1/m1)))**m1)**2; cp=(ts-tr)*cp1/(1-g01)+tr*ds
    elif model==10:
      s=w1*g1+w2*g2
      a=w1*a1*(1-g1**(1/m1))**m1+w2*a2*(1-g2**(1/m2))**m2
      kc=s**l*(1-a/(w1*a1+w2*a2))**2; cp=(ts-tr)*(w1*cp1+w2*cp2)+tr*ds
    else:
      g01=(1+(a1*h0)**n1)**(-m1); g02=(1+(a2*h0)**n2)**(-m2)
      s=(w1*g1+w2*g2-w1*g01-w2*g02)/(1-w1*g01-w2*g02)
      sA=(g1-g01)/(1-g01); sB=(g2-g02)/(1-g02)
      a=w1*a1*(1-g1**(1/m1))**m1+w2*a2*(1-g2**(1/m2))**m2
      b=w1*a1*(1-g01**(1/m1))**m1+w2*a2*(1-g02**(1/m2))**m2
      kc=(w1*sA+w2*sB)**l*(1-a/b)**2
      cp=(ts-tr)*(w1*cp1+w2*cp2)/(1-w1*g01-w2*g02)+tr*ds
    th=tr*sad+s*(ts-tr)
    return th,ks*((1-ok)*kc+ok*(h0/ha)**(apar*(1-sad))),cp

for model,h,th,k,cap,dk in rows:
    exp=(0.25,1.25,0.005) if model==1 else (m2(h) if model==2 else calc(model,h))
    for name,a,b in zip(("theta","K","C"),(th,k,cap),exp):
      scale=max(1.0,abs(a),abs(b))
      if abs(a-b)>2e-12*scale:
        raise SystemExit(f"model {model} {name} mismatch: got={a} expected={b}")
    if dk!=0.0: raise SystemExit(f"model {model} unexpected dKdh {dk}")

base_by_model={model:(th,k) for model,h,th,k,cap,dk in rows}
if [r[0] for r in vapor_rows] != [8,9,10,11]:
    raise SystemExit(f"unexpected PDI vapor rows: {[r[0] for r in vapor_rows]}")
mg_r=0.018015*9.81/8.314
tk=20.0+273.15
mg_rt=mg_r/tk
da=2.14e-5*(tk/273.15)**2
rho_sv=1e-3*math.exp(31.3716-6014.79/tk-7.92495e-3*tk)/tk
f_kvap=rho_sv/1000.0*mg_rt
conv=100.0*86400.0
for model,theta_v,k_v,delta in vapor_rows:
    theta0,k0=base_by_model[model]
    air=C[2]-theta0
    expected=f_kvap*(air**(7.0/3.0+1.0)/C[2]**2)*da*math.exp(-100.0/100.0*mg_rt)*conv
    scale=max(1.0,abs(delta),abs(expected))
    if abs(theta_v-theta0)>2e-12*max(1.0,abs(theta_v),abs(theta0)):
        raise SystemExit(f"model {model} vapor changed retention")
    if abs(delta-expected)>2e-12*scale:
        raise SystemExit(f"model {model} vapor mismatch: got={delta} expected={expected}")
    if abs(k_v-(k0+expected))>2e-12*max(1.0,abs(k_v),abs(k0+expected)):
        raise SystemExit(f"model {model} total K mismatch")
print("B111_PDI_VAPOR_SW009_ORACLE=PASS")
print("B111_HYDRAULIC_FAMILIES_ORACLE=PASS")
