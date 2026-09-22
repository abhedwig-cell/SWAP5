from __future__ import annotations
import math

SS=0.10
SM=0.10
C=0.20
DT=1.0
WS=0.010
H0=8.0
BETA=C*DT/(SS+C*DT)
U=BETA*SS
Q0=BETA*WS/DT
PHYSICAL_ROOT=8.04
TOL=1e-12

def close(a,b,tol=TOL):
    assert math.isclose(a,b,rel_tol=0.0,abs_tol=tol),(a,b)

def predictor(qb):
    zp=H0+(WS+qb*DT)/SS
    hp=zp+qb/C
    u=DT/(DT/SS+1/C)
    qu=u*(hp-H0)/DT-qb
    return hp,u,qu

def physical_q(H):
    return Q0-(U/DT)*(H-H0)

def production_q(H,hp,qu,u):
    return qu+(u/DT)*(H-hp)

def solve_storage_with_affine(hp,qu,u):
    # SM*(H-H0)/dt = qu + (u/dt)*(H-hp)
    denom=(SM-u)/DT
    return (SM*H0/DT + qu - (u/DT)*hp)/denom

def solve_storage_physical():
    # SM*(H-H0)/dt = Q0 - (U/dt)*(H-H0)
    return H0+Q0/(SM+U)

def test_independent_physical_root():
    close(solve_storage_physical(),PHYSICAL_ROOT)
    close(physical_q(PHYSICAL_ROOT),0.004)

def test_production_affine_falsification():
    roots=[]
    for qb in (-0.002,0.0,0.003,0.008):
        hp,u,qu=predictor(qb)
        close(u,U)
        close(qu,Q0)
        h=solve_storage_with_affine(hp,qu,u)
        roots.append(h)
        # Published positive-slope response closes its own groundwater equation.
        close(SM*(h-H0)/DT,production_q(h,hp,qu,u))
    # It is not predictor invariant and does not reproduce the physical root.
    assert max(roots)-min(roots)>1e-3
    assert any(abs(h-PHYSICAL_ROOT)>1e-3 for h in roots)

def test_accepted_physical_ledger_exposes_mismatch():
    qb=0.0
    hp,u,qu=predictor(qb)
    h=solve_storage_with_affine(hp,qu,u)
    qpub=production_q(h,hp,qu,u)
    qphys=physical_q(h)
    assert abs(qpub-qphys)>1e-3

if __name__=="__main__":
    test_independent_physical_root()
    test_production_affine_falsification()
    test_accepted_physical_ledger_exposes_mismatch()
    print("GC_FIXED_INTERFACE_PB01_PHYSICAL_ROOT=PASS")
    print("GC_FIXED_INTERFACE_PB01_POSITIVE_SLOPE_EXACT_CONDENSATION=FAIL_AS_PREDICTED")
    print("GC_FIXED_INTERFACE_PB01_PREDICTOR_INVARIANCE=FAIL_AS_PREDICTED")
