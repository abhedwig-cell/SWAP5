#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

dynamic_old="""    theta_tilde=state%water_content+dt*theta_dot_n
    if(any(theta_tilde<=tr) .or. any(theta_tilde>=ts))then
      terminal_reason='PREDICTED_RETENTION_DOMAIN_FAILED'
      eligible=.false.; transition_step=step_index; return
    end if
    do i=1,numnod
      head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
    end do
    predstate=state
    predstate%water_content=theta_tilde
    predstate%pressure_head=head_tilde
"""
dynamic_new="""    theta_tilde=state%water_content+dt*theta_dot_n
    if(any(theta_tilde<=tr))then
      terminal_reason='PREDICTED_RETENTION_DOMAIN_FAILED'
      eligible=.false.; transition_step=step_index; return
    end if
    do i=1,numnod
      if(theta_tilde(i)>=ts)then
        head_tilde(i)=0.0_real64
      else
        head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
      end if
    end do
    predstate=state
    predstate%water_content=min(theta_tilde,ts)
    predstate%pressure_head=head_tilde
"""
if dynamic_old in src:
    src=src.replace(dynamic_old,dynamic_new,1)
else:
    smooth_old="""    theta_tilde=state%water_content+dt*theta_dot_n
    call require(all(theta_tilde>tr) .and. all(theta_tilde<ts),'predicted theta outside unsaturated retention domain')
    do i=1,numnod
      head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    call require(maxval(abs(tmp_theta-theta_tilde))<=1.0e-12_real64,'predicted-state retention roundtrip failed')
"""
    smooth_new="""    theta_tilde=state%water_content+dt*theta_dot_n
    call require(all(theta_tilde>tr),'predicted theta below retention domain')
    do i=1,numnod
      if(theta_tilde(i)>=ts)then
        head_tilde(i)=0.0_real64
      else
        head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
      end if
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    call require(maxval(abs(tmp_theta-min(theta_tilde,ts)))<=1.0e-12_real64,'predicted-state saturation extension mismatch')
"""
    if smooth_old not in src:
        raise SystemExit("NLGLOB11 predictor marker missing")
    src=src.replace(smooth_old,smooth_new,1)

if "theta_tilde(i)>=ts" not in src:
    raise SystemExit("NLGLOB11 saturation extension injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB11_MATERIALIZER=PASS")
