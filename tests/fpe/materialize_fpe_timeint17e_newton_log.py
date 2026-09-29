#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

# Test-only diagnostic locals.
marker="   logical                          :: flboth, flok\n"
insert=marker+"""   logical                          :: timeint17e_balance_fail, timeint17e_head_fail
   logical                          :: timeint17e_total_fail, timeint17e_pond_fail
   real(8)                          :: timeint17e_max_head_change
"""
if marker not in src: raise SystemExit("TIMEINT17E declaration marker missing")
src=src.replace(marker,insert,1)

# Iteration-start residual authority.
marker="   sumold = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))\n"
insert=marker+"""   if (provider_dynamic_top_active) then
      write(*,'(*(g0))') 'F_PE_TIMEINT17E_INIT|SUMOLD=',sumold,'|FMAX=',maxval(dabs(fsi_ws%residual(1:NN))), &
           '|TOP_H=',state%h(1),'|POND=',state%pond,'|ROUTE=',trim(provider_dynamic_top_result%route)
   end if
"""
if marker not in src: raise SystemExit("TIMEINT17E initial residual marker missing")
src=src.replace(marker,insert,1)

# Newton correction geometry, after possible alternative solve and before backtracking.
marker="!     back tracking cycle\n      factor = 1.0d0\n"
insert="""      if (provider_dynamic_top_active) then
         write(*,'(*(g0))') 'F_PE_TIMEINT17E_NEWTON|ITER=',state%numbit,'|SUMOLD=',sumold, &
              '|FMAX_OLD=',maxval(dabs(fsi_ws%residual(1:NN))),'|MAX_DH=',maxval(dabs(fsi_ws%delta_head(1:NN))), &
              '|L2_DH=',sqrt(dot_product(fsi_ws%delta_head(1:NN),fsi_ws%delta_head(1:NN))), &
              '|TOP_H=',state%h(1),'|POND=',state%pond,'|ROUTE=',trim(provider_dynamic_top_result%route)
      end if

!     back tracking cycle
      factor = 1.0d0
"""
if marker not in src: raise SystemExit("TIMEINT17E backtrack marker missing")
src=src.replace(marker,insert,1)

# Candidate observation before the existing accept/reduce decision.
marker="""!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0
"""
insert="""!        test-only TIMEINT17E observation; no solver decision is changed
         if (provider_dynamic_top_active) then
            write(*,'(*(g0))') 'F_PE_TIMEINT17E_BT|ITER=',state%numbit,'|TRY=',itry,'|FACTOR=',factor, &
                 '|SUMP=',sump,'|SUMOLD=',sumold,'|RATIO=',sump/max(sumold,tiny(1.0d0)),'|FMAX=',Fmax, &
                 '|EXIT=',merge(1,0,(sump < sumold .OR. Fmax < CritDevBalCp)), &
                 '|TOP_H=',state%h(1),'|POND=',state%pond,'|ROUTE=',trim(provider_dynamic_top_result%route)
         end if

!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0
"""
if marker not in src: raise SystemExit("TIMEINT17E progress marker missing")
src=src.replace(marker,insert,1)

# Recompute exact gate categories without changing flnonconv.
marker="      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.\n\n!     save sump voor next iteration\n"
insert="""      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.

      if (provider_dynamic_top_active) then
         timeint17e_balance_fail = any(dabs(fsi_ws%residual(1:NN)) > CritDevBalCp)
         timeint17e_head_fail = .false.
         timeint17e_max_head_change = 0.0d0
         do i = 1, NN
            if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
               timeint17e_max_head_change = max(timeint17e_max_head_change,abs(state%h(i)-fsi_ws%old_head(i)))
               if (abs(state%h(i)-fsi_ws%old_head(i)) > CritDevh2Cp) timeint17e_head_fail=.true.
            else
               timeint17e_max_head_change = max(timeint17e_max_head_change, &
                    abs(state%h(i)-fsi_ws%old_head(i))/abs(fsi_ws%old_head(i)))
               if (abs(state%h(i)-fsi_ws%old_head(i))/abs(fsi_ws%old_head(i)) > CritDevh1Cp) timeint17e_head_fail=.true.
            end if
         end do
         timeint17e_pond_fail = flnonconv3
         timeint17e_total_fail = dabs(sum1) > CritDevBalTot
         write(*,'(*(g0))') 'F_PE_TIMEINT17E_GATE|ITER=',state%numbit, &
              '|BAL_FAIL=',merge(1,0,timeint17e_balance_fail),'|HEAD_FAIL=',merge(1,0,timeint17e_head_fail), &
              '|POND_FAIL=',merge(1,0,timeint17e_pond_fail),'|TOTAL_FAIL=',merge(1,0,timeint17e_total_fail), &
              '|SUMABS=',dabs(sum1),'|MAX_HEAD_CHANGE=',timeint17e_max_head_change, &
              '|CONVERGED=',merge(1,0,.not.flnonconv),'|SUMP=',sump,'|FMAX=',Fmax, &
              '|TOP_H=',state%h(1),'|POND=',state%pond,'|ROUTE=',trim(provider_dynamic_top_result%route)
      end if

!     save sump voor next iteration
"""
if marker not in src: raise SystemExit("TIMEINT17E gate marker missing")
src=src.replace(marker,insert,1)

for req in ("F_PE_TIMEINT17E_INIT","F_PE_TIMEINT17E_NEWTON","F_PE_TIMEINT17E_BT","F_PE_TIMEINT17E_GATE"):
    if req not in src: raise SystemExit("missing "+req)
Path(args.output).write_text(src)
print("F_PE_TIMEINT17E_MATERIALIZER=PASS")
