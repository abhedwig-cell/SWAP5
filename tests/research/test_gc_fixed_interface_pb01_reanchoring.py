from __future__ import annotations
import math

SS=.10; SM=.10; C=.20; DT=1.0; WS=.010; H0=8.0
U=C*DT*SS/(SS+C*DT)
BETA=C*DT/(SS+C*DT)
ROOT=8.04

def qphys(h):
    return BETA*WS/DT-(U/DT)*(h-H0)

def solve_surrogate(h_anchor, slope):
    q_anchor=qphys(h_anchor)
    # SM*(H-H0)/dt = q_anchor + slope*(H-h_anchor)
    return (SM*H0/DT+q_anchor-slope*h_anchor)/(SM/DT-slope)

def iterate(h0,slope,maxit=100,tol=1e-12):
    h=h0
    history=[]
    for k in range(maxit):
        hn=solve_surrogate(h,slope)
        history.append((h,hn,qphys(hn)-SM*(hn-H0)/DT))
        if abs(hn-h)<=tol:
            return hn,k+1,history
        h=hn
    return h,maxit,history

def test_pb01_reanchored_surrogate():
    starts=(7.95,8.0,8.10,8.20)
    slopes=(0.0,+U/DT,-0.5*U/DT)
    for s in slopes:
        for hstart in starts:
            h,n,hist=iterate(hstart,s)
            assert n<100
            assert math.isclose(h,ROOT,abs_tol=1e-10)
            assert abs(qphys(h)-SM*(h-H0)/DT)<1e-10

    # Exact physical tangent closes in one surrogate solve from any anchor.
    for hstart in starts:
        h,n,hist=iterate(hstart,-U/DT)
        assert math.isclose(h,ROOT,abs_tol=1e-12)
        assert n<=2

    # A frozen current-sign surrogate is not predictor invariant.
    frozen=[solve_surrogate(h,+U/DT) for h in starts]
    assert max(frozen)-min(frozen)>1e-3

if __name__=="__main__":
    test_pb01_reanchored_surrogate()
    for slope,name in ((+U/DT,"POSITIVE_U"),(-U/DT,"PHYSICAL_NEGATIVE_U"),(0.0,"ZERO")):
        h,n,_=iterate(8.20,slope)
        print(f"PB01_REANCHOR_{name}_HEAD_M={h:.15g}")
        print(f"PB01_REANCHOR_{name}_ITERATIONS={n}")
    print("PB01_REANCHORED_POSITIVE_U_FIXED_POINT=PASS")
    print("PB01_FROZEN_POSITIVE_U_PHYSICAL_RESPONSE=FAIL_AS_PREDICTED")
    print("PB01_PHYSICAL_NEGATIVE_U_TANGENT=PASS")
