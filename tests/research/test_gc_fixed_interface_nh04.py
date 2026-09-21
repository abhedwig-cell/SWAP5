from __future__ import annotations
import math

SS=0.10
SM=0.10
C=0.20
DT=1.0
WS=0.010
WM=0.0
ET0=0.002
KT=0.020
Z0=8.0
H0=8.0
TOL=1e-12

def close(a,b,tol=TOL):
    assert math.isclose(a,b,rel_tol=0.0,abs_tol=tol),(a,b)

def exact_root():
    # y = Cdt/(SM+Cdt) x
    k=C*DT/(SM+C*DT)
    x=(WS-ET0)/(SS+KT+C*DT*(1-k))
    y=k*x
    et=ET0+KT*x
    ec=SM*y-WM
    return x,y,et,ec

def condensed_u():
    return C*DT*(SS+KT)/(SS+KT+C*DT)

def transfer_at_trial_head(hc):
    # solve linear top balance at fixed trial interface head
    zp=(SS*Z0 + WS-ET0 + KT*Z0 + C*DT*hc)/(SS+KT+C*DT)
    return C*DT*(zp-hc)

def test_nh04_exact_oracle():
    x,y,et,ec=exact_root()
    close(x,0.04285714285714286)
    close(y,0.02857142857142857)
    close(et,0.002857142857142857)
    close(ec,0.002857142857142857)
    close(SS*x,WS-et-ec)
    close(SM*y,WM+ec)
    close(SS*x+SM*y,WS-et+WM)

def test_nh04_process_changes_condensed_response_not_storage():
    u=condensed_u()
    close(u,0.075)
    close(SS,0.10)
    assert not math.isclose(u,SS,rel_tol=0.0,abs_tol=1e-6)

def test_nh04_corrector_derivative():
    _,y,_,_=exact_root()
    hc=H0+y
    eps=1e-6
    fd=(transfer_at_trial_head(hc+eps)-transfer_at_trial_head(hc-eps))/(2*eps)
    close(fd,-condensed_u(),1e-10)

if __name__=="__main__":
    test_nh04_exact_oracle()
    test_nh04_process_changes_condensed_response_not_storage()
    test_nh04_corrector_derivative()
    print("GC_FIXED_INTERFACE_NH04_PROCESS_ORACLE=PASS")
