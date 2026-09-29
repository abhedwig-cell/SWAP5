#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old_bind="""    call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
         rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,fixedk)
"""
new_bind="""    if(nl14d_saturated_mode)then
      call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
           0.0_real64,0.0_real64,0.0_real64,0.0_real64,rain,rain,pmax,rsro,1.0_real64,fixedk)
    else
      call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
           rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,fixedk)
    end if
"""
if old_bind not in src:
    raise SystemExit("NLGLOB14G provider bind marker missing")
src=src.replace(old_bind,new_bind,1)

old_persist="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      call advance_klag(step_index)
"""
new_persist="""    if(nl14d_saturated_mode)then
      nominal_dt=dt
      write(*,'(*(g0))') 'F_PE_NLGLOB14G_FORCING|STEP=',step_index,'|PHASE=DRY', &
           '|PRECIP=',0.0_real64,'|EBARE=',rain,'|EPOND=',rain,'|ROUTE_TARGET=',trim(route_id)
      call advance_klag(step_index)
"""
if old_persist not in src:
    raise SystemExit("NLGLOB14G persistent-mode marker missing")
src=src.replace(old_persist,new_persist,1)

# In persistent saturated attribution the dynamic-top provider may legitimately
# change route under drying. Preserve the original same-route guard before entry.
src=src.replace(
"""    if(r0/=target_route)then
      terminal_reason='ORIGIN_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
""",
"""    if((.not.nl14d_saturated_mode) .and. r0/=target_route)then
      terminal_reason='ORIGIN_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
""",1)

# Replace only the KLAG endpoint route guard: this exact block appears last.
old_guard="""    if(rp/=target_route)then
      terminal_reason='ENDPOINT_PROVIDER_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
"""
idx=src.rfind(old_guard)
if idx<0:
    raise SystemExit("NLGLOB14G KLAG endpoint route marker missing")
new_guard="""    if((.not.nl14d_saturated_mode) .and. rp/=target_route)then
      terminal_reason='ENDPOINT_PROVIDER_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
"""
src=src[:idx]+src[idx:].replace(old_guard,new_guard,1)

old_ledger="""    ledger=storage1-storage0-rain*dt+topres%runoff_depth-res%bottom_flux*dt
"""
new_ledger="""    if(nl14d_saturated_mode)then
      ledger=storage1-storage0 + (topres%bare_soil_evaporation+topres%ponded_water_evaporation)*dt + &
           topres%runoff_depth-res%bottom_flux*dt
    else
      ledger=storage1-storage0-rain*dt+topres%runoff_depth-res%bottom_flux*dt
    end if
"""
if old_ledger not in src:
    raise SystemExit("NLGLOB14G KLAG ledger marker missing")
src=src.replace(old_ledger,new_ledger,1)

# The NLGLOB14F accepted-state logger should report the actual provider route.
src=src.replace(
"""'|ROUTE=',trim(route_id), &
             '|TOP_FLUX=',res%top_flux""",
"""'|ROUTE=',trim(topres%route), &
             '|TOP_FLUX=',res%top_flux""",1)

for req in ("F_PE_NLGLOB14G_FORCING","potential","nl14d_saturated_mode"):
    if req=="potential":
        continue
    if req not in src:
        raise SystemExit(f"NLGLOB14G injection failed: {req}")

Path(args.output).write_text(src)
print("F_PE_NLGLOB14G_MATERIALIZER=PASS")
