from __future__ import annotations
import argparse, json, math
from pathlib import Path

NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL=1e-4
M1_MIN=1e-2

def observables(theta):
    w=math.fsum(x*DZ_CM for x in theta)
    m1=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(NODES))/w
    upper=math.fsum(theta[i]*DZ_CM for i in range(3))
    return w,m1,upper

def write_state(path:Path, rec:dict):
    h=rec["pressure_head_cm"]
    theta=rec["water_content"]
    assert len(h)==NODES and len(theta)==NODES
    assert all(math.isfinite(float(x)) for x in h+theta)
    with path.open("w",encoding="utf-8") as f:
        for i,(hh,tt) in enumerate(zip(h,theta),1):
            f.write(f"{i} {float(hh):.17g} {float(tt):.17g}\n")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--result",required=True)
    ap.add_argument("--output-a",required=True)
    ap.add_argument("--output-b",required=True)
    args=ap.parse_args()
    d=json.load(open(args.result,encoding="utf-8"))
    assert d["decision"]=="QUALIFIED_RESPONSE_BLIND_ZERO_DIVERGENCE_H2_ORIGIN_PAIR_SELECTED"
    assert d["preregistration_commit"]=="c11c08282a3abc9b1beee3002f5a9a01df58d95f"
    p=d["selected_pair"]
    a=p["A_EQ"]; b=p["B_CLOSED"]
    assert (a["family"],a["step"])==("EQ",1)
    assert (b["family"],b["step"])==("CLOSED",14)
    wa,m1a,ua=observables([float(x) for x in a["water_content"]])
    wb,m1b,ub=observables([float(x) for x in b["water_content"]])
    # JSON uses Python round-trip float rendering. Recomputed values must recover
    # the persisted state diagnostics at normal binary64 arithmetic precision.
    assert abs(wa-float(a["profile_water_cm"]))<=1e-12
    assert abs(wb-float(b["profile_water_cm"]))<=1e-12
    assert abs(m1a-float(a["distribution_moment_cm"]))<=1e-12
    assert abs(m1b-float(b["distribution_moment_cm"]))<=1e-12
    dw=abs(wb-wa); dm=abs(m1b-m1a)
    assert dw<=W_TOL,(dw,W_TOL)
    assert dm>=M1_MIN,(dm,M1_MIN)
    write_state(Path(args.output_a),a)
    write_state(Path(args.output_b),b)
    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06e02.origin_extract.v1",
      "source_commit":"e53816189389121cc0b3ff5130e7229d6eddd815",
      "A":{"family":"EQ","step":1,"profile_water_cm":wa,"distribution_moment_cm":m1a,"upper_30cm_water_cm":ua},
      "B":{"family":"CLOSED","step":14,"profile_water_cm":wb,"distribution_moment_cm":m1b,"upper_30cm_water_cm":ub},
      "abs_delta_profile_water_cm":dw,
      "abs_delta_distribution_moment_cm":dm,
      "state_gate_pass":True,
      "response_fields_used_for_extraction":False
    }
    print("RZM06E02_ORIGIN_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E02_ORIGIN_EXTRACT=PASS")

if __name__=="__main__":
    main()
