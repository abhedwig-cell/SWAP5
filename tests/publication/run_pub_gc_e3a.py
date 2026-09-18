from __future__ import annotations

import argparse
import csv
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT=Path(__file__).resolve().parents[2]
SUPPORT=ROOT/"tests"/"fgc"/"support"
sys.path.insert(0,str(SUPPORT))

from fgc44_real_swap_ctypes import Fgc44RealSwap

INIT_DURATIONS=(
    1.0e-5,2.5e-5,5.0e-5,6.25e-5,7.5e-5,8.75e-5,
    1.0e-4,2.0e-4,4.0e-4,
)
TRIAL_DURATIONS=(1.0e-4,2.0e-4,4.0e-4)
OFFSETS=(0.0,1e-6,-1e-6,2e-6,-2e-6,5e-6,-5e-6,1e-5,-1e-5,
         2e-5,-2e-5,5e-5,-5e-5,1e-4,-1e-4,2e-4,-2e-4,5e-4,-5e-4)


def init_case(library:Path,duration:float)->dict[str,Any]:
    swap=Fgc44RealSwap(library)
    try:
        _,_,href=swap.initialize_window(duration)
        e1=swap.e1_diagnostics()
        return {
            "kind":"init","duration_day":duration,"status":"OK",
            "init_stage":swap.init_stage(),"reference_head_m":href,
            "u":float(e1["u"]),
        }
    except Exception as exc:
        stage=-1
        try: stage=swap.init_stage()
        except Exception: pass
        return {
            "kind":"init","duration_day":duration,"status":"FAILED",
            "init_stage":stage,"error":str(exc),
        }


def trial_case(library:Path,duration:float,offset:float)->dict[str,Any]:
    swap=Fgc44RealSwap(library)
    try:
        _,_,href=swap.initialize_window(duration)
    except Exception as exc:
        stage=-1
        try: stage=swap.init_stage()
        except Exception: pass
        return {
            "kind":"trial","duration_day":duration,"offset_m":offset,
            "status":"INITIALIZE_FAILED","init_stage":stage,"error":str(exc),
        }
    head=href+offset
    try:
        diag=swap.diagnostic_trial(head)
    except Exception as exc:
        return {
            "kind":"trial","duration_day":duration,"offset_m":offset,
            "reference_head_m":href,"head_m":head,
            "status":"DIAGNOSTIC_CALL_FAILED","error":str(exc),
        }
    result={
        "kind":"trial","duration_day":duration,"offset_m":offset,
        "reference_head_m":href,"head_m":head,
        "status":"OK" if diag["completed"] else "FAILED",
    }
    result.update(diag)
    return result


def child_main(args:argparse.Namespace)->int:
    library=Path(args.library).resolve()
    if args.kind=="init":
        result=init_case(library,args.duration)
    else:
        result=trial_case(library,args.duration,args.offset)
    Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    return 0


def run_child(library:Path,kind:str,duration:float,out:Path,offset:float=0.0)->dict[str,Any]:
    cmd=[sys.executable,str(Path(__file__).resolve()),"--child","--kind",kind,
         "--library",str(library),"--duration",repr(duration),"--output",str(out)]
    if kind=="trial":
        cmd += ["--offset",repr(offset)]
    p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if p.returncode:
        raise RuntimeError(f"E3A child infrastructure failure\nstdout:\n{p.stdout}\nstderr:\n{p.stderr}")
    return json.loads(out.read_text())


