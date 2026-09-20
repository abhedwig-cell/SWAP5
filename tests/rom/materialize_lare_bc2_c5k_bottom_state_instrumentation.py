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

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5i-history-slice-materializer",required=True,type=pathlib.Path)
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
        base=td/"c5i_slice.f90"
        bm=td/"c5i_slice_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5i_history_slice_materializer),
          "--c5i-materializer",str(a.c5i_materializer),
          "--c5e-materializer",str(a.c5e_materializer),
          "--c5d-materializer",str(a.c5d_materializer),
          "--c5c-materializer",str(a.c5c_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--history-index",str(a.history_index),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False or m.get("solver_or_physics_changed") is not False:
            raise SystemExit("C5I history slice is not an admissible instrumentation base")
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "      call configure_symbol(symbol,h0,k0,qeq,p,forcing)\n"
      "      t1=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt",
      "      call configure_symbol(symbol,h0,k0,qeq,p,forcing)\n"
      "      call emit_c5k_prestate(ih,step,symbol,state,forcing)\n"
      "      t1=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt",
      "pre-step instrumentation call"
    )

    text=one(
      text,
      "      write(*,'(*(g0))') 'LAREGW1_STATE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &",
      "      write(*,'(*(g0))') 'LAREGW1_C5K_POST|HISTORY=',trim(history_label(ih)),'|STEP=',step, &\n"
      "           '|SYMBOL=',trim(symbol_label(symbol)),'|H_LAST=',physical%pressure_head(numnod), &\n"
      "           '|H_BOT=',forcing%bottom_head,'|BOTTOM_OUTWARD_EXCHANGE=',bex,'|BOTTOM_FLUX=',bflux\n"
      "      write(*,'(*(g0))') 'LAREGW1_STATE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &",
      "post-step instrumentation anchored on unique state output"
    )

    marker="  subroutine metrics_from_physical(physical,total,upper,lower)\n"
    sub="""  subroutine emit_c5k_prestate(ih,step,symbol,state,forcing)
    integer,intent(in) :: ih,step,symbol
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    class(transaction_state_t),allocatable :: snap
    logical :: got
    call state%snapshot(snap,got)
    call require(got,'LAREGW1 C5K pre-step snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      call require(physical%active_nodes==numnod,'LAREGW1 C5K pre-step geometry')
      call require(ieee_is_finite(physical%pressure_head(numnod)),'LAREGW1 C5K finite pre-step bottom head')
      write(*,'(*(g0))') 'LAREGW1_C5K_PRE|HISTORY=',trim(history_label(ih)),'|STEP=',step, &
           '|SYMBOL=',trim(symbol_label(symbol)),'|H_LAST=',physical%pressure_head(numnod), &
           '|H_BOT=',forcing%bottom_head
    class default
      call require(.false.,'LAREGW1 C5K expected B110 pre-step state')
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine emit_c5k_prestate

"""
    text=one(text,marker,sub+marker,"instrumentation subroutine insertion")

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5k.bottom-state-instrumentation.v1",
      "history_index":a.history_index,
      "history_label":f"Z{a.history_index:02d}",
      "base_c5i_history_slice_materializer_sha256":sha256(a.c5i_history_slice_materializer),
      "source_harness_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "instrumentation":["pre-step committed last-cell pressure head and prescribed hbot",
                         "post-step accepted last-cell pressure head plus existing published bottom exchange/flux"],
      "solver_input_changed":False,
      "solver_or_physics_changed":False,
      "state_trajectory_changed":False,
      "numerical_policy_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
