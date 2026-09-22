#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re
from pathlib import Path

SHADOW=re.compile(r"RNP02_SHADOW128\|STATUS=(?P<status>\d+)\|ROUTE=(?P<route>[^|]+)\|NL=(?P<nl>\d+)\|BACKTRACK=(?P<bt>\d+)\|SUM=(?P<sum>[^|]+)\|FMAX=(?P<fmax>[^|]+)\|SUMP=(?P<sump>.+)$",re.MULTILINE)
TRACE=re.compile(r"RNP02_TRACE\|IT=(?P<it>\d+)\|BT=(?P<bt>\d+)\|FACTOR=(?P<factor>[^|]+)\|SUM=(?P<sum>[^|]+)\|FMAX=(?P<fmax>[^|]+)\|SUMP=(?P<sump>[^|]+)\|SUMOLD=(?P<sumold>.+)$",re.MULTILINE)

def parse(path:Path):
    raw=path.read_text(errors="replace")
    sm=SHADOW.search(raw)
    if not sm:
        raise SystemExit(f"shadow summary missing: {path}")
    traces=[]
    for m in TRACE.finditer(raw):
        traces.append({k:(int(m[k]) if k in ("it","bt") else m[k].strip()) for k in m.groupdict()})
    if not traces:
        raise SystemExit(f"trace missing: {path}")
    terminal={}
    for row in traces:
        terminal[row["it"]]=row
    seen={}
    recurrences=[]
    for it in sorted(terminal):
        row=terminal[it]
        key=(row["sum"],row["fmax"],row["sump"])
        if key in seen:
            recurrences.append({"first_iteration":seen[key],"repeat_iteration":it,"tuple":{"sum":key[0],"fmax":key[1],"sump":key[2]}})
        else:
            seen[key]=it
    return {
      "shadow128":{
        "status":int(sm["status"]),"route":sm["route"].strip(),"nonlinear_iterations":int(sm["nl"]),
        "backtracking_attempts":int(sm["bt"]),"sum":float(sm["sum"]),"fmax":float(sm["fmax"]),"sump":float(sm["sump"])
      },
      "trace_records":len(traces),
      "terminal_iterations":len(terminal),
      "exact_terminal_recurrences":recurrences
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--target",required=True,type=Path)
    ap.add_argument("--control",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    target=parse(args.target); control=parse(args.control)
    cls={
      "TARGET_CONVERGES_BY_128":target["shadow128"]["status"]==1,
      "TARGET_PERSISTS_TO_128":target["shadow128"]["status"]==2,
      "EXACT_TERMINAL_RECURRENCE":bool(target["exact_terminal_recurrences"]),
      "CONTROL_PRESERVATION":control["shadow128"]["status"]==1
    }
    result={
      "schema":"swap5.rom_root.rnp02.result.v1",
      "work_unit":"ROM-ROOT-RNP02",
      "status":"TRACE_COMPLETE_NO_POLICY_DECISION",
      "target":target,
      "control":control,
      "classifications":cls,
      "policy_decision_authorized":False,
      "c6r_reopened":False,
      "reduced_candidate_response_generated":False,
      "production_source_changed":False
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":result["status"],"classifications":cls},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