def main()->int:
    library=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    outdir=Path(os.environ.get("PUB_GC_EVIDENCE_DIR",ROOT/"build"/"pub-gc-e3a")).resolve()
    outdir.mkdir(parents=True,exist_ok=True)
    cases=outdir/"cases"; cases.mkdir(exist_ok=True)

    init_records=[]
    for duration in INIT_DURATIONS:
        path=cases/f"init-{duration:.8g}.json"
        rec=run_child(library,"init",duration,path)
        init_records.append(rec)
        print(f"E3A_INIT duration={duration:.8g} status={rec['status']} stage={rec.get('init_stage')}")

    trial_records=[]
    for duration in TRIAL_DURATIONS:
        for offset in OFFSETS:
            tag=f"{offset:+.8g}".replace("+","p").replace("-","m").replace(".","d")
            path=cases/f"trial-{duration:.8g}-{tag}.json"
            rec=run_child(library,"trial",duration,path,offset)
            trial_records.append(rec)
            print(
                f"E3A_TRIAL duration={duration:.8g} offset={offset:+.8g} "
                f"status={rec['status']} kernel={rec.get('kernel_status','NA')} "
                f"retry={rec.get('retries','NA')} solverrej={rec.get('solver_rejections','NA')} "
                f"temprej={rec.get('temporal_rejections','NA')} massrej={rec.get('mass_rejections','NA')}"
            )

    initialized=[r["duration_day"] for r in init_records if r["status"]=="OK"]
    minimum_initialized=min(initialized) if initialized else None

    envelope={}
    for duration in TRIAL_DURATIONS:
        rows=[r for r in trial_records if r["duration_day"]==duration]
        successful=[r["offset_m"] for r in rows if r["status"]=="OK"]
        pos=[x for x in successful if x>=0.0]
        neg=[x for x in successful if x<=0.0]
        envelope[str(duration)]={
            "max_success_positive_offset_m":max(pos) if pos else None,
            "max_success_negative_magnitude_m":max(abs(x) for x in neg) if neg else None,
            "successful_count":len(successful),
            "attempted_count":len(rows),
        }

    result={
        "schema":"pub-gc-e3a-envelope-result-v1",
        "parent_e3_first_run_id":35343698622,
        "init_durations_day":INIT_DURATIONS,
        "trial_durations_day":TRIAL_DURATIONS,
        "offsets_m":OFFSETS,
        "minimum_initialized_duration_day":minimum_initialized,
        "init_records":init_records,
        "trial_records":trial_records,
        "envelope":envelope,
    }
    (outdir/"PUB_GC_E3A_RESULT.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")

    fields=["duration_day","offset_m","status","init_stage","reference_head_m","head_m",
            "kernel_status","completed","retries","solver_rejections","temporal_rejections",
            "mass_rejections","accepted_substeps","bottom_exchange_cm","error"]
    with (outdir/"PUB_GC_E3A_TRIALS.csv").open("w",newline="") as h:
        w=csv.DictWriter(h,fieldnames=fields,extrasaction="ignore")
        w.writeheader()
        for r in trial_records: w.writerow(r)

    print(f"PUB_GC_E3A_MIN_INITIALIZED_DURATION_DAY={minimum_initialized}")
    print("PUB_GC_E3A_MATRIX_ATTEMPTED=PASS")
    if all(any(r["duration_day"]==d and r["offset_m"]==0.0 and r["status"]=="OK" for r in trial_records)
           for d in TRIAL_DURATIONS):
        print("PUB_GC_E3A_ZERO_OFFSET_CONTROL=PASS")
    else:
        print("PUB_GC_E3A_ZERO_OFFSET_CONTROL=FAIL")
        return 2
    print("PUB_GC_E3A_EVIDENCE_RUN=PASS")
    return 0


def parse()->argparse.Namespace:
    p=argparse.ArgumentParser()
    p.add_argument("--child",action="store_true")
    p.add_argument("--kind",choices=("init","trial"))
    p.add_argument("--library")
    p.add_argument("--duration",type=float)
    p.add_argument("--offset",type=float,default=0.0)
    p.add_argument("--output")
    return p.parse_args()


if __name__=="__main__":
    args=parse()
    if args.child:
        if not args.kind or not args.library or args.duration is None or not args.output:
            raise SystemExit("missing E3A child arguments")
        raise SystemExit(child_main(args))
    raise SystemExit(main())
