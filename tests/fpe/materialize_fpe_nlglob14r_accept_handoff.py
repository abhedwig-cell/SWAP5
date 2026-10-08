#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

gdecl="  logical :: nl14q_shadow_done,nl14q_shadow_dry,nl14q_shadow_retry\n"
if gdecl not in src: raise SystemExit("NLGLOB14R global marker missing")
src=src.replace(gdecl,gdecl+"  logical :: nl14r_pending_handoff,nl14r_dry_release,nl14r_handoff_active\n  integer :: nl14r_handoff_step\n",1)

init="  nl14q_shadow_retry=.false.\n"
if init not in src: raise SystemExit("NLGLOB14R init marker missing")
src=src.replace(init,init+"  nl14r_pending_handoff=.false.\n  nl14r_dry_release=.false.\n  nl14r_handoff_active=.false.\n  nl14r_handoff_step=0\n",1)

src=src.replace("if(nl14q_shadow_dry)then","if(nl14q_shadow_dry .or. nl14r_dry_release)then",1)

bind_old="""    if(nl14d_saturated_mode)then
      call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
           0.0_real64,0.0_real64,0.0_real64,0.0_real64,rain,rain,pmax,rsro,1.0_real64,fixedk)
"""
bind_new="""    if(nl14d_saturated_mode .or. nl14r_dry_release)then
      call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
           0.0_real64,0.0_real64,0.0_real64,0.0_real64,rain,rain,pmax,rsro,1.0_real64,fixedk)
"""
if bind_old not in src: raise SystemExit("NLGLOB14R dry bind marker missing")
src=src.replace(bind_old,bind_new,1)

ledger_old="    ledger=storage1-storage0-rain*stepdt+runint-res%bottom_flux*stepdt\n"
ledger_new="""    if(nl14r_dry_release)then
      runint=0.0_real64
      ledger=storage1-storage0+rain*stepdt-res%bottom_flux*stepdt
    else
      ledger=storage1-storage0-rain*stepdt+runint-res%bottom_flux*stepdt
    end if
"""
if ledger_old not in src: raise SystemExit("NLGLOB14R TG ledger marker missing")
src=src.replace(ledger_old,ledger_new,1)

decl_marker="    logical::nl14q_saved_eligible\n"
if decl_marker not in src: raise SystemExit("NLGLOB14R local declaration marker missing")
src=src.replace(decl_marker,decl_marker+"    logical::nl14r_shadow_admissible\n",1)

shadow_ledger_marker="""        if(eligible .and. .not.nl14q_shadow_domain .and. nl14q_shadow_route==R_FLUX)then
          nl14q_shadow_ledger=nl14q_storage1-nl14q_storage0+rain*dt
        else
          nl14q_shadow_ledger=huge(1.0_real64)
        end if
"""
shadow_ledger_repl=shadow_ledger_marker+"""        nl14r_shadow_admissible=eligible .and. .not.nl14q_shadow_domain .and. nl14q_shadow_finite .and. &
             nl14q_shadow_route==R_FLUX .and. last_pred_route==R_FLUX .and. &
             last_endpoint_route==R_FLUX .and. last_accept_route==R_FLUX .and. &
             abs(nl14q_shadow_ledger)<=5.0e-8_real64
"""
if shadow_ledger_marker not in src: raise SystemExit("NLGLOB14R shadow admissibility marker missing")
src=src.replace(shadow_ledger_marker,shadow_ledger_repl,1)

done_marker="        nl14q_shadow_done=.true.\n"
if done_marker not in src: raise SystemExit("NLGLOB14R shadow done marker missing")
src=src.replace(done_marker,"""        nl14q_shadow_done=.true.
        if(nl14r_shadow_admissible) nl14r_pending_handoff=.true.
""",1)

main_old="""    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
main_new="""    if(nl14r_pending_handoff)then
      nl14d_saturated_mode=.false.
      nl14r_dry_release=.true.
      nl14r_handoff_active=.true.
      nl14r_handoff_step=step
      target_route=R_FLUX
      nl14r_pending_handoff=.false.
      write(*,'(*(g0))') 'F_PE_NLGLOB14R_START|STEP=',step,'|MODE=TG|ROUTE=1'
    end if
    if(trim(mode)=='TG')then
      call advance_tg_subdiv(step)
    else
"""
if main_old not in src: raise SystemExit("NLGLOB14R main dispatch marker missing")
src=src.replace(main_old,main_new,1)

exit_marker="    if(.not.eligible) exit\n"
follow_code="""    if(nl14r_handoff_active .and. step==nl14r_handoff_step)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14R_HANDOFF|STEP=',step,'|ELIGIBLE=',merge(1,0,eligible), &
           '|SAT_MODE=',merge(1,0,nl14d_saturated_mode),'|SAT_COUNT=', &
           count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
           '|TERMINAL=',trim(terminal_reason),'|MAX_LEDGER=',maxledger,'|CUM_LEDGER=',cumledger
    else if(nl14r_handoff_active .and. step==nl14r_handoff_step+1)then
      write(*,'(*(g0))') 'F_PE_NLGLOB14R_FOLLOW|STEP=',step,'|ELIGIBLE=',merge(1,0,eligible), &
           '|SAT_MODE=',merge(1,0,nl14d_saturated_mode),'|SAT_COUNT=', &
           count(state%pressure_head>=0.0_real64 .and. state%water_content==ts), &
           '|TERMINAL=',trim(terminal_reason),'|MAX_LEDGER=',maxledger,'|CUM_LEDGER=',cumledger
      if(eligible)then
        terminal_reason='NLGLOB14R_WINDOW_COMPLETE'
        eligible=.false.
        transition_step=step
      end if
    end if
    if(.not.eligible) exit
"""
if exit_marker not in src: raise SystemExit("NLGLOB14R main exit marker missing")
src=src.replace(exit_marker,follow_code,1)

if "F_PE_NLGLOB14R_HANDOFF" not in src or "F_PE_NLGLOB14R_FOLLOW" not in src:
    raise SystemExit("NLGLOB14R injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB14R_MATERIALIZER=PASS")
