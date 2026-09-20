#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def block(text:str,pattern:str,replacement:str,label:str)->str:
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5i-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5e-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5d-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5c-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--history-index",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5i_full.f90"
        bm=td/"c5i_full_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5i_materializer),
          "--c5e-materializer",str(a.c5e_materializer),
          "--c5d-materializer",str(a.c5d_materializer),
          "--c5c-materializer",str(a.c5c_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C5I full materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    idx=a.history_index
    driver=(
      f"  ih={idx}\n"
      "  call run_history(ih,total_states,total_fallbacks,max_abs_mass)\n"
    )
    text=block(
      text,
      r"^  do ih=1,NHIST\n\s+call run_history\(ih,total_states,total_fallbacks,max_abs_mass\)\n\s+end do\n",
      driver,
      "history driver"
    )
    text=one(
      text,
      "call require(total_states==NHIST*NSTEPS,'LAREGW1 exact library state count')",
      "call require(total_states==NSTEPS,'LAREGW1 exact sliced history state count')",
      "sliced state-count guard"
    )
    text=one(
      text,
      "write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',NHIST",
      "write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',1",
      "sliced history-count output"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5i.history-slice-materialization.v1",
      "history_index":idx,
      "history_label":f"Z{idx:02d}",
      "full_c5i_materializer_sha256":sha256(a.c5i_materializer),
      "source_harness_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "temporal_factor":16,
      "main_step_dt_day":0.00005,
      "main_steps":16384,
      "physical_history_changed":False,
      "history_initialization_changed":False,
      "history_state_continuity_changed":False,
      "numerical_policy_changed":False,
      "solver_or_physics_changed":False,
      "diagnostic_partition_only":True,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
