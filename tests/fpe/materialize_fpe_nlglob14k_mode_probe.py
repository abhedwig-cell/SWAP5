#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

needle="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
      do nl14f_i=1,numnod
"""
repl="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
      call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
      call base_constitutive%evaluate(state%pressure_head,tmp_theta,tmp_k,tmp_cap,tmp_dk)
      call origin_derivative(state,k_origin,theta_dot_n,pdot0,run0,r0,qtop0)
      do nl14f_i=1,numnod
        write(*,'(*(g0))') 'F_PE_NLGLOB14K_PROBE|STEP=',step_index,'|NODE=',nl14f_i, &
             '|THETA_EVAL=',tmp_theta(nl14f_i),'|CAP=',tmp_cap(nl14f_i), &
             '|THETA_DOT=',theta_dot_n(nl14f_i)
      end do
      do nl14f_i=1,numnod
"""
if needle not in src:
    raise SystemExit("NLGLOB14K accepted-state logger marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB14K_PROBE" not in src:
    raise SystemExit("NLGLOB14K probe injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14K_MATERIALIZER=PASS")
