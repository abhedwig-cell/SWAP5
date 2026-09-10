#!/usr/bin/env python3
import math

TOL = 2e-7


def close(a, b, tol=TOL):
    return abs(a-b) <= tol*max(1.0, abs(a), abs(b))


def fd(fun, x, h=1e-5):
    return (fun(x+h)-fun(x-h))/(2*h)


def afgen(table, x):
    # Exact semantic translation of SWAP/functions.f90 AFGEN for a filled table.
    if table[0][0] >= x:
        return table[0][1]
    for i in range(1, len(table)):
        if table[i][0] >= x:
            x0,y0=table[i-1]; x1,y1=table[i]
            return y0+(x-x0)*(y1-y0)/(x1-x0)
    return table[-1][1]


def table_q(gwl, table):
    return afgen(table, abs(gwl))


def eq_depth(L, dbot, wetper):
    x=2*math.pi*dbot/L
    if x > 0.5:
        fx=sum((4*math.exp(-2*i*x))/(i*(1-math.exp(-2*i*x))) for i in (1,3,5))
        eqd=math.pi*L/8/(math.log(L/wetper)+fx)
    elif x < 1e-6:
        eqd=dbot
    else:
        fx=math.pi**2/(4*x)+math.log(x/(2*math.pi))
        eqd=math.pi*L/8/(math.log(L/wetper)+fx)
    return min(eqd,dbot)


def dramet2(g, p):
    d=(g-p['zd'])/p['shape']
    if d < 1e-10:
        return 0.0
    L=p['L']; E=p['entres']; ip=p['ipos']
    zimp=max(p['basegw'],p['zd']-0.25*L)
    dbot=p['zd']-zimp
    if ip == 1:
        R=L*L/(4*p['khtop']*d)+E
    elif ip in (2,3):
        eqd=eq_depth(L,dbot,p['wetper'])
        kb=p['khtop'] if ip==2 else p['khbot']
        R=L*L/(8*kb*eqd+4*p['khtop']*d)+E
    elif ip == 4:
        rver=max(g-p['zintf'],0.0)/p['kvtop']+(min(p['zintf'],g)-p['zd'])/p['kvbot']
        rhor=L*L/(8*p['khbot']*dbot)
        rrad=L/(math.pi*math.sqrt(p['khbot']*p['kvbot']))*math.log(dbot/p['wetper'])
        R=rver+rhor+rrad+E
    elif ip == 5:
        rver=(g-p['zd'])/p['kvtop']
        rhor=L*L/(8*p['khtop']*(p['zd']-p['zintf'])+8*p['khbot']*(p['zintf']-zimp))
        rrad=L/(math.pi*math.sqrt(p['khtop']*p['kvtop']))*math.log((p['geofac']*(p['zd']-p['zintf']))/p['wetper'])
        R=rver+rhor+rrad+E
    else:
        raise ValueError(ip)
    return d/R


def dramet2_dq_dg(g,p):
    d=(g-p['zd'])/p['shape']
    assert d > 1e-8
    L=p['L']; E=p['entres']; ip=p['ipos']
    zimp=max(p['basegw'],p['zd']-0.25*L)
    dbot=p['zd']-zimp
    dd=1/p['shape']
    if ip == 1:
        A=L*L/(4*p['khtop'])
        R=A/d+E
        dRdg=(-A/(d*d))*dd
    elif ip in (2,3):
        eqd=eq_depth(L,dbot,p['wetper'])
        kb=p['khtop'] if ip==2 else p['khbot']
        den=8*kb*eqd+4*p['khtop']*d
        R=L*L/den+E
        dRdg=-(L*L)*(4*p['khtop']*dd)/(den*den)
    elif ip == 4:
        rver=max(g-p['zintf'],0.0)/p['kvtop']+(min(p['zintf'],g)-p['zd'])/p['kvbot']
        rhor=L*L/(8*p['khbot']*dbot)
        rrad=L/(math.pi*math.sqrt(p['khbot']*p['kvbot']))*math.log(dbot/p['wetper'])
        R=rver+rhor+rrad+E
        dRdg=1/p['kvtop'] if g>p['zintf'] else 1/p['kvbot']
    elif ip == 5:
        rver=(g-p['zd'])/p['kvtop']
        rhor=L*L/(8*p['khtop']*(p['zd']-p['zintf'])+8*p['khbot']*(p['zintf']-zimp))
        rrad=L/(math.pi*math.sqrt(p['khtop']*p['kvtop']))*math.log((p['geofac']*(p['zd']-p['zintf']))/p['wetper'])
        R=rver+rhor+rrad+E
        dRdg=1/p['kvtop']
    return (dd*R-d*dRdg)/(R*R)


