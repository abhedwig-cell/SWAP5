#!/usr/bin/env python3
"""Independent Decimal authority-equation roots, without production code."""
from decimal import Decimal as D,getcontext
getcontext().prec=70

def shape(a,c1,c2):
    return (a*c2.ln()).exp()*((-a*c2).exp()-(-a*c1).exp())/((-a).exp()-(-a*c1).exp())

def root(c1,c2,target,lo,hi):
    flo=shape(lo,c1,c2)-target
    assert flo*(shape(hi,c1,c2)-target)<0
    for _ in range(250):
        mid=(lo+hi)/2;f=shape(mid,c1,c2)-target
        if flo*f>0:lo=mid;flo=f
        else:hi=mid
    return (lo+hi)/2

for p in [D('.1'),D('-.3')]:
    base=D('.28');target=D('.3') if p>0 else D('.2')
    alpha=root(D(2),D(1)/3,(target/base-1)/p,D('.001'),D(10))
    print(f'PPA_WU05_MIGMAC04_DECIMAL_P={p}|ALPHA={alpha}|BETA={alpha*2}')
# Outside the admitted typical<peak branch, the same source residual has two roots.
r1=root(D(2),D('1.5'),D('.55'),D('.001'),D(2))
r2=root(D(2),D('1.5'),D('.55'),D(2),D(10))
assert r1!=r2
print(f'PPA_WU05_MIGMAC04_AMBIGUOUS_C1_2_C2_1_5_C3_0_55|ROOT1={r1}|ROOT2={r2}')
print('PPA_WU05_MIGMAC04_INDEPENDENT_DECIMAL_AND_NONIDENTIFIABILITY=PASS')
