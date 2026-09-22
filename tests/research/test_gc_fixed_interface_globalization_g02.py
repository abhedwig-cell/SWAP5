from __future__ import annotations
import math, json

# Dimensionless scale: physical SWAP tangent p=-1.
# r=a/(-p)>0 is groundwater-response magnitude relative to |p|.
P=-1.0
def rho(a,s):
    d=a-s
    if abs(d)<1e-14: return None
    return (P-s)/d

def cls(x):
    if x is None: return "SINGULAR"
    if abs(x)<1-1e-12: return "CONTRACTIVE"
    if abs(abs(x)-1)<=1e-12: return "NEUTRAL"
    return "DIVERGENT"

def main():
    ratios=(0.1,0.25,0.5,0.9,1.0,1.1,2.0,5.0,10.0)
    policies={"P0_positive":1.0,"P1_physical":-1.0,"P2_picard":0.0}
    out=[]
    for r in ratios:
        row={"a_over_abs_p":r}
        for name,s in policies.items():
            rr=rho(r,s); row[name]={"rho":rr,"class":cls(rr)}
        out.append(row)
        print("G02",json.dumps(row,sort_keys=True))
    # Closed-form gates for p=-1:
    # P0 rho=-2/(r-1): singular r=1; contractive iff r>3.
    # P1 rho=0 for all r>0.
    # P2 rho=-1/r: contractive iff r>1.
    assert cls(rho(1.0,1.0))=="SINGULAR"
    assert cls(rho(2.0,1.0))=="DIVERGENT"
    assert cls(rho(5.0,1.0))=="CONTRACTIVE"
    assert cls(rho(.5,0.0))=="DIVERGENT"
    assert cls(rho(2.0,0.0))=="CONTRACTIVE"
    assert all(abs(rho(r,-1.0))<1e-14 for r in ratios)
    print("G02_P0_CONTRACTIVE_IFF_A_OVER_ABS_P_GT_3=PASS")
    print("G02_P2_CONTRACTIVE_IFF_A_OVER_ABS_P_GT_1=PASS")
    print("G02_P1_AFFINE_ONE_STEP_FOR_POSITIVE_A=PASS")
    print("GC_GLOBALIZATION_G02=PASS")
if __name__=="__main__": main()
