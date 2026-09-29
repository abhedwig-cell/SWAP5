#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

smooth_old="""    theta_tilde=state%water_content+dt*theta_dot_n
    call require(all(theta_tilde>tr) .and. all(theta_tilde<ts),'predicted theta outside unsaturated retention domain')
    do i=1,numnod
      head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    call require(maxval(abs(tmp_theta-theta_tilde))<=1.0e-12_real64,'predicted-state retention roundtrip failed')
    call require(all(ieee_is_finite(k_tilde)) .and. all(k_tilde>0.0_real64),'invalid predicted K')
"""
smooth_new="""    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(state%pressure_head,tmp_theta,tmp_k,tmp_cap,tmp_dk)
    call require(all(ieee_is_finite(tmp_cap)) .and. all(tmp_cap>0.0_real64),'invalid origin capacity for head-space predictor')
    head_tilde=state%pressure_head+dt*theta_dot_n/tmp_cap
    call require(all(ieee_is_finite(head_tilde)),'nonfinite head-space predictor')
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    call require(all(ieee_is_finite(k_tilde)) .and. all(k_tilde>0.0_real64),'invalid predicted K')
"""

dyn_old="""    theta_tilde=state%water_content+dt*theta_dot_n
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
    predstate%ponding_depth=state%ponding_depth+dt*pdot_n
    if(predstate%ponding_depth<0.0_real64)then
      terminal_reason='PREDICTED_PONDING_NEGATIVE'
      eligible=.false.; transition_step=step_index; return
    end if
    call exact_state_k(predstate,k_tilde)
"""
dyn_new="""    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(state%pressure_head,tmp_theta,tmp_k,tmp_cap,tmp_dk)
    if(any(.not.ieee_is_finite(tmp_cap)) .or. any(tmp_cap<=0.0_real64))then
      terminal_reason='HEADSPACE_PREDICTOR_CAPACITY_FAILED'
      eligible=.false.; transition_step=step_index; return
    end if
    head_tilde=state%pressure_head+dt*theta_dot_n/tmp_cap
    if(any(.not.ieee_is_finite(head_tilde)))then
      terminal_reason='HEADSPACE_PREDICTOR_NONFINITE'
      eligible=.false.; transition_step=step_index; return
    end if
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    if(any(.not.ieee_is_finite(k_tilde)) .or. any(k_tilde<=0.0_real64))then
      terminal_reason='HEADSPACE_PREDICTOR_K_FAILED'
      eligible=.false.; transition_step=step_index; return
    end if
    predstate=state
    predstate%water_content=tmp_theta
    predstate%pressure_head=head_tilde
    predstate%ponding_depth=state%ponding_depth+dt*pdot_n
    if(predstate%ponding_depth<0.0_real64)then
      terminal_reason='PREDICTED_PONDING_NEGATIVE'
      eligible=.false.; transition_step=step_index; return
    end if
"""

changed=0
if smooth_old in src:
    src=src.replace(smooth_old,smooth_new,1); changed+=1
if dyn_old in src:
    src=src.replace(dyn_old,dyn_new,1); changed+=1
if changed!=1:
    raise SystemExit(f"NLGLOB11A expected exactly one predictor block, changed={changed}")
Path(args.output).write_text(src)
print("F_PE_NLGLOB11A_HEADSPACE_MATERIALIZER=PASS")
