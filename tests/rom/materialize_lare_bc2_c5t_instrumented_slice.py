#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def block(text:str,pattern:str,replacement:str,label:str)->str:
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5t-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5r-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5p-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5n-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--history-index",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5t_full.f90"; bm=td/"c5t_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5t_materializer),
          "--c5r-materializer",str(a.c5r_materializer),
          "--c5p-materializer",str(a.c5p_materializer),
          "--c5n-materializer",str(a.c5n_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False or m.get("logging_only") is not True:
            raise SystemExit("C5T full materializer contract failed")
        text=base.read_text(encoding="utf-8")

    idx=a.history_index
    driver=f"  ih={idx}\n  call run_history(ih,total_states,total_fallbacks,max_abs_mass)\n"
    text=block(
      text,
      r"^  do ih=1,NHIST\n\s+call run_history\(ih,total_states,total_fallbacks,max_abs_mass\)\n\s+end do\n",
      driver,
      "history driver"
    )
    text=one(
      text,
      "call require(total_states==NHIST*NSTEPS,'LAREGW1 exact library state count')",
      "call require(total_states==NSTEPS,'LAREGW1 exact C5T sliced history state count')",
      "state count"
    )
    text=one(
      text,
      "write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',NHIST",
      "write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',1",
      "history count output"
    )
    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5t.instrumented-history-slice.v1",
      "history_index":idx,
      "history_label":f"R{idx:02d}",
      "temporal_factor":16,
      "steps_per_history":16384,
      "transaction_dt_day":0.00005,
      "c5t_materializer_sha256":sha256(a.c5t_materializer),
      "source_harness_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "diagnostic_lines":{"layer":12288,"face":11264},
      "logging_only":True,
      "history_state_continuity_changed":False,
      "solver_or_physics_changed":False,
      "numerical_policy_changed":False,
      "candidate_feedback":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
