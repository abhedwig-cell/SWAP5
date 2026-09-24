#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,subprocess,sys,tempfile

def one(text,old,new,label):
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"p6a.f90"; bm=td/"p6a.json"
        subprocess.run([
          sys.executable,"tests/rom/materialize_rom_purpose_p5c_gw_reference.py",
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),"--material",a.material,
          "--temporal-factor","8","--output",str(base),"--manifest",str(bm)
        ],check=True)
        text=base.read_text()
        m=json.loads(bm.read_text())

    text=one(text,
      "    real(real64) :: h0,k0,qeq,t0,t1,mass,bex,bflux\n",
      "    real(real64) :: h0,k0,qeq,t0,t1,mass,bex,bflux,pre_bottom_h,post_bottom_h\n"
      "    class(transaction_state_t),allocatable :: pre_snap,post_snap\n"
      "    logical :: got_pre,got_post\n",
      "P6A run-history declarations")

    old="""      call strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
      call require(ok,'ROM1A accepted history step')"""
    new="""      call state%snapshot(pre_snap,got_pre)
      call require(got_pre,'LAREGW1 P6A pre-step snapshot')
      select type(pre=>pre_snap)
      type is(fmr_b110_physical_state_t)
        pre_bottom_h=pre%pressure_head(numnod)
      class default
        call require(.false.,'LAREGW1 P6A pre-step physical state')
      end select
      if(allocated(pre_snap))deallocate(pre_snap)
      call strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
      call require(ok,'LAREGW1 accepted history step')
      call state%snapshot(post_snap,got_post)
      call require(got_post,'LAREGW1 P6A post-step snapshot')
      select type(post=>post_snap)
      type is(fmr_b110_physical_state_t)
        post_bottom_h=post%pressure_head(numnod)
      class default
        call require(.false.,'LAREGW1 P6A post-step physical state')
      end select
      if(allocated(post_snap))deallocate(post_snap)
      if(symbol/=SYM_HOLD)then
        write(*,'(*(g0))') 'ROMPURP_P6A_BOUNDARY_ORACLE|HISTORY=',trim(history_label(ih)), &
             '|STEP=',step,'|PRE_BOTTOM_H=',pre_bottom_h,'|POST_BOTTOM_H=',post_bottom_h, &
             '|HBOT=',forcing%bottom_head,'|BOTTOM_OUTWARD_FLUX=',bflux,'|BOTTOM_MODE=5'
      end if"""
    text=one(text,old,new,"P6A pre/post boundary oracle instrumentation")
    a.output.write_text(text)

    out={
      "schema":"swap5.rom-purpose.p6a.materialization.v1",
      "material":a.material,"route":"R512_T8",
      "base":m,"marker":"ROMPURP_P6A_BOUNDARY_ORACLE",
      "solver_or_physics_changed":False,"numerical_policy_changed":False,
      "tolerance_changed":False,"response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")

if __name__=="__main__": main()
