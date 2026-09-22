from __future__ import annotations
import argparse,json,math
from pathlib import Path

EXPECTED_DECISION="SELECTED_EXACT_LOCAL_REDISTRIBUTION_PAIR"
EXPECTED_A={"direction":"LOCAL_UP","rate_index":6,"fraction":0.5,"steps":2}
EXPECTED_B={"direction":"LOCAL_DOWN","rate_index":6,"fraction":0.5,"steps":2}

def write_origin(path:Path,origin:dict)->None:
    h=origin["pressure_head_cm"]; t=origin["water_content"]
    assert len(h)==16 and len(t)==16
    with path.open("w",encoding="utf-8") as f:
        for i,(hh,tt) in enumerate(zip(h,t),1):
            f.write(f"{i} {hh:.17g} {tt:.17g}\n")

def canonical_aggregates(origin:dict)->tuple[float,float]:
    theta=origin["water_content"]
    profile=math.fsum(x*10.0 for x in theta)
    root30=math.fsum(theta[i]*10.0 for i in range(3))
    return profile,root30

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--result",required=True)
    ap.add_argument("--output-a",required=True)
    ap.add_argument("--output-b",required=True)
    a=ap.parse_args()
    d=json.loads(Path(a.result).read_text(encoding="utf-8"))
    assert d["decision"]==EXPECTED_DECISION
    assert d["selected_mode"]=="EXACT"
    p=d["selected_pair"]
    for k,v in EXPECTED_A.items(): assert p["A"][k]==v
    for k,v in EXPECTED_B.items(): assert p["B"][k]==v
    assert p["abs_delta_profile_water_cm"]==0.0
    assert p["abs_delta_root30_water_cm"]==0.0
    assert p["abs_delta_H16_cm"]>=1e-2
    wa,ra=canonical_aggregates(p["A"])
    wb,rb=canonical_aggregates(p["B"])
    assert wa==wb, (wa,wb)
    assert ra==rb, (ra,rb)
    write_origin(Path(a.output_a),p["A"])
    write_origin(Path(a.output_b),p["B"])
    print("RZM06E10_ORIGIN_JSON",json.dumps({
      "schema":"swap5.gc_rootzone_memory.rzm06e10.origin_extract.v1",
      "parent_result_commit":"f01c6330cc1c1a3956889225b7bf59108c4e704a",
      "A":EXPECTED_A,"B":EXPECTED_B,
      "canonical_profile_water_a_cm":wa,"canonical_profile_water_b_cm":wb,
      "canonical_root30_water_a_cm":ra,"canonical_root30_water_b_cm":rb,
      "canonical_profile_exact_equal":wa==wb,
      "canonical_root30_exact_equal":ra==rb,
      "abs_delta_H16_cm":p["abs_delta_H16_cm"],
      "response_fields_used":False
    },sort_keys=True,separators=(",",":")))
    print("GC_RZM06E10_ORIGIN_EXTRACT=PASS")
    return 0
if __name__=="__main__": raise SystemExit(main())
