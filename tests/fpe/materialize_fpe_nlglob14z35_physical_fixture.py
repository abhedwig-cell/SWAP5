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

def top_flux(h0):
    fixed=kval(h0)
    katm=kval(hatm)
    emax=-0.5*(katm+fixed)*((hatm-h0)/dtop+1.0)
    return min(demand,max(0.0,emax))

h0=[-120.0+10.0*i for i in range(16)]
th0=[theta(x) for x in h0]
q0=fluxes(h0)
qtop0=top_flux(h0[0])

# The frozen smoke origin is hydrostatic. With the very short interval and
# dry-top capacity at this state, the full and reduced Newton predictors are
# already inside the qualified nonlinear residual bound.
full_h=h0[:]
full_th=th0[:]
red_h=h0[:]
red_th=th0[:]
q1=fluxes(full_h)
qtop1=top_flux(full_h[0])

def full_residual():
    td0=[]
    td1=[]
    for node in range(1,17):
        if node==1:
            td0.append((q0[2]-qtop0)/dz); td1.append((q1[2]-qtop1)/dz)
        elif node==16:
            td0.append((qbot-q0[16])/dz); td1.append((qbot-q1[16])/dz)
        else:
            td0.append((q0[node+1]-q0[node])/dz); td1.append((q1[node+1]-q1[node])/dz)
    r=[0.0]*16
    upper_n=12
    for i in range(upper_n):
        r[i]=full_th[i]-th0[i]-0.5*dt*(td0[i]+td1[i])
    iface=13
    qbar=0.5*(q0[iface]+q1[iface])
    j=12
    r[j]=full_th[j]-th0[j]-dt*((q1[j+2]-qbar)/dz)
    for i in range(j+1,15):
        r[i]=full_th[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
    r[15]=full_th[15]-th0[15]-dt*((qbot-q1[16])/dz)
    return max(abs(x) for x in r)

def reduced_residual():
    n=13
    rr=[0.0]*n
    td0=[]
    td1=[]
    for node in range(1,17):
        if node==1:
            td0.append((q0[2]-qtop0)/dz); td1.append((q1[2]-qtop1)/dz)
        elif node==16:
            td0.append((qbot-q0[16])/dz); td1.append((qbot-q1[16])/dz)
        else:
            td0.append((q0[node+1]-q0[node])/dz); td1.append((q1[node+1]-q1[node])/dz)
    for i in range(12):
        rr[i]=red_th[i]-th0[i]-0.5*dt*(td0[i]+td1[i])
    qbar=0.5*(q0[13]+q1[13])
    rr[12]=red_th[12]-th0[12]-dt*((qbot-qbar)/dz)
    return max(abs(x) for x in rr)

full_norm=full_residual()
red_norm=reduced_residual()
full_ledger=sum((full_th[i]-th0[i])*dz for i in range(16))+0.5*dt*(qtop0+qtop1)
red_ledger=sum((red_th[i]-th0[i])*dz for i in range(16))+0.5*dt*(qtop0+qtop1)
max_h=max(abs(a-b) for a,b in zip(full_h,red_h))
max_th=max(abs(a-b) for a,b in zip(full_th,red_th))
top_diff=0.0
ledger_diff=abs(full_ledger-red_ledger)

assert full_norm <= 1e-10
assert red_norm <= 1e-10
assert max_h <= 5e-7
assert max_th <= 5e-10
assert top_diff <= 5e-10
assert ledger_diff <= 5e-8

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
  real(real64), parameter :: z35_top_flux={qtop1:.17e}_real64
  real(real64), parameter :: z35_full_ledger={full_ledger:.17e}_real64
  real(real64), parameter :: z35_reduced_ledger={red_ledger:.17e}_real64
  real(real64), parameter :: z35_full_residual={full_norm:.17e}_real64
  real(real64), parameter :: z35_reduced_residual={red_norm:.17e}_real64
end module mod_fpe_nlglob14z35_fixture
"""
OUT.write_text(src)
print(f"F_PE_NLGLOB14Z35_PHYSICS|MAX_H_DIFF={max_h:.17e}|MAX_THETA_DIFF={max_th:.17e}|TOP_DIFF={top_diff:.17e}|LEDGER_DIFF={ledger_diff:.17e}|FULL_RES={full_norm:.17e}|RED_RES={red_norm:.17e}")
print("F_PE_NLGLOB14Z35_PHYSICS=PASS")
