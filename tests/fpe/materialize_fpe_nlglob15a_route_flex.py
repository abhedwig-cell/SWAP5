#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

old_origin="""    if(r0/=target_route)then
      terminal_reason='ORIGIN_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
"""
idx=src.rfind(old_origin)
if idx<0:
    raise SystemExit("NLGLOB15A KLAG origin route marker missing")
new_origin="""    if((.not.nl14d_saturated_mode) .and. r0/=target_route)then
      terminal_reason='ORIGIN_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
"""
src=src[:idx]+src[idx:].replace(old_origin,new_origin,1)

old_endpoint="""    if(rp/=target_route)then
      terminal_reason='ENDPOINT_PROVIDER_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
"""
idx=src.rfind(old_endpoint)
if idx<0:
    raise SystemExit("NLGLOB15A KLAG endpoint route marker missing")
new_endpoint="""    if((.not.nl14d_saturated_mode) .and. rp/=target_route)then
      terminal_reason='ENDPOINT_PROVIDER_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
"""
src=src[:idx]+src[idx:].replace(old_endpoint,new_endpoint,1)

old_diag="""'|MASS_LEDGER=',nl15_interval_ledger,'|ROUTE=',trim(route_id), &
           '|FINITE=',merge(1,0,eligible),'|TERMINAL=',trim(terminal_reason)
"""
new_diag="""'|MASS_LEDGER=',nl15_interval_ledger,'|ORIGIN_ROUTE_CODE=',last_origin_route, &
           '|ENDPOINT_ROUTE_CODE=',last_endpoint_route,'|ROUTE_CHANGED=',merge(1,0,last_origin_route/=last_endpoint_route), &
           '|FINITE=',merge(1,0,eligible),'|TERMINAL=',trim(terminal_reason)
"""
if old_diag not in src:
    raise SystemExit("NLGLOB15A release diagnostic marker missing")
src=src.replace(old_diag,new_diag,1)

if "ROUTE_CHANGED" not in src:
    raise SystemExit("NLGLOB15A injection failed")

Path(args.output).write_text(src)
print("F_PE_NLGLOB15A_ROUTE_FLEX_MATERIALIZER=PASS")
