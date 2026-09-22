from __future__ import annotations
import argparse, json
from pathlib import Path

ALLOWED_STATE={"SPLIT","HISTORY","STEP","FALLBACK"}
ALLOWED_NODE={"SPLIT","HISTORY","STEP","NODE","H","THETA"}

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
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    root=Path(args.artifact_dir)
    lines=(root/"o0.txt").read_text().splitlines()
    candidates=[]
    for line in lines:
        if not line.startswith("ROM1AR2_STATE|"):
            continue
        split=extract(line,{"SPLIT"}).get("SPLIT")
        if split!="DISCOVERY":
            continue
        m=extract(line,ALLOWED_STATE)
        if m.get("FALLBACK")!="F":
            continue
        candidates.append((m["SPLIT"],m["HISTORY"],int(m["STEP"])))
    key=min(candidates)
    assert key==("DISCOVERY","D01",1),key

    nodes={}
    for line in lines:
        if not line.startswith("ROM1AR2_NODE|"):
            continue
        split=extract(line,{"SPLIT"}).get("SPLIT")
        if split!="DISCOVERY":
            continue
        m=extract(line,ALLOWED_NODE)
        k=(m["SPLIT"],m["HISTORY"],int(m["STEP"]))
        if k!=key:
            continue
        nodes[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
    assert len(nodes)==16
    out=Path(args.output)
    with out.open("w") as f:
        for i in range(1,17):
            h,theta=nodes[i]
            f.write(f"{i} {h:.17g} {theta:.17g}\n")
    evidence={
      "selected_by":"lexicographically first strict DISCOVERY provenance",
      "split":key[0],"history":key[1],"step":key[2],
      "nodes":16,
      "response_fields_parsed":False,
      "heldout_node_observables_parsed":0,
    }
    print("RZM06D02_AUDIT_ORIGIN_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06D02_AUDIT_ORIGIN=PASS")

if __name__=="__main__":
    main()
