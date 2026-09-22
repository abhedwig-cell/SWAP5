from __future__ import annotations
import argparse
import json
from pathlib import Path

EXPECTED_DECISION="QUALIFIED_RESPONSE_BLIND_STORAGE_MATCHED_INTERFACE_STATE_PAIR_SELECTED"
EXPECTED_A=["E01","CLOSED","1"]
EXPECTED_B=["E03","DRY_RECOVER","RECOVER","19"]

def write_origin(path:Path, origin:dict)->None:
    h=origin["pressure_head_cm"]
    theta=origin["water_content"]
    assert len(h)==16 and len(theta)==16
    with path.open("w",encoding="utf-8") as f:
        for i,(hh,tt) in enumerate(zip(h,theta),start=1):
            f.write(f"{i} {hh:.17g} {tt:.17g}\n")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--result",required=True)
    ap.add_argument("--output-a",required=True)
    ap.add_argument("--output-b",required=True)
    args=ap.parse_args()

    d=json.loads(Path(args.result).read_text(encoding="utf-8"))
    assert d["decision"]==EXPECTED_DECISION
    pair=d["selected_pair"]
    assert pair["A"]["provenance"]==EXPECTED_A
    assert pair["B"]["provenance"]==EXPECTED_B
    assert pair["abs_delta_profile_water_cm"]<=1e-4
    assert pair["abs_delta_root30_water_cm"]<=1e-4
    assert pair["abs_delta_bottom_node_pressure_head_cm"]>=1e-2

    write_origin(Path(args.output_a),pair["A"])
    write_origin(Path(args.output_b),pair["B"])

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06e04.origin_extract.v1",
      "parent_result_commit":"e7ba2db6b5eb4084a61387e1159e76cf77394fd1",
      "A":pair["A"]["provenance"],
      "B":pair["B"]["provenance"],
      "abs_delta_profile_water_cm":pair["abs_delta_profile_water_cm"],
      "abs_delta_root30_water_cm":pair["abs_delta_root30_water_cm"],
      "abs_delta_H16_cm":pair["abs_delta_bottom_node_pressure_head_cm"],
      "response_fields_used":False,
    }
    print("RZM06E04_ORIGIN_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E04_ORIGIN_EXTRACT=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
