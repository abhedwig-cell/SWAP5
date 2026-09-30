#!/usr/bin/env python3
import math
import sys
from pathlib import Path

OUT=Path(sys.argv[1])
m={"theta_r":0.01,"theta_s":0.336701,"alpha":0.030304,"n":2.887502,"ksat":17.418504,"lambda":0.0736}
dz=10.0
dt=6.25e-5
demand=0.01
qbot=0.0
dtop=10.0
hatm=-2.75e5

def theta(h):
    if h>=0.0: return m["theta_s"]
    mm=1.0-1.0/m["n"]; hcrit=-1e-2
    if h>hcrit:
        c26=m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1.0+abs(m["alpha"]*hcrit)**m["n"])**mm)
        c27=(m["theta_s"]-c26)/(-hcrit)
        return min(c26+c27*(h-hcrit),m["theta_s"])
    return m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1.0+abs(m["alpha"]*h))**m["n"])**mm)

def kval(h):
    th=theta(h)
    rel=(th-m["theta_r"])/(m["theta_s"]-m["theta_r"])
    if rel>1.0-1e-6: return m["ksat"]
    if rel<=0.0: return 0.0
    mm=1.0-1.0/m["n"]
    term=(1.0-rel**(1.0/mm))**mm
    return min(m["ksat"]*(rel**m["lambda"])*(1.0-term)**2,m["ksat"])

def fluxes(h):
    k=[kval(x) for x in h]
    q=[None]*17
    for j in range(1,16):
        km=0.5*(k[j-1]+k[j])
        q[j+1]=-km*((h[j-1]-h[j])/dz+1.0)
    return q

def top_flux(h0):
    fixed=kval(h0)
    katm=kval(hatm)
    emax=-0.5*(katm+fixed)*((hatm-h0)/dtop+1.0)
    evap=min(demand,max(0.0,emax))
    if evap>=0.0 and evap>emax:
        return emax,"atmospheric-head",emax
    return evap,"surface-flux",emax

def gauss(a,b):
    n=len(b); a=[r[:] for r in a]; b=b[:]
    for i in range(n):
        p=max(range(i,n),key=lambda r:abs(a[r][i]))
        if abs(a[p][i])<1e-18:
            raise ArithmeticError("singular")
        if p!=i:
            a[i],a[p]=a[p],a[i]
            b[i],b[p]=b[p],b[i]
        piv=a[i][i]
        for r in range(i+1,n):
            f=a[r][i]/piv
            if f==0.0: continue
            for c in range(i,n):
                a[r][c]-=f*a[i][c]
            b[r]-=f*b[i]
    x=[0.0]*n
    for i in range(n-1,-1,-1):
        x[i]=(b[i]-sum(a[i][j]*x[j] for j in range(i+1,n)))/a[i][i]
    return x

def sat_tail(h,th):
    sat=[h[i]>=0.0 and th[i]==m["theta_s"] for i in range(16)]
    first=16
    while first>0 and sat[first-1]:
        first-=1
    if any(sat[:first]):
        return None
    return list(range(first+1,17))

