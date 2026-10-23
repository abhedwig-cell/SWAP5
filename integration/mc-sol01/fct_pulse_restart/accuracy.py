"""Independent exact cell averages for a constant-coefficient reactive pulse."""
import math
import numpy as np
def reference(n):
    h=80/n;t=8.;storage=.56;q=.3
    diffusivity=(.02*.3**3.33/.423**2+.25*q)/storage
    centre=25+q/storage*t;sigma=math.sqrt(4+2*diffusivity*t)
    edges=np.arange(n+1)*h
    integral=np.array([math.erf((x-centre)/(math.sqrt(2)*sigma)) for x in edges])
    cells=1e-6*math.exp(-.05*t)+2*math.sqrt(math.pi/2)/h*math.exp(-.05*t)*np.diff(integral)
    return cells
def assess(raw,n,steps,flag):
    lines=raw.decode().splitlines();head=lines[0].split()
    assert head[0]=='PULSE_PASS' and list(map(int,head[1:4]))==[n,steps,flag]
    budget=np.array(list(map(float,head[4:])));assert len(budget)==6 and np.isfinite(budget).all() and min(budget)>=0
    rows=[l.split() for l in lines[1:]];assert len(rows)==n and [int(v[1]) for v in rows]==list(range(1,n+1))
    p=np.array([list(map(float,v[2:])) for v in rows]);assert p.shape==(n,4) and np.isfinite(p).all() and p.min()>=0
    initial,c,m,s=p.T;h=80/n
    assert max(abs(m-.3*h*c))<1e-13 and max(abs(s-.26*h*c))<1e-12
    assert max(c)<=max(initial)+1e-12
    balance=abs(sum(m+s)-budget[0]-budget[1]+budget[2]);assert balance<1e-10 and budget[4]<1e-10
    assert budget[3]>0 and budget[2]>=budget[3]
    if flag:assert budget[5]>1e-8
    else:assert budget[5]==0
    exact=reference(n);error=float(sum(abs(.56*h*(c-exact))))
    return dict(mass_l1_error=error,mass_residual=max(balance,float(budget[4])),peak_error=float(max(c)-max(exact)))
def compare(cases,read):
    results={};profiles={};worst=drift=0.
    for case in cases:
        key=(case['optimization'],case['n'],case['steps'],case['flag']);assert key not in results
        raw=read(case['stdout']);v=assess(raw,*key[1:]);results[key]=v;profiles[key]=raw
        worst=max(worst,v['mass_residual'])
    from itertools import product
    assert set(results)==set(product(['O0','O2'],[40,80,160],[80,160,320],[0,1]))
    ratios={}
    for opt,n,steps in product(['O0','O2'],[40,80,160],[80,160,320]):
        high=results[opt,n,steps,1]['mass_l1_error'];low=results[opt,n,steps,0]['mass_l1_error']
        assert high<low,('pulse correction fails accuracy',opt,n,steps,high,low)
        if opt=='O2':ratios[f'{n}/{steps}']=high/low
    for n in [40,80,160]:
        assert all(results['O2',n,a,1]['mass_l1_error']>results['O2',n,b,1]['mass_l1_error'] for a,b in [(80,160),(160,320)])
    assert all(results['O2',a,320,1]['mass_l1_error']>results['O2',b,320,1]['mass_l1_error'] for a,b in [(40,80),(80,160)])
    for key,raw in profiles.items():
        if key[0]=='O0':
            numeric=lambda b:np.array([float(x) for l in b.decode().splitlines() for x in l.split()[1:]])
            d=float(max(abs(numeric(raw)-numeric(profiles[('O2',*key[1:])]))));assert d<1e-11;drift=max(drift,d)
    return dict(status='ANALYTICAL_MOVING_PULSE_O0_O2_PASS',cases=36,max_mass_residual=worst,max_O0_O2_numeric_difference=drift,
        corrected_to_implicit_mass_l1_ratio=ratios,
        corrected_mass_l1={f'{n}/{steps}':results['O2',n,steps,1]['mass_l1_error'] for n in [40,80,160] for steps in [80,160,320]},
        qualification_scope='Linear sorption, homogeneous constant-water advection+mechanical/molecular dispersion+decay; Gaussian cell-average analytical reference. Spatial and temporal error decrease, not general nonlinear/full Richards PDE accuracy.')
