#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

# Global handoff/release state.
decl="  logical :: nl14d_saturated_mode\n"
if decl not in src:
    raise SystemExit("NLGLOB14R global declaration marker missing")
src=src.replace(decl,decl+"""  logical :: nl14r_handoff_pending,nl14r_released,nl14r_dry_tg
  integer :: nl14r_prev_sat_count,nl14r_retreat_step,nl14r_handoff_step,nl14r_reentries
""",1)

init="  nl14d_saturated_mode=.false.\n"
if init not in src:
    raise SystemExit("NLGLOB14R init marker missing")
src=src.replace(init,init+"""  nl14r_handoff_pending=.false.
  nl14r_released=.false.
  nl14r_dry_tg=.false.
  nl14r_prev_sat_count=0
  nl14r_retreat_step=0
  nl14r_handoff_step=0
  nl14r_reentries=0
""",1)

# Dry surface operator for TG after the handoff.
surf_old="""    kface=0.5_real64*(ksat+k_top)
    qhead=-kface*((pond-head_top)/p%node_distance(1)+1.0_real64)
"""
surf_new="""    if(nl14r_dry_tg .or. nl14r_released)then
      route=R_FLUX
      runoff_rate=0.0_real64
      qtop=rain
      pdot=0.0_real64
      return
    end if
    kface=0.5_real64*(ksat+k_top)
    qhead=-kface*((pond-head_top)/p%node_distance(1)+1.0_real64)
"""
if surf_old not in src:
    raise SystemExit("NLGLOB14R surface operator marker missing")
src=src.replace(surf_old,surf_new,1)

# Keep the dynamic-top provider on dry forcing after release as well as in saturated mode.
bind_old="""    if(nl14d_saturated_mode)then
      call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
"""
bind_new="""    if(nl14d_saturated_mode .or. nl14r_dry_tg .or. nl14r_released)then
      call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
"""
if bind_old not in src:
    raise SystemExit("NLGLOB14R dry provider marker missing")
src=src.replace(bind_old,bind_new,1)

# Use the dry physical mass contract for TG after release.
tg_start=src.find("  subroutine advance_tg_core")
tg_end=src.find("  end subroutine advance_tg_core",tg_start)
if tg_start<0 or tg_end<0:
    raise SystemExit("NLGLOB14R TG core bounds missing")
tgseg=src[tg_start:tg_end]
ledger_old="    ledger=storage1-storage0-rain*stepdt+runint-res%bottom_flux*stepdt\n"
ledger_new="""    if(nl14r_dry_tg .or. nl14r_released)then
      ledger=storage1-storage0+rain*stepdt-res%bottom_flux*stepdt
    else
      ledger=storage1-storage0-rain*stepdt+runint-res%bottom_flux*stepdt
    end if
"""
if ledger_old not in tgseg:
    raise SystemExit("NLGLOB14R TG ledger marker missing")
tgseg=tgseg.replace(ledger_old,ledger_new,1)
src=src[:tg_start]+tgseg+src[tg_end:]

# Detect first 14->13 retreat on accepted persistent-KLAG states and arm next-interval handoff.
decl2="    integer::r0,rp,nl14f_i\n"
if decl2 not in src:
    raise SystemExit("NLGLOB14R KLAG declaration marker missing")
src=src.replace(decl2,decl2+"    integer::nl14r_sat_count\n",1)

state_marker="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
"""
state_repl="""    state=res%candidate_state
    if(nl14d_saturated_mode)then
      nl14r_sat_count=count(state%pressure_head>=0.0_real64 .and. state%water_content==ts)
      if((.not.nl14r_released) .and. (.not.nl14r_handoff_pending) .and. &
           nl14r_prev_sat_count==14 .and. nl14r_sat_count==13)then
        nl14r_handoff_pending=.true.
        nl14r_retreat_step=step_index
        write(*,'(*(g0))') 'F_PE_NLGLOB14R_RETREAT|STEP=',step_index,'|SAT=',nl14r_sat_count, &
             '|ROUTE=',trim(topres%route),'|POND=',state%ponding_depth
      end if
      nl14r_prev_sat_count=nl14r_sat_count
