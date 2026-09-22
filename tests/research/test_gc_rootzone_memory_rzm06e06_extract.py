from __future__ import annotations
import argparse,json
from pathlib import Path

EXPECTED_DECISION="SELECTED_TIGHTER_STORAGE_MATCHED_INTERFACE_STATE_PAIR"
EXPECTED_A=["D04","B","HOLD","1","5"]
EXPECTED_B=["D04","B","IDENTITY","0","0"]

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
    assert d["selected_mode_cm"]==1e-6
    p=d["selected_pair"]
    assert p["A"]["provenance"]==EXPECTED_A and p["B"]["provenance"]==EXPECTED_B
    assert p["abs_delta_profile_water_cm"]<=1e-6
    assert p["abs_delta_root30_water_cm"]<=1e-6
    assert p["abs_delta_H16_cm"]>=1e-2
    write_origin(Path(a.output_a),p["A"]); write_origin(Path(a.output_b),p["B"])
    print("RZM06E06_ORIGIN_JSON",json.dumps({
      "schema":"swap5.gc_rootzone_memory.rzm06e06.origin_extract.v1",
      "parent_result_commit":"a92af540a106bcefae9c3eaa99532762bf518e52",
      "A":p["A"]["provenance"],"B":p["B"]["provenance"],
      "abs_delta_profile_water_cm":p["abs_delta_profile_water_cm"],
      "abs_delta_root30_water_cm":p["abs_delta_root30_water_cm"],
      "abs_delta_H16_cm":p["abs_delta_H16_cm"],
      "response_fields_used":False
    },sort_keys=True,separators=(",",":")))
    print("GC_RZM06E06_ORIGIN_EXTRACT=PASS")
    return 0
if __name__=="__main__": raise SystemExit(main())
