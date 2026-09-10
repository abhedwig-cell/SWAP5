#!/usr/bin/env python3
import math

TOL = 3e-6


def close(a, b, tol=TOL):
    return abs(a - b) <= tol * max(1.0, abs(a), abs(b))


def fd(fun, x, h=1e-5):
    return (fun(x + h) - fun(x - h)) / (2.0 * h)


def geometry(p):
    zimp = max(p['basegw'], p['zd'] - 0.25 * p['L'])
    dbot = p['zd'] - zimp
    return zimp, dbot


def eq_depth(L, dbot, wetper):
    x = 2.0 * math.pi * dbot / L
    branch = None
    if x > 0.5:
        branch = 'series'
        fx = sum((4.0 * math.exp(-2.0 * i * x)) /
                 (i * (1.0 - math.exp(-2.0 * i * x))) for i in (1, 3, 5))
        den = math.log(L / wetper) + fx
        raw = math.pi * L / 8.0 / den
    elif x < 1.0e-6:
        branch = 'dbot'
        den = None
        raw = dbot
    else:
        branch = 'asymptotic'
        fx = math.pi ** 2 / (4.0 * x) + math.log(x / (2.0 * math.pi))
        den = math.log(L / wetper) + fx
        raw = math.pi * L / 8.0 / den
    return min(raw, dbot), raw, x, branch, den


def base(ipos):
    p = dict(
        ipos=ipos,
        L=1000.0,
        shape=0.8,
        wetper=10.0,
        entres=5.0,
        basegw=-500.0,
        khtop=10.0,
        khbot=5.0,
        kvtop=2.0,
        kvbot=1.0,
        geofac=1.5,
    )
    if ipos == 4:
        p.update(zd=-200.0, zintf=-100.0)
    else:
        p.update(zd=-100.0, zintf=-200.0)
    return p


def normalized_domain_ok(p):
    ip = p['ipos']
    if not (p['L'] > 0.0 and p['shape'] > 0.0 and p['entres'] >= 0.0):
        return False
    zimp, dbot = geometry(p)
    if p['basegw'] > p['zd']:
        return False

    if ip == 1:
        return p['khtop'] > 0.0

    if ip in (2, 3):
        if not (p['khtop'] > 0.0 and p['wetper'] > 0.0):
            return False
        if dbot < 0.0:
            return False
        try:
            eqd, raw, x, branch, den = eq_depth(p['L'], dbot, p['wetper'])
        except (ValueError, ZeroDivisionError, OverflowError):
            return False
        if not math.isfinite(eqd) or eqd < 0.0:
            return False
        if den is not None and den <= 0.0:
            return False
        if ip == 3 and p['khbot'] < 0.0:
            return False
        return True

    if ip == 4:
        if not (p['basegw'] < p['zd'] and p['zd'] <= p['zintf']):
            return False
        if not (dbot > 0.0 and p['khbot'] > 0.0 and p['kvtop'] > 0.0 and p['kvbot'] > 0.0 and p['wetper'] > 0.0):
            return False
        try:
            rhor = p['L'] ** 2 / (8.0 * p['khbot'] * dbot)
            rrad = p['L'] / (math.pi * math.sqrt(p['khbot'] * p['kvbot'])) * math.log(dbot / p['wetper'])
        except (ValueError, ZeroDivisionError):
            return False
        return math.isfinite(rhor + rrad + p['entres']) and (rhor + rrad + p['entres'] > 0.0)

    if ip == 5:
        if not (p['khtop'] > 0.0 and p['kvtop'] > 0.0 and p['khbot'] >= 0.0 and p['wetper'] > 0.0 and p['geofac'] > 0.0):
            return False
        if not (p['zd'] > p['zintf']):
            return False
        hden = 8.0 * p['khtop'] * (p['zd'] - p['zintf']) + 8.0 * p['khbot'] * (p['zintf'] - zimp)
        if not (hden > 0.0):
            return False
        try:
            rhor = p['L'] ** 2 / hden
            arg = p['geofac'] * (p['zd'] - p['zintf']) / p['wetper']
            rrad = p['L'] / (math.pi * math.sqrt(p['khtop'] * p['kvtop'])) * math.log(arg)
        except (ValueError, ZeroDivisionError):
            return False
        return math.isfinite(rhor + rrad + p['entres']) and (rhor + rrad + p['entres'] > 0.0)

    return False


