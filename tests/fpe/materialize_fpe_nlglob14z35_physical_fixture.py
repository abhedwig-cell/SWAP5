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
    return m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1.0+abs(m["alpha"]*h)**m["n"])**mm)

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

def top_flux(h):
    fixed=kval(h)
    katm=kval(hatm)
    emax=-0.5*(katm+fixed)*((hatm-h)/dtop+1.0)
    return min(demand,max(0.0,emax))

def gauss(a,b):
    n=len(b); a=[row[:] for row in a]; b=b[:]
    for i in range(n):
        p=max(range(i,n),key=lambda r:abs(a[r][i]))
        if abs(a[p][i])<1e-18: raise ArithmeticError("singular")
        if p!=i:
            a[i],a[p]=a[p],a[i]; b[i],b[p]=b[p],b[i]
        piv=a[i][i]
        for r in range(i+1,n):
            fac=a[r][i]/piv
            if fac==0.0: continue
            for c in range(i,n): a[r][c]-=fac*a[i][c]
            b[r]-=fac*b[i]
    x=[0.0]*n
    for i in range(n-1,-1,-1):
        x[i]=(b[i]-sum(a[i][j]*x[j] for j in range(i+1,n)))/a[i][i]
    return x

h0=[-120.0+10.0*i for i in range(16)]
th0=[theta(x) for x in h0]