def base(ip):
    p=dict(ipos=ip,L=1000.0,shape=0.8,wetper=10.0,entres=5.0,basegw=-500.0,
           khtop=10.0,khbot=5.0,kvtop=2.0,kvbot=1.0,geofac=1.5)
    if ip==4:
        p.update(zd=-200.0,zintf=-100.0)
    elif ip==5:
        p.update(zd=-100.0,zintf=-200.0)
    else:
        p.update(zd=-100.0,zintf=-200.0)
    return p


def interflow(g,hd,c,e):
    d=g-hd
    return c*d**e if d>=0 else 0.0


def main():
    table=[(0.0,0.0),(50.0,0.2),(100.0,0.5)]
    assert close(fd(lambda g:table_q(g,table),-75.0),-0.006)
    assert close(fd(lambda g:table_q(g,table),75.0),0.006)
    assert close(fd(lambda g:table_q(g,table),-150.0),0.0)
    left=(table_q(-50.0-1e-6,table)-table_q(-50.0,table))/(-1e-6)
    right=(table_q(-50.0+1e-6,table)-table_q(-50.0,table))/(1e-6)
    assert abs(left-right)>1e-3
    print('FPM08C_DRAMET1_PIECEWISE_LINEAR_SENSITIVITY=PASS')
    print('FPM08C_DRAMET1_KNOT_NONSMOOTHNESS=PASS')

    for ip in (1,2,3,4,5):
        p=base(ip)
        probes=[-50.0]
        if ip==4:
            probes=[-150.0,-50.0]
        for g in probes:
            analytic=dramet2_dq_dg(g,p)
            numeric=fd(lambda x:dramet2(x,p),g)
            assert close(analytic,numeric,3e-6),(ip,g,analytic,numeric)
        print(f'FPM08C_DRAMET2_IPOS{ip}_ANALYTIC_TANGENT_FD=PASS')

    p=base(4)
    eps=1e-6
    below=(dramet2(p['zintf'],p)-dramet2(p['zintf']-eps,p))/eps
    above=(dramet2(p['zintf']+eps,p)-dramet2(p['zintf'],p))/eps
    assert abs(below-above)>1e-8
    print('FPM08C_DRAMET2_IPOS4_INTERFACE_KINK=PASS')

    p=base(2)
    below=p['zd']+p['shape']*0.5e-10
    above=p['zd']+p['shape']*2.0e-10
    assert dramet2(below,p)==0.0
    assert dramet2(above,p)>0.0
    reconstructed_below=(below-p['zd'])/p['shape']
    reconstructed_above=(above-p['zd'])/p['shape']
    assert reconstructed_below < 1e-10 and reconstructed_above > 1e-10
    print('FPM08C_DRAMET2_SMALL_CUTOFF_BRANCH=PASS')
    print('FPM08C_DRAMET2_EXACT_CUTOFF_REPRESENTATION_SENSITIVE=PASS')

    c=0.7; hd=-50.0
    for e in (1.0,0.7,0.2):
        g=-20.0
        analytic=c*e*(g-hd)**(e-1)
        numeric=fd(lambda x:interflow(x,hd,c,e),g)
        assert close(analytic,numeric,3e-6),(e,analytic,numeric)
    e=0.7
    d1=1e-3; d2=1e-6
    slope1=c*e*d1**(e-1); slope2=c*e*d2**(e-1)
    assert slope2>slope1*5
    assert close(c*1.0*(1e-6)**0.0,c)
    print('FPM08C_INTERFLOW_ACTIVE_TANGENT_FD=PASS')
    print('FPM08C_INTERFLOW_SUBLINEAR_ACTIVATION_TANGENT_DIVERGES=PASS')

    levels=[(-80.0,100.0),(-60.0,200.0),(-40.0,50.0)]
    g=-20.0
    q=sum(max(0.0,(g-h)/r) for h,r in levels)
    dq=sum((1/r if g>h else 0.0) for h,r in levels)
    qfun=lambda x:sum(max(0.0,(x-h)/r) for h,r in levels)
    assert q>0 and close(fd(qfun,g),dq)
    print('FPM08C_MULTILEVEL_STABLE_BRANCH_DERIVATIVE_SUM=PASS')

    print('FPM08C_RESPONSE_SENSITIVITY_CHARACTERIZATION PASS')

if __name__=='__main__':
    main()
