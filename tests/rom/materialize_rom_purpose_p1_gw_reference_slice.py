#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--base-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--history-index",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"p1_gw_full.f90"
        bm=td/"p1_gw_full_manifest.json"
        subprocess.run([
            sys.executable,str(a.base_materializer),
            "--c5a-materializer",str(a.c5a_materializer),
            "--c4z-materializer",str(a.c4z_materializer),
            "--source",str(a.source),
            "--material",a.material,
            "--temporal-factor",str(a.temporal_factor),
            "--output",str(base),
            "--manifest",str(bm),
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("P1 GW base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    idx=a.history_index
    driver=f"  ih={idx}\n  call run_history(ih,total_states,total_fallbacks,max_abs_mass)\n"
    text=one(
        text,
        "  do ih=1,NHIST\n    call run_history(ih,total_states,total_fallbacks,max_abs_mass)\n  end do\n",
        driver,
        "single-history driver",
    )
    text=one(
        text,
        "  call require(total_states==NHIST*NSTEPS,'LAREGW1 exact library state count')",
        "  call require(total_states==NSTEPS,'LAREGW1 exact P1 sliced history state count')",
        "state count",
    )
    text=one(
        text,
        "  write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',NHIST",
        "  write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',1",
        "history count output",
    )

    a.output.write_text(text,encoding="utf-8")
    out={
        "schema":"swap5.rom-purpose.p1.gw-reference-history-slice.v1",
        "history_index":idx,
        "history_label":f"G{idx:02d}",
        "material":a.material,
        "temporal_factor":a.temporal_factor,
        "steps_per_history":1024*a.temporal_factor,
        "transaction_dt_day":0.0008/a.temporal_factor,
        "base_materializer_sha256":sha256(a.base_materializer),
        "source_harness_sha256":sha256(a.source),
        "output_sha256":sha256(a.output),
        "history_state_continuity_changed":False,
        "solver_or_physics_changed":False,
        "numerical_policy_changed":False,
        "forcing_changed":False,
        "diagnostic_partition_only":True,
        "response_based":False,
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
