from __future__ import annotations
import math

SS=0.10
SM=0.10
C=0.20
DT=1.0
Z0=8.0
H0=8.0
LAMBDA=0.5
TOL=1e-12

def close(a,b,tol=TOL):
    assert math.isclose(a,b,rel_tol=0.0,abs_tol=tol),(a,b)

def solve(m0):
    release=LAMBDA*m0
    # Same linear partition as NH01 with release acting as internal mobile input.
    # y=k*x and SS*x = release-SM*y.
    k=C*DT/(SM+C*DT)
    x=release/(SS+SM*k)
    y=k*x
    ec=SM*y
    m1=(1-LAMBDA)*m0
    return x,y,ec,m1,release

def test_nh05_equal_heads_different_memory_different_future():
    a=solve(0.0)
    b=solve(0.006)
    close(a[0],0.0); close(a[1],0.0); close(a[2],0.0)
    close(b[0],0.018)
    close(b[1],0.012)
    close(b[2],0.0012)
    assert b[2] != a[2]

def test_nh05_memory_is_internal_ledger():
    x,y,ec,m1,release=solve(0.006)
    dvs=SS*x
    dvm=SM*y
    dm=m1-0.006
    close(dvs,release-ec)
    close(dvm,ec)
    close(dm,-release)
    close(dvs+dvm+dm,0.0)
    # If memory inventory were omitted, apparent water creation equals release.
    close(dvs+dvm,release)

def test_nh05_same_tangent_can_have_different_intercept():
    # Memory release is head independent here, so the fixed-head response slope
    # is unchanged while its intercept shifts with m0.
    u=C*DT*SS/(SS+C*DT)
    close(u,1.0/15.0)
    intercept_a=(C*DT/(SS+C*DT))*(LAMBDA*0.0)
    intercept_b=(C*DT/(SS+C*DT))*(LAMBDA*0.006)
    close(intercept_a,0.0)
    close(intercept_b,0.002)
    assert intercept_a != intercept_b

if __name__=="__main__":
    test_nh05_equal_heads_different_memory_different_future()
    test_nh05_memory_is_internal_ledger()
    test_nh05_same_tangent_can_have_different_intercept()
    print("GC_FIXED_INTERFACE_NH05_MEMORY_ORACLE=PASS")