def response(gwl, p):
    d = (gwl - p['zd']) / p['shape']
    if d < 1.0e-10:
        return 0.0
    zimp, dbot = geometry(p)
    if dbot < 0.0:
        raise ValueError('negative dbot')
    ip = p['ipos']

    if ip == 1:
        R = p['L'] ** 2 / (4.0 * p['khtop'] * abs(d)) + p['entres']
    elif ip in (2, 3):
        eqd, _, _, _, _ = eq_depth(p['L'], dbot, p['wetper'])
        kb = p['khtop'] if ip == 2 else p['khbot']
        R = p['L'] ** 2 / (8.0 * kb * eqd + 4.0 * p['khtop'] * abs(d)) + p['entres']
    elif ip == 4:
        if p['zd'] > p['zintf']:
            raise ValueError('invalid IPOS4 geometry')
        rver = max(gwl - p['zintf'], 0.0) / p['kvtop'] + (min(p['zintf'], gwl) - p['zd']) / p['kvbot']
        rhor = p['L'] ** 2 / (8.0 * p['khbot'] * dbot)
        rrad = p['L'] / (math.pi * math.sqrt(p['khbot'] * p['kvbot'])) * math.log(dbot / p['wetper'])
        R = rver + rhor + rrad + p['entres']
    elif ip == 5:
        if p['zd'] < p['zintf']:
            raise ValueError('invalid IPOS5 geometry')
        rver = (gwl - p['zd']) / p['kvtop']
        hden = 8.0 * p['khtop'] * (p['zd'] - p['zintf']) + 8.0 * p['khbot'] * (p['zintf'] - zimp)
        rhor = p['L'] ** 2 / hden
        rrad = p['L'] / (math.pi * math.sqrt(p['khtop'] * p['kvtop'])) * math.log((p['geofac'] * (p['zd'] - p['zintf'])) / p['wetper'])
        R = rver + rhor + rrad + p['entres']
    else:
        raise ValueError(ip)
    return d / R


def analytic_dq_dg(gwl, p):
    d = (gwl - p['zd']) / p['shape']
    assert d > 1.0e-8
    dd = 1.0 / p['shape']
    zimp, dbot = geometry(p)
    ip = p['ipos']

    if ip == 1:
        A = p['L'] ** 2 / (4.0 * p['khtop'])
        R = A / d + p['entres']
        dR = -A * dd / (d * d)
    elif ip in (2, 3):
        eqd, _, _, _, _ = eq_depth(p['L'], dbot, p['wetper'])
        kb = p['khtop'] if ip == 2 else p['khbot']
        den = 8.0 * kb * eqd + 4.0 * p['khtop'] * d
        R = p['L'] ** 2 / den + p['entres']
        dR = -(p['L'] ** 2) * (4.0 * p['khtop'] * dd) / (den * den)
    elif ip == 4:
        rver = max(gwl - p['zintf'], 0.0) / p['kvtop'] + (min(p['zintf'], gwl) - p['zd']) / p['kvbot']
        rhor = p['L'] ** 2 / (8.0 * p['khbot'] * dbot)
        rrad = p['L'] / (math.pi * math.sqrt(p['khbot'] * p['kvbot'])) * math.log(dbot / p['wetper'])
        R = rver + rhor + rrad + p['entres']
        dR = 1.0 / p['kvtop'] if gwl > p['zintf'] else 1.0 / p['kvbot']
    elif ip == 5:
        hden = 8.0 * p['khtop'] * (p['zd'] - p['zintf']) + 8.0 * p['khbot'] * (p['zintf'] - zimp)
        rver = (gwl - p['zd']) / p['kvtop']
        rhor = p['L'] ** 2 / hden
        rrad = p['L'] / (math.pi * math.sqrt(p['khtop'] * p['kvtop'])) * math.log((p['geofac'] * (p['zd'] - p['zintf'])) / p['wetper'])
        R = rver + rhor + rrad + p['entres']
        dR = 1.0 / p['kvtop']
    else:
        raise ValueError(ip)
    return (dd * R - d * dR) / (R * R)


