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
    return (SM*H0/DT+q_anchor-slope*h_anchor)/(SM/DT-slope)

def iterate(h0,slope,maxit=100,tol=1e-12):
    h=h0; history=[]
    for k in range(maxit):
        hn=solve_surrogate(h,slope)
        history.append((h,hn,qphys(hn)-SM*(hn-H0)/DT))
        if abs(hn-h)<=tol: return hn,k+1,history,True
        h=hn
    return h,maxit,history,False

def amplification(slope):
    # e_{k+1}=rho e_k for this linear problem.
    return -(U/DT+slope)/(SM/DT-slope)

def test_pb01_reanchored_surrogate():
    starts=(7.95,8.0,8.10,8.20)

    # Exact physical tangent.
    for hstart in starts:
        h,n,_,ok=iterate(hstart,-U/DT)
        assert ok and math.isclose(h,ROOT,abs_tol=1e-12)

    # Zero slope is convergent but slower.
    assert abs(amplification(0.0))<1.0
    for hstart in starts:
        h,n,_,ok=iterate(hstart,0.0)
        assert ok and math.isclose(h,ROOT,abs_tol=1e-10)

    # Current positive slope is an exact fixed-point preserving surrogate,
    # but it is unstable for this NH01 parameter set.
    assert math.isclose(solve_surrogate(ROOT,+U/DT),ROOT,abs_tol=1e-12)
    assert abs(amplification(+U/DT))>1.0
    h,n,hist,ok=iterate(8.20,+U/DT)
    assert not ok
    assert abs(hist[-1][1]-ROOT)>abs(hist[0][0]-ROOT)

    frozen=[solve_surrogate(h,+U/DT) for h in starts]
    assert max(frozen)-min(frozen)>1e-3

if __name__=="__main__":
    test_pb01_reanchored_surrogate()
    print(f"PB01_REANCHOR_POSITIVE_U_AMPLIFICATION={amplification(+U/DT):.15g}")
    print(f"PB01_REANCHOR_ZERO_AMPLIFICATION={amplification(0.0):.15g}")
    print(f"PB01_REANCHOR_PHYSICAL_TANGENT_AMPLIFICATION={amplification(-U/DT):.15g}")
    print("PB01_REANCHORED_POSITIVE_U_FIXED_POINT_PRESERVED=PASS")
    print("PB01_REANCHORED_POSITIVE_U_STABILITY=FAIL_AS_DERIVED")
    print("PB01_FROZEN_POSITIVE_U_PHYSICAL_RESPONSE=FAIL_AS_PREDICTED")
    print("PB01_PHYSICAL_NEGATIVE_U_TANGENT=PASS")
