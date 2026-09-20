#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

FACTOR=16

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def block(text,pattern,replacement,label):
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def history_block()->str:
    a=256*FACTOR; b=576*FACTOR; c=320*FACTOR
    return f"""  integer function history_symbol(ih,step) result(symbol)
    integer,intent(in) :: ih,step
    select case(ih)
    case(1)
      if(step<={a})then; symbol=SYM_FALL
      else if(step<={b})then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(2)
      if(step<={a})then; symbol=SYM_RISE
      else if(step<={b})then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case(3)
      if(step<={c})then; symbol=SYM_FALL
      else if(step<={b})then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(4)
      if(step<={c})then; symbol=SYM_RISE
      else if(step<={b})then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case default
      symbol=0
    end select
    call require(symbol==SYM_HOLD.or.symbol==SYM_RISE.or.symbol==SYM_FALL,'LAREGW1 C5I valid boundary-only symbol')
  end function history_symbol
"""

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5e-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5d-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5c-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5e_base.f90"
        bm=td/"base_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5e_materializer),
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
            raise SystemExit("C5E base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    text=one(text,"integer, parameter :: NHIST=4, NSTEPS=1024",
             "integer, parameter :: NHIST=4, NSTEPS=16384","temporal state count")
    text=one(text,"real(real64), parameter :: step_dt=0.0008_real64",
             "real(real64), parameter :: step_dt=0.00005_real64","main transaction interval")
    text=block(text,r"^  integer function history_symbol\(ih,step\) result\(symbol\).*?^  end function history_symbol\n",
               history_block(),"physical-time matched history symbols")
    text=one(text,
      "write(*,'(A)') 'LAREGW1_C5E_B14_REFERENCE_EXTENSION_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5I_B14_T16_GENERATED=TRUE'",
      "completion marker")

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5i.t16-materialization.v1",
      "temporal_factor":16,
      "main_step_dt_day":0.00005,
      "main_steps_per_history":16384,
      "physical_horizon_day":0.8192,
      "seed_dt_day":0.0016,
      "seed_intervals":2,
      "seed_path_changed":False,
      "physical_history_switch_times_changed":False,
      "head_multipliers_changed":False,
      "reference_retry_policy_changed":False,
      "solver_or_physics_changed":False,
      "node_output_suppressed":True,
      "state_output_retained":True,
      "response_based":False,
      "source_harness_sha256":sha256(a.source),
      "c5e_materializer_sha256":sha256(a.c5e_materializer),
      "output_sha256":sha256(a.output)
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
