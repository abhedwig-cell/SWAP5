#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

decl="  integer :: nl14f_event_node\n"
if decl not in src:
    raise SystemExit("NLGLOB14Q global declaration marker missing")
src=src.replace(decl,decl+"  integer :: nl14q_prev_sat_count\n  logical :: nl14q_shadow_done\n",1)

init="  nl14f_event_node=0\n"
if init not in src:
    raise SystemExit("NLGLOB14Q init marker missing")
src=src.replace(init,init+"  nl14q_prev_sat_count=0\n  nl14q_shadow_done=.false.\n",1)

decl2="    integer::r0,rp,nl14f_i\n"
if decl2 not in src:
    raise SystemExit("NLGLOB14Q advance_klag declaration marker missing")
src=src.replace(decl2,decl2+"""    integer::nl14q_sat_count,nl14q_saved_target,nl14q_shadow_route,nl14q_shadow_sat
    integer::nl14q_saved_origin,nl14q_saved_pred,nl14q_saved_endpoint,nl14q_saved_accept,nl14q_saved_status
    logical::nl14q_shadow_domain,nl14q_shadow_finite
    logical::nl14q_saved_eligible
    real(real64)::nl14q_saved_cumledger,nl14q_saved_cumrunoff,nl14q_saved_maxledger,nl14q_shadow_ledger
    integer::nl14q_saved_transition
    character(len=64)::nl14q_saved_terminal
    type(soil_water_physical_state_t)::nl14q_saved_state
    type(reference_richards_legacy_workspace_t)::nl14q_saved_ws
""",1)

needle="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
"""
repl="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
      nl14q_sat_count=count(state%pressure_head>=0.0_real64 .and. state%water_content==ts)
      if((.not.nl14q_shadow_done) .and. nl14q_prev_sat_count==14 .and. nl14q_sat_count==13)then
        nl14q_saved_state=state
        nl14q_saved_ws=ws
        nl14q_saved_cumledger=cumledger
        nl14q_saved_cumrunoff=cumrunoff
        nl14q_saved_maxledger=maxledger
        nl14q_saved_eligible=eligible
        nl14q_saved_terminal=terminal_reason
        nl14q_saved_transition=transition_step
        nl14q_saved_target=target_route
        nl14q_saved_origin=last_origin_route
        nl14q_saved_pred=last_pred_route
        nl14q_saved_endpoint=last_endpoint_route
        nl14q_saved_accept=last_accept_route
        nl14q_saved_status=last_solver_status

        call origin_derivative(state,k_origin,theta_dot_n,pdot0,run0,nl14q_shadow_route,qtop0)
        target_route=nl14q_shadow_route
        eligible=.true.
        terminal_reason='COMPLETE_SAME_ROUTE'
        transition_step=0
        call advance_tg_core(step_index,dt,nl14q_shadow_domain)

        nl14q_shadow_sat=count(state%pressure_head>=0.0_real64 .and. state%water_content==ts)
        nl14q_shadow_finite=all(ieee_is_finite(state%pressure_head)) .and. &
             all(ieee_is_finite(state%water_content)) .and. ieee_is_finite(state%ponding_depth)
        nl14q_shadow_ledger=cumledger-nl14q_saved_cumledger
        write(*,'(*(g0))') 'F_PE_NLGLOB14Q_SHADOW|STEP=',step_index,'|ORIGIN_ROUTE=',nl14q_shadow_route, &
             '|DOMAIN=',merge(1,0,nl14q_shadow_domain),'|ELIGIBLE=',merge(1,0,eligible), &
             '|TERMINAL=',trim(terminal_reason),'|SOLVER_STATUS=',last_solver_status, &
             '|PRED_ROUTE=',last_pred_route,'|ENDPOINT_ROUTE=',last_endpoint_route, &
             '|ACCEPT_ROUTE=',last_accept_route,'|FINITE=',merge(1,0,nl14q_shadow_finite), &
             '|SHADOW_SAT=',nl14q_shadow_sat,'|SHADOW_LEDGER=',nl14q_shadow_ledger

        state=nl14q_saved_state
        ws=nl14q_saved_ws
        cumledger=nl14q_saved_cumledger
        cumrunoff=nl14q_saved_cumrunoff
        maxledger=nl14q_saved_maxledger
        eligible=nl14q_saved_eligible
        terminal_reason=nl14q_saved_terminal
        transition_step=nl14q_saved_transition
        target_route=nl14q_saved_target
        last_origin_route=nl14q_saved_origin
        last_pred_route=nl14q_saved_pred
        last_endpoint_route=nl14q_saved_endpoint
        last_accept_route=nl14q_saved_accept
        last_solver_status=nl14q_saved_status
        write(*,'(*(g0))') 'F_PE_NLGLOB14Q_ROLLBACK|STEP=',step_index, &
             '|H=',maxval(abs(state%pressure_head-nl14q_saved_state%pressure_head)), &
             '|THETA=',maxval(abs(state%water_content-nl14q_saved_state%water_content)), &
             '|POND=',abs(state%ponding_depth-nl14q_saved_state%ponding_depth), &
             '|LEDGER=',abs(cumledger-nl14q_saved_cumledger),'|RUNOFF=',abs(cumrunoff-nl14q_saved_cumrunoff)
        nl14q_shadow_done=.true.
      end if
      nl14q_prev_sat_count=nl14q_sat_count
"""
if needle not in src:
    raise SystemExit("NLGLOB14Q accepted-state marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB14Q_SHADOW" not in src or "F_PE_NLGLOB14Q_ROLLBACK" not in src:
    raise SystemExit("NLGLOB14Q injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14Q_MATERIALIZER=PASS")