def solve_full():
    upper_n=12
    q0=fluxes(h0); qt0=top_flux(h0[0])
    td0=[]
    for node in range(1,17):
        if node==1: v=(q0[2]-qt0)/dz
        elif node==16: v=(qbot-q0[16])/dz
        else: v=(q0[node+1]-q0[node])/dz
        td0.append(v)
    h=h0[:]
    for i in range(upper_n):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        cap=(theta(h0[i]+eps)-theta(h0[i]-eps))/(2.0*eps)
        if cap>1e-14: h[i]+=dt*td0[i]/cap
    def residual(x):
        th1=[theta(v) for v in x]; q1=fluxes(x); qt1=top_flux(x[0])
        td1=[]
        for node in range(1,17):
            if node==1: v=(q1[2]-qt1)/dz
            elif node==16: v=(qbot-q1[16])/dz
            else: v=(q1[node+1]-q1[node])/dz
            td1.append(v)
        r=[0.0]*16
        for i in range(upper_n):
            r[i]=th1[i]-th0[i]-0.5*dt*(td0[i]+td1[i])
        qbar=0.5*(q0[13]+q1[13])
        j=12
        r[j]=th1[j]-th0[j]-dt*((q1[j+2]-qbar)/dz)
        for i in range(j+1,15):
            r[i]=th1[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
        r[15]=th1[15]-th0[15]-dt*((qbot-q1[16])/dz)
        return r,th1,q1,qt1
    best=None
    for it in range(1,31):
        r,th1,q1,qt1=residual(h)
        norm=max(abs(v) for v in r)
        best=(h[:],th1,q1,qt0,qt1,it,norm)
        if norm<=1e-10: return best
        jac=[[0.0]*16 for _ in range(16)]
        for j in range(16):
            eps=max(1e-7,1e-6*max(1.0,abs(h[j])))
            hp=h[:]; hp[j]+=eps
            rp=residual(hp)[0]
            for i in range(16): jac[i][j]=(rp[i]-r[i])/eps
        dx=gauss(jac,[-v for v in r])
        base=norm; accepted=False
        for bt in range(12):
            fac=0.5**bt
            trial=[h[i]+fac*dx[i] for i in range(16)]
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                h=trial; accepted=True; break
        if not accepted: raise SystemExit("Z35 full no descent")
    raise SystemExit("Z35 full maxit")

def solve_reduced():
    n=13; upper_n=12
    q0=fluxes(h0); qt0=top_flux(h0[0])
    td0=[]
    for node in range(1,17):
        if node==1: v=(q0[2]-qt0)/dz
        elif node==16: v=(qbot-q0[16])/dz
        else: v=(q0[node+1]-q0[node])/dz
        td0.append(v)
    x=h0[:n]
    for i in range(upper_n):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        cap=(theta(h0[i]+eps)-theta(h0[i]-eps))/(2.0*eps)
        if cap>1e-14: x[i]+=dt*td0[i]/cap
    def reconstruct(xv):
        h=xv[:] + [0.0]*(16-n)
        kg=kval(h[n-1]); km=0.5*(kg+m["ksat"])
        h[n]=h[n-1]+dz*(1.0+qbot/km)
        for i in range(n+1,16): h[i]=h[i-1]+dz*(1.0+qbot/m["ksat"])
        return h
    def residual(xv):
        h=reconstruct(xv); th1=[theta(v) for v in h]; q1=fluxes(h); qt1=top_flux(h[0])
        td1=[]
        for node in range(1,17):
            if node==1: v=(q1[2]-qt1)/dz
            elif node==16: v=(qbot-q1[16])/dz
            else: v=(q1[node+1]-q1[node])/dz
            td1.append(v)
        r=[0.0]*n
        for i in range(upper_n):
            r[i]=th1[i]-th0[i]-0.5*dt*(td0[i]+td1[i])
        qbar=0.5*(q0[13]+q1[13])
        r[12]=th1[12]-th0[12]-dt*((qbot-qbar)/dz)
        return r,h,th1,q1,qt1
    best=None
    for it in range(1,31):
        r,h,th1,q1,qt1=residual(x)
        norm=max(abs(v) for v in r)
        best=(h,th1,q1,qt0,qt1,it,norm)
        if norm<=1e-10: return best
        jac=[[0.0]*n for _ in range(n)]
        for j in range(n):
            eps=max(1e-7,1e-6*max(1.0,abs(x[j])))
            xp=x[:]; xp[j]+=eps
            rp=residual(xp)[0]
            for i in range(n): jac[i][j]=(rp[i]-r[i])/eps
        dx=gauss(jac,[-v for v in r])
        base=norm; accepted=False
        for bt in range(12):
            fac=0.5**bt
            trial=[x[i]+fac*dx[i] for i in range(n)]
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                x=trial; accepted=True; break
        if not accepted: raise SystemExit("Z35 reduced no descent")
    raise SystemExit("Z35 reduced maxit")

full_h,full_th,full_q,qtop0,qtop1,full_it,full_norm=solve_full()
red_h,red_th,red_q,rqtop0,rqtop1,red_it,red_norm=solve_reduced()
full_ledger=sum((full_th[i]-th0[i])*dz for i in range(16))+0.5*dt*(qtop0+qtop1)
red_ledger=sum((red_th[i]-th0[i])*dz for i in range(16))+0.5*dt*(rqtop0+rqtop1)
max_h=max(abs(a-b) for a,b in zip(full_h,red_h))
max_th=max(abs(a-b) for a,b in zip(full_th,red_th))
top_diff=abs(qtop1-rqtop1)
ledger_diff=abs(full_ledger-red_ledger)

assert full_norm<=1e-10 and red_norm<=1e-10
assert max_h<=5e-7 and max_th<=5e-10
assert top_diff<=5e-10 and ledger_diff<=5e-8

def fvals(vals):
    chunks=[]
    for i in range(0,len(vals),4):
        chunks.append(", ".join(f"{x:.17e}_real64" for x in vals[i:i+4]))
    return ", &\n       ".join(chunks)

src=f"""module mod_fpe_nlglob14z35_fixture
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: z35_full_nodes=16, z35_active_nodes=13
  real(real64), parameter :: z35_origin_h(16)=[{fvals(h0)}]
  real(real64), parameter :: z35_origin_th(16)=[{fvals(th0)}]
  real(real64), parameter :: z35_full_h(16)=[{fvals(full_h)}]
  real(real64), parameter :: z35_full_th(16)=[{fvals(full_th)}]
  real(real64), parameter :: z35_reduced_h(13)=[{fvals(red_h[:13])}]
  real(real64), parameter :: z35_reduced_th(13)=[{fvals(red_th[:13])}]
  real(real64), parameter :: z35_tail_h(3)=[{fvals(red_h[13:])}]
  real(real64), parameter :: z35_tail_th(3)=[{fvals(red_th[13:])}]
  real(real64), parameter :: z35_top_flux={rqtop1:.17e}_real64
  real(real64), parameter :: z35_full_ledger={full_ledger:.17e}_real64
  real(real64), parameter :: z35_reduced_ledger={red_ledger:.17e}_real64
  real(real64), parameter :: z35_full_residual={full_norm:.17e}_real64
  real(real64), parameter :: z35_reduced_residual={red_norm:.17e}_real64
  integer, parameter :: z35_full_iterations={full_it}, z35_reduced_iterations={red_it}
end module mod_fpe_nlglob14z35_fixture
"""
OUT.write_text(src)
print(f"F_PE_NLGLOB14Z35_PHYSICS|MAX_H_DIFF={max_h:.17e}|MAX_THETA_DIFF={max_th:.17e}|TOP_DIFF={top_diff:.17e}|LEDGER_DIFF={ledger_diff:.17e}|FULL_RES={full_norm:.17e}|RED_RES={red_norm:.17e}|FULL_IT={full_it}|RED_IT={red_it}")
print("F_PE_NLGLOB14Z35_PHYSICS=PASS")
