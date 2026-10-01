#!/usr/bin/env python3
from pathlib import Path
import argparse,re

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

src,n=re.subn(r"integer, parameter :: nstep=4000, tail_start=13",
              "integer, parameter :: nstep=40000, tail_start=13",src,count=1)
if n!=1:
    raise SystemExit(f"MIQUAL12 expected one nstep marker, found {n}")

anchor="  use mod_moving_interface_manager, only: MI_MANAGER_ROUTE_REDUCED, MI_MANAGER_ROUTE_FULL_FALLBACK, &\n       MI_MANAGER_ROUTE_FULL_BYPASS\n"
insert=anchor+"  use mod_fmr_moving_interface_runtime_adapter, only: fmr_moving_interface_runtime_profile_t\n"
if anchor not in src:
    raise SystemExit("MIQUAL12 manager import anchor missing")
src=src.replace(anchor,insert,1)

decl="  type(fmr_serialized_physical_observation_t)::obs\n"
if decl not in src:
    raise SystemExit("MIQUAL12 declaration anchor missing")
src=src.replace(decl,decl+"  type(fmr_moving_interface_runtime_profile_t)::mi_profile\n",1)

marker="  write(*,'(*(g0))') 'F_PE_MIQUAL07_RESULT|VARIANT=',trim(variant),'|WORKLOAD=',trim(workload), &"
idx=src.find(marker)
if idx<0:
    raise SystemExit("MIQUAL12 result marker missing")
profile_text="""  mi_profile=backend%moving_interface_runtime_profile()
  write(*,'(*(g0))') 'F_PE_MIQUAL12_PROFILE|CALLS=',mi_profile%solve_calls, &
       '|ELIGIBILITY_TAIL=',mi_profile%eligibility_tail_cpu, &
       '|REDUCED_REQUEST=',mi_profile%reduced_request_cpu, &
       '|PROVIDER_PREPARE=',mi_profile%provider_prepare_cpu, &
       '|REDUCED_SOLVE=',mi_profile%reduced_solve_cpu, &
       '|RECONSTRUCT_MATERIALIZE=',mi_profile%reconstruct_materialize_cpu, &
       '|FINALIZE_PUBLISH=',mi_profile%finalize_publish_cpu, &
       '|ATTRIBUTED_TOTAL=',mi_profile%eligibility_tail_cpu+mi_profile%reduced_request_cpu+ &
            mi_profile%provider_prepare_cpu+mi_profile%reduced_solve_cpu+ &
            mi_profile%reconstruct_materialize_cpu+mi_profile%finalize_publish_cpu, &
       '|NON_SOLVER=',mi_profile%eligibility_tail_cpu+mi_profile%reduced_request_cpu+ &
            mi_profile%provider_prepare_cpu+mi_profile%reconstruct_materialize_cpu+ &
            mi_profile%finalize_publish_cpu
"""
src=src[:idx]+profile_text+src[idx:]

Path(args.output).write_text(src)
print("F_PE_MIQUAL12_MATERIALIZER=PASS")