"""
if state_marker not in src:
    raise SystemExit("NLGLOB14R KLAG accepted-state marker missing")
src=src.replace(state_marker,state_repl,1)

# Replace the next nominal saturated-mode interval by the accepted TG handoff interval.
wrapper_start=src.find("  subroutine advance_tg_subdiv(step_index)")
wrapper_end=src.find("  end subroutine advance_tg_subdiv",wrapper_start)
if wrapper_start<0 or wrapper_end<0:
    raise SystemExit("NLGLOB14R wrapper bounds missing")
wseg=src[wrapper_start:wrapper_end]
persist="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
"""
handoff="""    if(nl14r_handoff_pending)then
      nominal_dt=dt
      nl14r_dry_tg=.true.
      target_route=R_FLUX
      call advance_tg_core(step_index,nominal_dt,domain_fail)
      nl14r_dry_tg=.false.
      if(domain_fail .or. .not.eligible)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14R_HANDOFF|STEP=',step_index,'|OK=0|DOMAIN=',merge(1,0,domain_fail), &
             '|TERMINAL=',trim(terminal_reason),'|SOLVER_STATUS=',last_solver_status, &
             '|ORIGIN_ROUTE=',last_origin_route,'|PRED_ROUTE=',last_pred_route, &
             '|ENDPOINT_ROUTE=',last_endpoint_route,'|ACCEPT_ROUTE=',last_accept_route
        return
      end if
      nl14r_handoff_pending=.false.
      nl14d_saturated_mode=.false.
      nl14r_released=.true.
      nl14r_handoff_step=step_index
      nl14r_prev_sat_count=count(state%pressure_head>=0.0_real64 .and. state%water_content==ts)
      write(*,'(*(g0))') 'F_PE_NLGLOB14R_HANDOFF|STEP=',step_index,'|OK=1|DOMAIN=0', &
           '|TERMINAL=',trim(terminal_reason),'|SOLVER_STATUS=',last_solver_status, &
           '|ORIGIN_ROUTE=',last_origin_route,'|PRED_ROUTE=',last_pred_route, &
           '|ENDPOINT_ROUTE=',last_endpoint_route,'|ACCEPT_ROUTE=',last_accept_route, &
           '|SAT=',nl14r_prev_sat_count,'|LEDGER=',cumledger
      return
    end if

    if(nl14d_saturated_mode)then
      nominal_dt=dt
"""
if persist not in wseg:
    raise SystemExit("NLGLOB14R persistent wrapper marker missing")
wseg=wseg.replace(persist,handoff,1)

# Mark every ordinary TG-owned interval after handoff.
corecall="""    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(.not.domain_fail) return
"""
corecall_repl="""    call advance_tg_core(step_index,nominal_dt,domain_fail)
    if(nl14r_released .and. .not.domain_fail .and. eligible)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14R_TG_OWNED|STEP=',step_index,'|SAT=', &
           count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
           '|ORIGIN_ROUTE=',last_origin_route,'|ENDPOINT_ROUTE=',last_endpoint_route
    end if
    if(.not.domain_fail) return
"""
if corecall not in wseg:
    raise SystemExit("NLGLOB14R ordinary TG marker missing")
wseg=wseg.replace(corecall,corecall_repl,1)
src=src[:wrapper_start]+wseg+src[wrapper_end:]

# Record any later saturated-mode entry as re-entry.
entry="""        nl14d_saturated_mode=.true.
        write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=1', &
"""
entry_repl="""        nl14d_saturated_mode=.true.
        if(nl14r_released)then
          nl14r_reentries=nl14r_reentries+1
          write(*,'(*(g0))') 'F_PE_NLGLOB14R_REENTRY|STEP=',step_index,'|COUNT=',nl14r_reentries, &
               '|DELAY=',step_index-nl14r_handoff_step,'|NODE=',event_node
        end if
        write(*,'(*(g0))') 'F_PE_NLGLOB14D_MODE|STEP=',step_index,'|MODE=SATURATED_KLAG|ENTRY=1', &
"""
if entry not in src:
    raise SystemExit("NLGLOB14R mode-entry marker missing")
src=src.replace(entry,entry_repl,1)

for req in ("F_PE_NLGLOB14R_RETREAT","F_PE_NLGLOB14R_HANDOFF","F_PE_NLGLOB14R_REENTRY","F_PE_NLGLOB14R_TG_OWNED"):
    if req not in src:
        raise SystemExit(f"NLGLOB14R injection failed: {req}")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14R_MATERIALIZER=PASS")
