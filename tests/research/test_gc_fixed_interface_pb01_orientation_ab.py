from __future__ import annotations
import math

SS=.10; SM=.10; C=.20; DT=1.0; WS=.010; H0=8.0
U=DT/(DT/SS+1/C)
QINT=(U/SS)*(WS/DT)
ROOT=8.04

def predictor(qb):
    hp=H0+WS/SS+qb*(DT/SS+1/C)
    qu=U*(hp-H0)/DT-qb
    return hp,qu

def root_for(hp,qu,slope):
    # SM*(H-H0)/dt = qu + slope*(H-hp)
    return (SM*H0/DT + qu - slope*hp)/(SM/DT-slope)

def test_orientation_ab():
    plus=[]; minus=[]
    for qb in (-.002,0,.003,.008):
        hp,qu=predictor(qb)
        assert math.isclose(qu,QINT,abs_tol=1e-14)
        plus.append(root_for(hp,qu,+U/DT))
        # Correct outward response needs value -qb at predictor origin, not qu.
        minus.append(root_for(hp,-qb,-U/DT))
    assert max(plus)-min(plus)>1e-3
    assert all(math.isclose(h,ROOT,abs_tol=1e-12) for h in minus)

if __name__=="__main__":
    test_orientation_ab()
    print("PB01_NATIVE_QBOT_POSITIVE_TANGENT=CONSISTENT")
    print("PB01_OUTWARD_QBOT_NEGATIVE_TANGENT=CONSISTENT")
    print("PB01_OUTWARD_QU_WITH_POSITIVE_TANGENT=INCONSISTENT_WITH_NH01")
