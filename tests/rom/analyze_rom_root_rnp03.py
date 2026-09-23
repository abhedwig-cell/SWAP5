#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re, struct
from pathlib import Path

SHADOW=re.compile(r"RNP02_SHADOW128\|STATUS=(?P<status>\d+)\|ROUTE=(?P<route>[^|]+)\|NL=(?P<nl>\d+)\|BACKTRACK=(?P<bt>\d+)\|SUM=(?P<sum>[^|]+)\|FMAX=(?P<fmax>[^|]+)\|SUMP=(?P<sump>.+)$",re.MULTILINE)
VECTOR=re.compile(r"RNP03_VECTOR\|IT=(?P<it>\d+)\|I=(?P<i>\d+)\|H=(?P<h>[0-9A-Fa-f]{16})\|R=(?P<r>[0-9A-Fa-f]{16})$",re.MULTILINE)
PAIRS=[(26,50),(27,51),(32,56)]

def bits_to_float(h:str)->float:
    return struct.unpack(">d", bytes.fromhex(h))[0]

def parse(path:Path):
    raw=path.read_text(errors="replace")
    sm=SHADOW.search(raw)
    if not sm:
        raise SystemExit(f"shadow summary missing: {path}")
    snaps={}
    for m in VECTOR.finditer(raw):
        it=int(m["it"]); idx=int(m["i"])
        snaps.setdefault(it,{})[idx]=(m["h"].upper(),m["r"].upper())
    return {
      "shadow128":{
        "status":int(sm["status"]),"route":sm["route"].strip(),"nonlinear_iterations":int(sm["nl"]),
        "backtracking_attempts":int(sm["bt"]),"sum":float(sm["sum"]),"fmax":float(sm["fmax"]),"sump":float(sm["sump"])
      },
      "snapshots":snaps
    }

def compare_pair(snaps,a,b):
    aa=snaps.get(a,{}); bb=snaps.get(b,{})
    if not aa or not bb:
        raise SystemExit(f"missing snapshot {a} or {b}")
    if set(aa)!=set(bb):
        raise SystemExit(f"node-set mismatch {a} vs {b}")
    hdiff=0; rdiff=0; maxh=0.0; maxr=0.0
    for i in sorted(aa):
        ha,ra=aa[i]; hb,rb=bb[i]
        if ha!=hb:
            hdiff+=1
            maxh=max(maxh,abs(bits_to_float(ha)-bits_to_float(hb)))
        if ra!=rb:
            rdiff+=1
            maxr=max(maxr,abs(bits_to_float(ra)-bits_to_float(rb)))
    return {
      "pair":[a,b],"nodes":len(aa),
      "pressure_head_bit_differences":hdiff,
      "residual_bit_differences":rdiff,
      "max_abs_pressure_head_difference":maxh,
      "max_abs_residual_difference":maxr,
      "full_vector_bit_identity":hdiff==0 and rdiff==0
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--target",required=True,type=Path)
    ap.add_argument("--control",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    target=parse(args.target); control=parse(args.control)
    pair_results=[compare_pair(target["snapshots"],a,b) for a,b in PAIRS]
    control17=control["snapshots"].get(17,{})
    result={
      "schema":"swap5.rom_root.rnp03.result.v1",
      "work_unit":"ROM-ROOT-RNP03",
      "status":"FULL_VECTOR_TRACE_COMPLETE_NO_POLICY_DECISION",
      "target_shadow128":target["shadow128"],
      "control_shadow128":control["shadow128"],
      "target_pairs":pair_results,
      "classifications":{
        "MULTIPAIR_FULL_VECTOR_RECURRENCE":all(x["full_vector_bit_identity"] for x in pair_results),
        "AGGREGATE_ONLY_RECURRENCE":not all(x["full_vector_bit_identity"] for x in pair_results),
        "CONTROL_PRESERVATION":control["shadow128"]["status"]==1,
        "CONTROL_SNAPSHOT_PRESENT":len(control17)>0
      },
      "policy_decision_authorized":False,
      "c6r_reopened":False,
      "reduced_candidate_response_generated":False,
      "production_source_changed":False
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":result["status"],"classifications":result["classifications"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
