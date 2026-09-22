from __future__ import annotations
import argparse,json
from pathlib import Path

EXPECTED_DECISION="SELECTED_TIGHT_DEEP_REDISTRIBUTION_PAIR"
EXPECTED_A={"direction":"UPSHIFT","rate_index":3,"fraction":0.0625,"steps":1}
EXPECTED_B={"direction":"DOWNSHIFT","rate_index":3,"fraction":0.0625,"steps":1}

def write_origin(path:Path,origin:dict)->None:
    h=origin["pressure_head_cm"]; t=origin["water_content"]
    assert len(h)==16 and len(t)==16
    with path.open("w",encoding="utf-8") as f:
        for i,(hh,tt) in enumerate(zip(h,t),1):
            f.write(f"{i} {hh:.17g} {tt:.17g}\n")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--result",required=True)
    ap.add_argument("--output-a",required=True)
    ap.add_argument("--output-b",required=True)
    a=ap.parse_args()
    d=json.loads(Path(a.result).read_text(encoding="utf-8"))
    assert d["decision"]==EXPECTED_DECISION
    assert d["generation"]["selected_resolution_cm"]==1e-9
    p=d["selected_pair"]
    for k,v in EXPECTED_A.items(): assert p["A"][k]==v
    for k,v in EXPECTED_B.items(): assert p["B"][k]==v
    assert p["abs_delta_profile_water_cm"]<=1e-9
    assert p["abs_delta_root30_water_cm"]<=1e-9
    assert p["abs_delta_H16_cm"]>=1e-2
    write_origin(Path(a.output_a),p["A"]); write_origin(Path(a.output_b),p["B"])
    print("RZM06E08_ORIGIN_JSON",json.dumps({
      "schema":"swap5.gc_rootzone_memory.rzm06e08.origin_extract.v1",
      "parent_result_commit":"4e103502f6d00df8adf27630e891050bbb791c28",
      "A":EXPECTED_A,"B":EXPECTED_B,
      "abs_delta_profile_water_cm":p["abs_delta_profile_water_cm"],
      "abs_delta_root30_water_cm":p["abs_delta_root30_water_cm"],
      "abs_delta_H16_cm":p["abs_delta_H16_cm"],
      "response_fields_used":False
    },sort_keys=True,separators=(",",":")))
    print("GC_RZM06E08_ORIGIN_EXTRACT=PASS")
    return 0
if __name__=="__main__": raise SystemExit(main())
