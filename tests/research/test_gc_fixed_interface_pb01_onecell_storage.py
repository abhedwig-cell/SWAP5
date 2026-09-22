from __future__ import annotations
import math

SS=.10; SM=.10; C=.20; DT=1.0; WS=.010; H0=8.0
U=DT/(DT/SS+1/C)
QINT=(U/SS)*(WS/DT)
ROOT=8.04
PREDICTORS=(-.002,0.0,.003,.008)

def predictor(qb):
    hp=H0+WS/SS+qb*(DT/SS+1/C)
    qu=U*(hp-H0)/DT-qb
    return hp,qu

def solve_api_storage(qref,href,slope):
    # Exact one-cell transient balance with an API boundary:
    # SM*(H-H0)/dt = Q(H), Q=qref+slope*(H-href).
    return (SM*H0/DT+qref-slope*href)/(SM/DT-slope)

def physical_outward(H):
    return QINT-(U/DT)*(H-H0)

def test_live_equation_orientation_matrix():
    current=[]; native=[]; outward=[]
    for qb in PREDICTORS:
        hp,qu=predictor(qb)

        # Current documented/public construction.
        hc=solve_api_storage(qu,hp,+U/DT)
        current.append(hc)

        # Coherent native-qbot representation: package source would need the
        # groundwater conversion -qbot, so this is not directly published.
        hn=solve_api_storage(-qb,hp,-U/DT)
        native.append(hn)

        # Coherent outward representation is algebraically the same.
        ho=solve_api_storage(-qb,hp,-U/DT)
        outward.append(ho)

        assert math.isclose(hn,ROOT,abs_tol=1e-12)
        assert math.isclose(ho,ROOT,abs_tol=1e-12)
        assert math.isclose(physical_outward(ROOT),SM*(ROOT-H0)/DT,abs_tol=1e-12)

    assert max(current)-min(current)>1e-3
    assert any(abs(h-ROOT)>1e-3 for h in current)

if __name__=="__main__":
    test_live_equation_orientation_matrix()
    print("PB01_ONECELL_STORAGE_CURRENT_ORIENTATION=FAIL_AS_PHYSICAL_CONDENSATION")
    print("PB01_ONECELL_STORAGE_OUTWARD_NEGATIVE_TANGENT=PASS")
    print("PB01_ONECELL_STORAGE_PHYSICAL_ROOT_M=8.04")
