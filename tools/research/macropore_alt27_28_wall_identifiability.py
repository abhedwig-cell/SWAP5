#!/usr/bin/env python3
"""F-MACRO-ALT27_28: reduced wall-exchange identifiability screen."""
from __future__ import annotations
import json, math

EVENTS = [
    ('very_dry', 18.0, 0.0002, 300.0, 0.02, 0.10),
    ('dry', 13.0, 0.02, 150.0, 0.05, 0.20),
    ('moderate', 7.0, 0.8, 60.0, 0.10, 0.30),
    ('wet', 2.0, 8.0, 20.0, 0.20, 0.30),
    ('very_wet', 0.5, 25.0, 8.0, 0.20, 0.30),
]
BASE = {'chi_wall': 0.5, 'ell_ex': 20.0, 'f_shape': 1.0}

def event_exchange(event, p):
    _, S, K, dh, age, duration = event
    droot = math.sqrt(age + duration) - math.sqrt(age)
    q_philip = p['chi_wall'] * (4.0 / p['ell_ex']) * S * droot
    q_darcy = p['f_shape'] * 8.0 * K * dh / (p['ell_ex']**2) * duration
    return max(q_philip, q_darcy), q_philip, q_darcy

def outputs(p, subset=None):
    ev = EVENTS if subset is None else [e for e in EVENTS if e[0] in subset]
    return [event_exchange(e, p)[0] for e in ev]

def dot(a,b): return sum(x*y for x,y in zip(a,b))
def norm(a): return math.sqrt(dot(a,a))
def corr(a,b):
    na, nb = norm(a), norm(b)
    return dot(a,b)/(na*nb) if na and nb else 0.0

def jacobi_eigs(m, sweeps=100):
    a=[r[:] for r in m]; n=len(a)
    for _ in range(sweeps):
        p=q=0; best=0.0
        for i in range(n):
            for j in range(i+1,n):
                if abs(a[i][j]) > best: best=abs(a[i][j]); p=i; q=j
        if best < 1e-14: break
        app,aqq,apq=a[p][p],a[q][q],a[p][q]
        phi=0.5*math.atan2(2*apq,aqq-app); c=math.cos(phi); s=math.sin(phi)
        for k in range(n):
            if k!=p and k!=q:
                akp,akq=a[k][p],a[k][q]
                a[k][p]=a[p][k]=c*akp-s*akq
                a[k][q]=a[q][k]=s*akp+c*akq
        a[p][p]=c*c*app-2*s*c*apq+s*s*aqq
        a[q][q]=s*s*app+2*s*c*apq+c*c*aqq
        a[p][q]=a[q][p]=0.0
    return sorted((a[i][i] for i in range(n)), reverse=True)

def singular_values(cols):
    g=[[dot(cols[i],cols[j]) for j in range(len(cols))] for i in range(len(cols))]
    return [math.sqrt(max(0.0,e)) for e in jacobi_eigs(g)]

def sensitivities(names, subset=None):
    eps=0.01; cols=[]
    for name in names:
        pp=dict(BASE); pm=dict(BASE)
        pp[name]*=1+eps; pm[name]*=1-eps
        yp=outputs(pp,subset); ym=outputs(pm,subset)
        cols.append([(a-b)/(2*eps) for a,b in zip(yp,ym)])
    sv=singular_values(cols)
    return {
        'parameters': names,
        'correlations': {names[i]: {names[j]: corr(cols[i],cols[j]) for j in range(len(names))} for i in range(len(names))},
        'singular_values': sv,
        'condition_number': (sv[0]/sv[-1] if sv[-1] > 1e-12 else None),
        'effective_rank': sum(v > sv[0]*1e-6 for v in sv)
    }

def main():
    regimes=[]
    for e in EVENTS:
        total, qp, qd = event_exchange(e, BASE)
        regimes.append({'name':e[0], 'q_philip':qp, 'q_darcy':qd, 'selected':'philip' if qp>=qd else 'darcy', 'q_selected':total})
    print(json.dumps({
        'schema':'swap5.f_macro_alt27_28.wall_exchange_identifiability.v1',
        'status':'RESEARCH_ONLY',
        'regimes':regimes,
        'two_parameter_all_regimes':sensitivities(['chi_wall','ell_ex']),
        'three_parameter_all_regimes':sensitivities(['chi_wall','ell_ex','f_shape']),
        'dry_only_two_parameter':sensitivities(['chi_wall','ell_ex'], {'very_dry','dry'}),
        'decision':{
            'empirical_sorptivity_pair':'remove from leading RFM',
            'f_shape':'fix or derive',
            'remaining_wall_core':['chi_wall','ell_ex']
        }
    }, indent=2, sort_keys=True))

if __name__ == '__main__': main()
