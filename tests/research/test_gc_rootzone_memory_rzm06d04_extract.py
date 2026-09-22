from __future__ import annotations
import argparse, json
from pathlib import Path

TARGETS={
    ("D02",64):"A",
    ("D08",44):"B",
}
STATE_ALLOWED={"SPLIT","HISTORY","STEP","T","FALLBACK"}
NODE_ALLOWED={"SPLIT","HISTORY","STEP","NODE","H","THETA"}

def extract(line,allowed):
    out={}
    for token in line.split("|")[1:]:
        if "=" not in token:
            continue
        k,v=token.split("=",1)
        if k in allowed:
            out[k]=v
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output-a",required=True)
    ap.add_argument("--output-b",required=True)
    args=ap.parse_args()
    root=Path(args.artifact_dir)
    raw=(root/"o0.txt").read_bytes()
    assert raw==(root/"o2.txt").read_bytes(),"ROM1AR2 O0/O2 drift"
    lines=raw.decode("utf-8").splitlines()

    metadata={}
    for line in lines:
        if not line.startswith("ROM1AR2_STATE|"):
            continue
        split=extract(line,{"SPLIT"}).get("SPLIT")
        if split!="DISCOVERY":
            continue
        m=extract(line,STATE_ALLOWED)
        key=(m["HISTORY"],int(m["STEP"]))
        if key in TARGETS:
            assert m["FALLBACK"]=="F",(key,m["FALLBACK"])
            metadata[key]=m
    assert set(metadata)==set(TARGETS),metadata

    nodes={k:{} for k in TARGETS}
    for line in lines:
        if not line.startswith("ROM1AR2_NODE|"):
            continue
        split=extract(line,{"SPLIT"}).get("SPLIT")
        if split!="DISCOVERY":
            continue
        m=extract(line,NODE_ALLOWED)
        key=(m["HISTORY"],int(m["STEP"]))
        if key not in TARGETS:
            continue
        node=int(m["NODE"])
        nodes[key][node]=(float(m["H"]),float(m["THETA"]))
    for key in TARGETS:
        assert len(nodes[key])==16,(key,len(nodes[key]))

    paths={"A":Path(args.output_a),"B":Path(args.output_b)}
    for key,label in TARGETS.items():
        with paths[label].open("w",encoding="utf-8") as f:
            for node in range(1,17):
                h,theta=nodes[key][node]
                f.write(f"{node} {h:.17g} {theta:.17g}\n")

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06d04.origin_extract.v1",
      "origins":{
        TARGETS[k]:{
          "split":"DISCOVERY","history":k[0],"step":k[1],
          "original_time_text":metadata[k]["T"],
          "producing_interval_fallback":metadata[k]["FALLBACK"],
          "nodes":16
        } for k in TARGETS
      },
      "response_fields_parsed":False,
      "heldout_node_observables_parsed":0
    }
    print("RZM06D04_ORIGIN_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06D04_ORIGIN_EXTRACT=PASS")

if __name__=="__main__":
    main()
