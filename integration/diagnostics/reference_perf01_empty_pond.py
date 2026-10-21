"""Independent continuous finite-volume water reference for the closed dry32 case."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import time

import numpy as np
import scipy
from scipy.integrate import solve_ivp


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--prefix',type=Path,required=True)
    ap.add_argument('--continuation',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    dz = np.array([.5,.5,1.,1.,2.,3.] + [5.] * 26)
    distance = .5 * (dz[:-1] + dz[1:])
    tr,ts,ks,alpha,n,ell = .032,.423,.00475,.0135,1.455,.365
    m = 1 - 1 / n
    intensity,epot,pmax,resistance = 1.,.05,.50001,.001
    sink = np.full(32,.000025)
    times = np.arange(1,65) / 64
    theta0 = tr + (ts-tr) * (1 + (alpha*1000)**n)**(-m)
    initial = np.r_[np.full(32,theta0),0.,0.,0.]
    def constitutive(theta):
        se = (theta-tr) / (ts-tr)
        if np.any(se <= 0) or np.any(se >= 1):
            raise ValueError('independent reference outside unsaturated domain')
        head = -(se**(-1/m) - 1)**(1/n) / alpha
        conductivity = ks * se**ell * (1 - (1-se**(1/m))**m)**2
        return head,conductivity
    def rhs(t,y,ponded):
        h,k = constitutive(y[:32])
        face = .5 * (ks + k[0])
        capacity = face * (1-h[0]/.25)
        if ponded:
            infil = face * (1+(y[32]-h[0])/.25)
            evap = epot
            runoff = max(0.,(y[32]-pmax)/resistance)
            dp = intensity-evap-infil-runoff
        else:
            infil = min(intensity,capacity)
            evap = max(0.,min(epot,intensity-capacity))
            runoff,dp = 0.,0.
        internal = .5*(k[:-1]+k[1:]) * (1+(h[:-1]-h[1:])/distance)
        faces = np.r_[infil,internal,0.]
        return np.r_[(faces[:-1]-faces[1:]-sink)/dz,dp,evap,runoff]
    def onset(t,y):
        h,k = constitutive(y[:32])
        return .5*(ks+k[0])*(1-h[0]/.25)-(intensity-epot)
    onset.terminal = True
    onset.direction = -1
    references = []
    for label,rtol,atol in [('tight',1e-11,1e-14),('tighter',1e-13,1e-16)]:
        start = time.monotonic()
        dry = solve_ivp(lambda t,y:rhs(t,y,False),(0.,1.),initial,method='BDF',
                        rtol=rtol,atol=atol,max_step=.005,dense_output=True,events=onset)
        assert dry.success and len(dry.t_events[0]) == 1
        crossing = float(dry.t_events[0][0])
        wet = solve_ivp(lambda t,y:rhs(t,y,True),(crossing,1.),dry.y_events[0][0],method='BDF',
                       rtol=rtol,atol=atol,max_step=.005,dense_output=True)
        assert wet.success and wet.t[-1] == 1.
        values = np.array([dry.sol(t) if t<=crossing else wet.sol(t) for t in times])
        heads = np.array([constitutive(y[:32])[0] for y in values])
        mass = values[:,:32] @ dz + values[:,32]
        residual = mass-initial[:32]@dz-intensity*times+values[:,33]+values[:,34]+sum(sink)*times
        assert min(values[:,32]) >= -1e-12 and max(abs(residual)) < 1e-10
        records = []
        for window,(t,y,h) in enumerate(zip(times,values,heads),1):
            for node in range(32):
                records.append(dict(window=window,time=float(t),node=node+1,head=float(h[node]),theta=float(y[node]),
                    pond=float(y[32]),cumulative_evaporation=float(y[33]),cumulative_runoff=float(y[34])))
        with (out / (label+'.csv')).open('w') as f:
            writer = csv.DictWriter(f,fieldnames=list(records[0]));writer.writeheader();writer.writerows(records)
        references.append(dict(label=label,rtol=rtol,atol=atol,onset_day=crossing,seconds=time.monotonic()-start,
            nfev=dry.nfev+wet.nfev,max_water_residual=float(max(abs(residual))),values=values,heads=heads))
    x,y = references
    spread = dict(head=float(np.max(abs(x['heads']-y['heads']))),theta=float(np.max(abs(x['values'][:,:32]-y['values'][:,:32]))),
                  pond=float(np.max(abs(x['values'][:,32]-y['values'][:,32]))))
    assert spread['head'] < 1e-4 and spread['theta'] < 1e-8 and spread['pond'] < 1e-8
    native = []
    budgets = []
    inputs = {}
    for folder in [a.prefix.resolve(),a.continuation.resolve()]:
        for name in ['trajectory.csv','budget.csv']:
            p = folder / name
            inputs[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
        native.extend(csv.DictReader((folder/'trajectory.csv').read_text().splitlines()))
        budgets.extend(csv.DictReader((folder/'budget.csv').read_text().splitlines()))
    assert len(native) == 64*32 and len(budgets) == 64
    native_h = np.array([float(r['head']) for r in native]).reshape(64,32)
    native_w = np.array([float(r['theta']) for r in native]).reshape(64,32)
    # Gross native surface amounts are measured per requested window.
    native_evap = np.cumsum([float(r['pond_evaporation_cm']) for r in budgets])
    native_runoff = np.cumsum([float(r['runoff_cm']) for r in budgets])
    errors = dict(head=float(np.max(abs(native_h-y['heads']))),theta=float(np.max(abs(native_w-y['values'][:,:32]))),
                  cumulative_evaporation=float(max(abs(native_evap-y['values'][:,33]))),
                  cumulative_runoff=float(max(abs(native_runoff-y['values'][:,34]))))
    report = dict(status='INDEPENDENT_CONTINUOUS_WATER_REFERENCE_MEASURED_NOT_PRODUCTION_ADMISSION',
                  scipy=scipy.__version__,inputs=inputs,reference_spread=spread,candidate_errors=errors,
                  references=[{k:v for k,v in r.items() if k not in {'values','heads'}} for r in references],
                  exclusions='No independent chemical truth; native full/half tolerance is not a global-error bound')
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    main()
