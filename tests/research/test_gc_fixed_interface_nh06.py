from __future__ import annotations
import math

SS=.10
SM=.10
C=.20
DT=1.0
WS=.010
H0=8.0
ZP0=8.0
BETA=C*DT/(SS+C*DT)
P_COMP=BETA*WS

def solve(p):
    dh=(BETA*WS-p)/(SM+BETA*SS)
    h=H0+dh
    ec=BETA*(WS+SS*(ZP0-h))
    dvs=WS-ec
    dvm=ec-p
    return h,ec,dvs,dvm

def test_nh06_compensated_throughflow():
    h,ec,dvs,dvm=solve(P_COMP)
    assert math.isclose(h,H0,abs_tol=1e-12)
    assert ec > 1e-3
    assert math.isclose(ec,P_COMP,abs_tol=1e-12)
    assert math.isclose(dvm,0.0,abs_tol=1e-12)
    assert math.isclose(dvs,WS-ec,abs_tol=1e-12)
    assert math.isclose(dvs+dvm,WS-P_COMP,abs_tol=1e-12)

    hu,ecu,dvsu,dvmu=solve(.8*P_COMP)
    ho,eco,dvso,dvmo=solve(1.2*P_COMP)
    assert hu>H0 and dvmu>0
    assert ho<H0 and dvmo<0
    assert math.isclose(dvsu+dvmu,WS-.8*P_COMP,abs_tol=1e-12)
    assert math.isclose(dvso+dvmo,WS-1.2*P_COMP,abs_tol=1e-12)

if __name__=="__main__":
    test_nh06_compensated_throughflow()
    h,ec,dvs,dvm=solve(P_COMP)
    print(f"NH06_COMPENSATED_HEAD_M={h:.15g}")
    print(f"NH06_COMPENSATED_INTERFACE_TRANSFER_M={ec:.15g}")
    print(f"NH06_COMPENSATED_GW_STORAGE_CHANGE_M={dvm:.15g}")
    print("NH06_NONZERO_TRANSFER_ZERO_GW_STORAGE=PASS")
    print("NH06_UNDER_OVER_ABSTRACTION_DIRECTION=PASS")
    print("NH06_COMBINED_LEDGER=PASS")