def solve_full(h0,th0):
    upper_n=12
    q0=fluxes(h0)
    qtop0,route0,emax0=top_flux(h0[0])

    def endpoint(x):
        th1=[theta(v) for v in x]
        q1=fluxes(x)
        qtop1,route1,emax1=top_flux(x[0])
        return th1,q1,qtop1,route1,emax1

    td0=[]
    for node in range(1,17):
        if node==1: v=(q0[2]-qtop0)/dz
        elif node==16: v=(qbot-q0[16])/dz
        else: v=(q0[node+1]-q0[node])/dz
        td0.append(v)

    h=h0[:]
    for i in range(upper_n):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        c=(theta(h0[i]+eps)-theta(h0[i]-eps))/(2*eps)
        if c>1e-14:
            h[i]+=dt*td0[i]/c

    iface=upper_n+1
    def residual(x):
        th1,q1,qtop1,route1,emax1=endpoint(x)
        td1=[]
        for node in range(1,17):
            if node==1: v=(q1[2]-qtop1)/dz
            elif node==16: v=(qbot-q1[16])/dz
            else: v=(q1[node+1]-q1[node])/dz
            td1.append(v)
        r=[0.0]*16
        for i in range(upper_n):
            r[i]=th1[i]-th0[i]-0.5*dt*(td0[i]+td1[i])
        qbar=0.5*(q0[iface]+q1[iface])
        j=upper_n
        r[j]=th1[j]-th0[j]-dt*((q1[j+2]-qbar)/dz)
        for i in range(j+1,15):
            r[i]=th1[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
        r[15]=th1[15]-th0[15]-dt*((qbot-q1[16])/dz)
        return r,th1,q1,qtop1,route1,emax1,qbar

    best=None
    for it in range(1,31):
        r,th1,q1,qtop1,route1,emax1,qbar=residual(h)
        norm=max(abs(v) for v in r)
        best=(h[:],th1,q1,qtop0,qtop1,route0,route1,it,norm)
        if norm<=1e-10:
            return best,True
        jac=[[0.0]*16 for _ in range(16)]
        for j in range(16):
            eps=max(1e-7,1e-6*max(1.0,abs(h[j])))
            hp=h[:]; hp[j]+=eps
            rp=residual(hp)[0]
            for i in range(16):
                jac[i][j]=(rp[i]-r[i])/eps
        dx=gauss(jac,[-v for v in r])
        base=norm
        accepted=False
        for bt in range(12):
            fac=0.5**bt
            trial=[h[i]+fac*dx[i] for i in range(16)]
            if not all(math.isfinite(v) and abs(v)<1e12 for v in trial):
                continue
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                h=trial
                accepted=True
                break
        if not accepted:
            break
    return best,False

def solve_reduced(h0,th0):
    n=13
    q0=fluxes(h0)
    qtop0,route0,emax0=top_flux(h0[0])

    def reconstruct(x):
        h=x[:] + [0.0]*(16-n)
        kg=kval(h[n-1])
        km=0.5*(kg+m["ksat"])
        h[n]=h[n-1]+dz*(1.0+qbot/km)
        for i in range(n+1,16):
            h[i]=h[i-1]+dz*(1.0+qbot/m["ksat"])
        return h

    def endpoint(x):
        hfull=reconstruct(x)
        th1=[theta(v) for v in hfull]
        q1=fluxes(hfull)
        qtop1,route1,emax1=top_flux(hfull[0])
        return hfull,th1,q1,qtop1,route1,emax1

    td0=[]
    for node in range(1,17):
        if node==1: v=(q0[2]-qtop0)/dz
        elif node==16: v=(qbot-q0[16])/dz
        else: v=(q0[node+1]-q0[node])/dz
        td0.append(v)

    x=h0[:n]
    for i in range(n-1):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        c=(theta(h0[i]+eps)-theta(h0[i]-eps))/(2*eps)
        if c>1e-14:
            x[i]+=dt*td0[i]/c

    iface=n
    def residual(xv):
        hfull,th1,q1,qtop1,route1,emax1=endpoint(xv)
        td1=[]
        for node in range(1,17):
            if node==1: v=(q1[2]-qtop1)/dz
            elif node==16: v=(qbot-q1[16])/dz
            else: v=(q1[node+1]-q1[node])/dz
            td1.append(v)
        r=[0.0]*n
        for i in range(n-1):
            r[i]=th1[i]-th0[i]-0.5*dt*(td0[i]+td1[i])
        qbar=0.5*(q0[iface]+q1[iface])
        r[n-1]=th1[n-1]-th0[n-1]-dt*((qbot-qbar)/dz)
        return r,hfull,th1,q1,qtop1,route1,emax1,qbar

    best=None
    for it in range(1,31):
        r,hfull,th1,q1,qtop1,route1,emax1,qbar=residual(x)
        norm=max(abs(v) for v in r)
        best=(hfull,th1,q1,qtop0,qtop1,route0,route1,it,norm,n)
        if norm<=1e-10:
            return best,True
        jac=[[0.0]*n for _ in range(n)]
        for j in range(n):
            eps=max(1e-7,1e-6*max(1.0,abs(x[j])))
            xp=x[:]; xp[j]+=eps
            rp=residual(xp)[0]
            for i in range(n):
                jac[i][j]=(rp[i]-r[i])/eps
        dx=gauss(jac,[-v for v in r])
        base=norm
        accepted=False
        for bt in range(12):
            fac=0.5**bt
            trial=[x[i]+fac*dx[i] for i in range(n)]
            if not all(math.isfinite(v) and abs(v)<1e12 for v in trial):
                continue
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                x=trial
                accepted=True
                break
        if not accepted:
            break
    return best,False

h0=[-120.0+10.0*i for i in range(16)]
th0=[theta(x) for x in h0]
assert sat_tail(h0,th0)==[13,14,15,16]

full,full_ok=solve_full(h0,th0)
red,red_ok=solve_reduced(h0,th0)
assert full is not None and red is not None and full_ok and red_ok

full_h,full_th,full_q,qtop0,qtop1,route0,route1,full_it,full_norm=full
red_h,red_th,red_q,rqtop0,rqtop1,rroute0,rroute1,red_it,red_norm,red_n=red

full_ledger=sum((full_th[i]-th0[i])*dz for i in range(16))+0.5*dt*(qtop0+qtop1)
red_ledger=sum((red_th[i]-th0[i])*dz for i in range(16))+0.5*dt*(rqtop0+rqtop1)
max_h=max(abs(a-b) for a,b in zip(full_h,red_h))
max_th=max(abs(a-b) for a,b in zip(full_th,red_th))
top_diff=abs(qtop1-rqtop1)
ledger_diff=abs(full_ledger-red_ledger)

assert max_h <= 5e-7
assert max_th <= 5e-10
assert top_diff <= 5e-10
assert ledger_diff <= 5e-8
assert sat_tail(full_h,full_th)==sat_tail(red_h,red_th)
assert route0==rroute0 and route1==rroute1

def arr(vals):
    return ", ".join(f"{x:.17e}_real64" for x in vals)

src=f"""module mod_fpe_nlglob14z35_fixture
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: z35_full_nodes=16, z35_active_nodes=13
  real(real64), parameter :: z35_origin_h(16)=[{arr(h0)}]
  real(real64), parameter :: z35_origin_th(16)=[{arr(th0)}]
  real(real64), parameter :: z35_full_h(16)=[{arr(full_h)}]
  real(real64), parameter :: z35_full_th(16)=[{arr(full_th)}]
  real(real64), parameter :: z35_reduced_h(13)=[{arr(red_h[:13])}]
  real(real64), parameter :: z35_reduced_th(13)=[{arr(red_th[:13])}]
  real(real64), parameter :: z35_tail_h(3)=[{arr(red_h[13:])}]
  real(real64), parameter :: z35_tail_th(3)=[{arr(red_th[13:])}]
  real(real64), parameter :: z35_top_flux={rqtop1:.17e}_real64
  real(real64), parameter :: z35_full_ledger={full_ledger:.17e}_real64
  real(real64), parameter :: z35_reduced_ledger={red_ledger:.17e}_real64
  real(real64), parameter :: z35_full_residual={full_norm:.17e}_real64
  real(real64), parameter :: z35_reduced_residual={red_norm:.17e}_real64
  integer, parameter :: z35_full_iterations={full_it}, z35_reduced_iterations={red_it}
  real(real64), parameter :: z35_work_ratio={red_it*red_n/(full_it*16.0):.17e}_real64
end module mod_fpe_nlglob14z35_fixture
"""
OUT.write_text(src)
print(f"F_PE_NLGLOB14Z35_PHYSICS|MAX_H_DIFF={max_h:.17e}|MAX_THETA_DIFF={max_th:.17e}|TOP_DIFF={top_diff:.17e}|LEDGER_DIFF={ledger_diff:.17e}|FULL_RES={full_norm:.17e}|RED_RES={red_norm:.17e}|WORK_RATIO={red_it*red_n/(full_it*16.0):.17e}")
print("F_PE_NLGLOB14Z35_PHYSICS=PASS")
