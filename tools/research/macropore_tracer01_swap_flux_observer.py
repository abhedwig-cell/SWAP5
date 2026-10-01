#!/usr/bin/env python3
"""F-MACRO-TRACER01-C: accepted SWAP5 1D water-transfer observer.

Research-only. Reconstructs net interface water transfers from accepted storage
changes and the documented SWAP upward-positive q convention.
"""
from __future__ import annotations
from dataclasses import dataclass
import json
import math

TOL = 1.0e-10

@dataclass(frozen=True)
class HydrologyTransfer:
    water_cm: float
    donor: int | None
    receiver: int | None
    label: str

@dataclass(frozen=True)
class ObserverResult:
    valid: bool
    reason: str
    interface_flux_cm_per_day: tuple[float, ...]
    transfers: tuple[HydrologyTransfer, ...]
    reconstructed_bottom_flux_cm_per_day: float
    bottom_flux_residual_cm_per_day: float

def reconstruct_accepted_transfers(start_theta, end_theta, dz_cm, dt_day, qtop, qbot, source=None, sink=None):
    n=len(start_theta)
    if n<=0 or len(end_theta)!=n or len(dz_cm)!=n:
        return ObserverResult(False,'shape mismatch',tuple(),tuple(),math.nan,math.nan)
    if not math.isfinite(dt_day) or dt_day<=0:
        return ObserverResult(False,'invalid dt',tuple(),tuple(),math.nan,math.nan)
    vals=list(start_theta)+list(end_theta)+list(dz_cm)+[qtop,qbot]
    if any(not math.isfinite(x) for x in vals):
        return ObserverResult(False,'non-finite input',tuple(),tuple(),math.nan,math.nan)
    if any(x<0 for x in start_theta) or any(x<0 for x in end_theta) or any(x<=0 for x in dz_cm):
        return ObserverResult(False,'invalid state/storage geometry',tuple(),tuple(),math.nan,math.nan)
    if source is None: source=[0.0]*n
    if sink is None: sink=[0.0]*n
    if len(source)!=n or len(sink)!=n:
        return ObserverResult(False,'source/sink shape mismatch',tuple(),tuple(),math.nan,math.nan)
    if any((not math.isfinite(x) or x<0) for x in list(source)+list(sink)):
        return ObserverResult(False,'invalid source/sink',tuple(),tuple(),math.nan,math.nan)

    # q is positive upward. For layer i:
    # dS/dt = q_lower - q_upper + source - sink.
    q_interfaces=[]
    q_upper=qtop
    for i in range(n):
        delta_storage=(end_theta[i]-start_theta[i])*dz_cm[i]
        q_lower=q_upper + delta_storage/dt_day - source[i] + sink[i]
        q_interfaces.append(q_lower)
        q_upper=q_lower

    residual=q_interfaces[-1]-qbot
    scale=max(1.0,abs(qbot),abs(q_interfaces[-1]))
    if abs(residual)>TOL*scale:
        return ObserverResult(False,'bottom flux does not close reconstructed layer balances',tuple(q_interfaces),tuple(),q_interfaces[-1],residual)

    transfers=[]
    # External top boundary.
    if qtop<0:
        transfers.append(HydrologyTransfer(-qtop*dt_day,None,0,'top-inflow'))
    elif qtop>0:
        transfers.append(HydrologyTransfer(qtop*dt_day,0,None,'top-outflow'))

    # Distributed external sources are placed before internal movement.
    for i,x in enumerate(source):
        if x>0:
            transfers.append(HydrologyTransfer(x*dt_day,None,i,f'source-{i+1}'))

    # Downward interfaces top-to-bottom, then upward bottom-to-top.
    for i,q in enumerate(q_interfaces[:-1]):
        if q<0:
            transfers.append(HydrologyTransfer(-q*dt_day,i,i+1,f'interface-{i+1}-down'))
    for i in range(n-2,-1,-1):
        q=q_interfaces[i]
        if q>0:
            transfers.append(HydrologyTransfer(q*dt_day,i+1,i,f'interface-{i+1}-up'))

    # Distributed sinks and bottom export/inflow.
    for i,x in enumerate(sink):
        if x>0:
            transfers.append(HydrologyTransfer(x*dt_day,i,None,f'sink-{i+1}'))
    if qbot<0:
        transfers.append(HydrologyTransfer(-qbot*dt_day,n-1,None,'bottom-outflow'))
    elif qbot>0:
        transfers.append(HydrologyTransfer(qbot*dt_day,None,n-1,'bottom-inflow'))

    return ObserverResult(True,'OBSERVER_VALID',tuple(q_interfaces),tuple(transfers),q_interfaces[-1],residual)

def _demo():
    start=(0.20,0.20,0.20)
    dz=(10.0,10.0,10.0)
    dt=0.1
    # imposed q: top=-1.0, int1=-0.8, int2=-0.5, bottom=-0.2 cm/day
    end=(
        start[0]+(-0.8-(-1.0))*dt/dz[0],
        start[1]+(-0.5-(-0.8))*dt/dz[1],
        start[2]+(-0.2-(-0.5))*dt/dz[2],
    )
    r=reconstruct_accepted_transfers(start,end,dz,dt,-1.0,-0.2)
    return {'valid':r.valid,'interfaces':r.interface_flux_cm_per_day,'bottom_residual':r.bottom_flux_residual_cm_per_day,'transfers':[x.__dict__ for x in r.transfers]}

if __name__=='__main__':
    print(json.dumps({'schema':'swap5.f_macro_tracer01c.accepted_flux_observer.v1','status':'RESEARCH_ONLY','demo':_demo()},indent=2,sort_keys=True))
