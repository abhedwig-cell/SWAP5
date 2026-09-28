#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

decl="""   integer :: timeint02_mode
   real(8) :: timeint02_thetam2(1000)
   common /timeint02_history_common/ timeint02_mode, timeint02_thetam2
"""
decl_new=decl+"""   integer :: timeint04_step
   common /timeint04_trace_common/ timeint04_step
"""
if decl not in src:
    raise SystemExit("TIMEINT02 common block not found")
src=src.replace(decl,decl_new,1)

initial="""   sumold = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))

!  start iteration loop, MaxIt specified in the input
"""
initial_new="""   sumold = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))
   if (timeint04_step == 24 .or. timeint04_step == 25) then
      write(*,'(*(g0))') 'F_PE_TIMEINT04_INIT|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
           '|SUMQ=',sumold,'|FINF=',maxval(abs(fsi_ws%residual(1:NN))), &
           '|HMIN=',minval(state%h(1:NN)),'|HMAX=',maxval(state%h(1:NN)), &
           '|KMIN=',minval(state%k(1:NN)),'|KMAX=',maxval(state%k(1:NN))
   end if

!  start iteration loop, MaxIt specified in the input
"""
if initial not in src:
    raise SystemExit("initial trace patch point missing")
src=src.replace(initial,initial_new,1)

pre="""!     incorporate Jacobian information in coefficient matrix elements
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
"""
pre_new="""      if (timeint04_step == 24 .or. timeint04_step == 25) then
         write(*,'(*(g0))') 'F_PE_TIMEINT04_PRE|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
              '|ITER=',solver_numbit,'|SUMOLD=',sumold, &
              '|FINF=',maxval(abs(fsi_ws%residual(1:NN))), &
              '|HMIN=',minval(state%h(1:NN)),'|HMAX=',maxval(state%h(1:NN)), &
              '|CMIN=',minval(state%dimoca(1:NN)),'|CMAX=',maxval(state%dimoca(1:NN)), &
              '|KMIN=',minval(state%k(1:NN)),'|KMAX=',maxval(state%k(1:NN))
      end if

!     incorporate Jacobian information in coefficient matrix elements
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
"""
if pre not in src:
    raise SystemExit("pre-Jacobian patch point missing")
src=src.replace(pre,pre_new,1)

delta="""!     in the rare case that TRIDAG fails, use alternative solution
      if (ierror /= 0) then
"""
delta_new="""      if (timeint04_step == 24 .or. timeint04_step == 25) then
         write(*,'(*(g0))') 'F_PE_TIMEINT04_DELTA|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
              '|ITER=',solver_numbit,'|DMAX=',maxval(abs(fsi_ws%delta_head(1:NN))), &
              '|D1=',fsi_ws%delta_head(1),'|DN=',fsi_ws%delta_head(NN),'|TRIDAG_STATUS=',ierror
      end if

!     in the rare case that TRIDAG fails, use alternative solution
      if (ierror /= 0) then
"""
if delta not in src:
    raise SystemExit("delta patch point missing")
src=src.replace(delta,delta_new,1)

trial="""!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0
"""
trial_new="""         if (timeint04_step == 24 .or. timeint04_step == 25) then
            write(*,'(*(g0))') 'F_PE_TIMEINT04_TRIAL|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
                 '|ITER=',solver_numbit,'|ITRY=',itry,'|FACTOR=',factor,'|SUMNEW=',sump, &
                 '|FINF=',Fmax,'|DHACT=',maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))), &
                 '|PROGRESS=',merge(1,0,sump < sumold .or. Fmax < CritDevBalCp)
         end if

!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0
"""
if trial not in src:
    raise SystemExit("trial patch point missing")
src=src.replace(trial,trial_new,1)

check="""!     save sump voor next iteration
      sumold = sump

      if (.NOT.flnonconv) then      ! convergence has been reached
"""
check_new="""      if (timeint04_step == 24 .or. timeint04_step == 25) then
         write(*,'(*(g0))') 'F_PE_TIMEINT04_CHECK|STEP=',timeint04_step,'|TMODE=',timeint02_mode, &
              '|ITER=',solver_numbit,'|SUMNEW=',sump,'|FINF=',Fmax,'|SUMRES=',sum1, &
              '|DHACT=',maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))), &
              '|NONCONV=',merge(1,0,flnonconv)
      end if

!     save sump voor next iteration
      sumold = sump

      if (.NOT.flnonconv) then      ! convergence has been reached
"""
if check not in src:
    raise SystemExit("check patch point missing")
src=src.replace(check,check_new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT04_TRACE_MATERIALIZER=PASS")