def main():
    for ip in (1, 2, 3, 4, 5):
        p = base(ip)
        assert normalized_domain_ok(p), ip
        probes = [-50.0]
        if ip == 4:
            probes = [-150.0, -50.0]
        for g in probes:
            a = analytic_dq_dg(g, p)
            n = fd(lambda x: response(x, p), g)
            assert close(a, n), (ip, g, a, n)
        print(f'FPM08C2_IPOS{ip}_STABLE_BRANCH_TANGENT_FD=PASS')

    p = base(4)
    eps = 1.0e-6
    q0 = response(p['zintf'], p)
    left = (q0 - response(p['zintf'] - eps, p)) / eps
    right = (response(p['zintf'] + eps, p) - q0) / eps
    assert abs(left - right) > 1.0e-8
    print('FPM08C2_IPOS4_INTERFACE_KINK=PASS')

    L = 1000.0
    wetper = 10.0
    db1 = (1.0e-6 * L / (2.0 * math.pi))
    e_lo = eq_depth(L, db1 * (1.0 - 1.0e-8), wetper)[0]
    e_hi = eq_depth(L, db1 * (1.0 + 1.0e-8), wetper)[0]
    assert abs(e_hi - e_lo) < 1.0e-8
    print('FPM08C2_EQDEPTH_X1E6_EFFECTIVELY_CONTINUOUS=PASS')

    db05 = 0.5 * L / (2.0 * math.pi)
    e_left = eq_depth(L, db05, wetper)[0]
    e_right = eq_depth(L, db05 * (1.0 + 1.0e-8), wetper)[0]
    assert abs(e_right - e_left) > 1.0e-3
    print('FPM08C2_EQDEPTH_X05_FINITE_BRANCH_JUMP=PASS')

    invalid = []
    p = base(1); p['khtop'] = 0.0; invalid.append(('IPOS1_ZERO_KHTOP', p))
    p = base(2); p['wetper'] = 0.0; invalid.append(('IPOS2_ZERO_WETPER', p))
    p = base(4); p['khbot'] = 0.0; invalid.append(('IPOS4_ZERO_KHBOT', p))
    p = base(4); p['kvtop'] = 0.0; invalid.append(('IPOS4_ZERO_KVTOP', p))
    p = base(4); p['kvbot'] = 0.0; invalid.append(('IPOS4_ZERO_KVBOT', p))
    p = base(5); p['geofac'] = 0.0; invalid.append(('IPOS5_ZERO_GEOFAC', p))
    p = base(5); p['zintf'] = p['zd']; invalid.append(('IPOS5_ZERO_LOG_THICKNESS', p))
    for name, p in invalid:
        assert not normalized_domain_ok(p), name
    print('FPM08C2_LEGACY_READER_ADMITS_MATHEMATICALLY_INVALID_EDGE_VALUES=PASS')

    p = base(5)
    p['kvbot'] = 0.0
    assert normalized_domain_ok(p)
    q = response(-50.0, p)
    assert math.isfinite(q)
    print('FPM08C2_IPOS5_KVBOT_UNUSED_IN_NORMALIZED_FORM=PASS')

    print('FPM08C2_HOOGHOUDT_ERNST_DOMAIN_CHARACTERIZATION PASS')


if __name__ == '__main__':
    main()
