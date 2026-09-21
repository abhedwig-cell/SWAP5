from __future__ import annotations
import math

P=-1/15
A=0.10

def rho(p,a,s): return (p-s)/(a-s)
def relaxed(r,alpha): return 1-alpha+alpha*r

def main():
    policies={"P0_positive":-P,"P1_physical":P,"P2_picard":0.0}
    for name,s in policies.items():
        r=rho(P,A,s)
        print(f"G01_{name}_RHO={r:.15g}")
    r0=rho(P,A,-P)
    assert math.isclose(r0,-4.0,abs_tol=1e-14)
    assert math.isclose(rho(P,A,P),0.0,abs_tol=1e-14)
    assert math.isclose(rho(P,A,0.0),-2/3,abs_tol=1e-14)
    # alpha=0.2 is the exact linear cancellation for NH01 P0.
    assert math.isclose(relaxed(r0,.2),0.0,abs_tol=1e-14)
    # General relaxed stability interval for rho<1: 0<alpha<2/(1-rho).
    alpha_max=2/(1-r0)
    assert math.isclose(alpha_max,.4,abs_tol=1e-14)
    print(f"G01_P3_ALPHA_MAX={alpha_max:.15g}")
    print("GC_GLOBALIZATION_G01=PASS")

if __name__=="__main__": main()
