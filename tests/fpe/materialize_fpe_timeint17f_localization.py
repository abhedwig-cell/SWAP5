#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="   real(8)                          :: timeint17e_max_head_change\n"
insert=marker+"""   integer                          :: timeint17f_max_head_node
   real(8)                          :: timeint17f_head_metric, timeint17f_pond_dev
"""
if marker not in src: raise SystemExit("TIMEINT17F declaration marker missing")
src=src.replace(marker,insert,1)

# Add a localization record immediately after each E backtracking record.
marker="""                 '|TOP_H=',state%h(1),'|POND=',state%pond,'|ROUTE=',trim(provider_dynamic_top_result%route)
         end if

!        test for iteration progress"""
insert="""                 '|TOP_H=',state%h(1),'|POND=',state%pond,'|ROUTE=',trim(provider_dynamic_top_result%route)
            write(*,'(*(g0))') 'F_PE_TIMEINT17F_BT|ITER=',state%numbit,'|TRY=',itry,'|FACTOR=',factor, &
                 '|MAX_NODE=',maxloc(dabs(fsi_ws%residual(1:NN)),dim=1), &
                 '|MAX_RES=',maxval(dabs(fsi_ws%residual(1:NN))),'|TOP_RES=',fsi_ws%residual(1), &
                 '|BOTTOM_RES=',fsi_ws%residual(NN),'|SUM_RES=',sum1,'|SUMP=',sump, &
                 '|ROUTE=',trim(provider_dynamic_top_result%route)
         end if

!        test for iteration progress"""
if marker not in src: raise SystemExit("TIMEINT17F BT marker missing")
src=src.replace(marker,insert,1)

# Initialize pond diagnostic before the dynamic-top convergence check.
marker="""!     test for waterbalance of ponding layer
      if (provider_dynamic_top_active) then
"""
insert="""!     test for waterbalance of ponding layer
      timeint17f_pond_dev = 0.0d0
      if (provider_dynamic_top_active) then
"""
if marker not in src: raise SystemExit("TIMEINT17F pond marker missing")
src=src.replace(marker,insert,1)

# Capture the actual dynamic pond deviation.
marker="""            deviat = state%pond - state%pondm1 - provider_dynamic_top_result%net_potential_surface_flux*dt + &
                     state%runots - state%qtop * dt
            if (abs(deviat) > CritDevPondDt) then
"""
insert="""            deviat = state%pond - state%pondm1 - provider_dynamic_top_result%net_potential_surface_flux*dt + &
                     state%runots - state%qtop * dt
            timeint17f_pond_dev = deviat
            if (abs(deviat) > CritDevPondDt) then
"""
if marker not in src: raise SystemExit("TIMEINT17F dynamic pond deviation marker missing")
src=src.replace(marker,insert,1)

# Add max-head node calculation and gate-localization record before E gate write.
marker="""         timeint17e_pond_fail = flnonconv3
         timeint17e_total_fail = dabs(sum1) > CritDevBalTot
         write(*,'(*(g0))') 'F_PE_TIMEINT17E_GATE|ITER=',state%numbit, &
"""
insert="""         timeint17e_pond_fail = flnonconv3
         timeint17e_total_fail = dabs(sum1) > CritDevBalTot
         timeint17f_max_head_node = 1
         timeint17f_head_metric = -1.0d0
         do i = 1, NN
            if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
               if (abs(state%h(i)-fsi_ws%old_head(i)) > timeint17f_head_metric) then
                  timeint17f_head_metric=abs(state%h(i)-fsi_ws%old_head(i)); timeint17f_max_head_node=i
               end if
            else
               if (abs(state%h(i)-fsi_ws%old_head(i))/abs(fsi_ws%old_head(i)) > timeint17f_head_metric) then
                  timeint17f_head_metric=abs(state%h(i)-fsi_ws%old_head(i))/abs(fsi_ws%old_head(i)); timeint17f_max_head_node=i
               end if
            end if
         end do
         write(*,'(*(g0))') 'F_PE_TIMEINT17F_GATE|ITER=',state%numbit, &
              '|MAX_NODE=',maxloc(dabs(fsi_ws%residual(1:NN)),dim=1),'|MAX_RES=',maxval(dabs(fsi_ws%residual(1:NN))), &
              '|TOP_RES=',fsi_ws%residual(1),'|BOTTOM_RES=',fsi_ws%residual(NN),'|SUM_RES=',sum1, &
              '|MAX_HEAD_NODE=',timeint17f_max_head_node,'|MAX_HEAD_METRIC=',timeint17f_head_metric, &
              '|POND_DEV=',timeint17f_pond_dev,'|BAL_FAIL=',merge(1,0,timeint17e_balance_fail), &
              '|HEAD_FAIL=',merge(1,0,timeint17e_head_fail),'|POND_FAIL=',merge(1,0,timeint17e_pond_fail), &
              '|TOTAL_FAIL=',merge(1,0,timeint17e_total_fail),'|CONVERGED=',merge(1,0,.not.flnonconv), &
              '|ROUTE=',trim(provider_dynamic_top_result%route)
         write(*,'(*(g0))') 'F_PE_TIMEINT17E_GATE|ITER=',state%numbit, &
"""
if marker not in src: raise SystemExit("TIMEINT17F gate localization marker missing")
src=src.replace(marker,insert,1)

for req in ("F_PE_TIMEINT17F_BT","F_PE_TIMEINT17F_GATE"):
    if req not in src: raise SystemExit("missing "+req)
Path(args.output).write_text(src)
print("F_PE_TIMEINT17F_MATERIALIZER=PASS")
