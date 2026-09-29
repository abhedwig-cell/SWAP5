#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

decl="""   real(8), parameter               :: Critdz = 1.0d-5
"""
decl_new=decl+"""
! F-PE-TIMEINT15 test-only trapezoidal temporal integration.
! mode=0 preserves production HeadCalc exactly; mode=1 activates the
! one-step physical-storage / trapezoidal non-storage residual.
   integer :: timeint15_mode
   integer :: timeint15_origin_ready
   real(8) :: timeint15_origin_flux(1000)
   common /timeint15_trapezoid_common/ timeint15_mode, timeint15_origin_ready, timeint15_origin_flux
"""
if decl not in src:
    raise SystemExit("TIMEINT15 declaration insertion point missing")
src=src.replace(decl,decl_new,1)

old="""!  calculate vector fsi_ws%residual (first time)
   call vector_F(1)
"""
new="""!  calculate vector fsi_ws%residual (first time)
   if (timeint15_mode == 1) then
      timeint15_origin_ready = 0
      timeint15_origin_flux = 0.0d0
   end if
   call vector_F(1)
"""
if old not in src:
    raise SystemExit("TIMEINT15 initial residual point missing")
src=src.replace(old,new,1)

old="""!     incorporate Jacobian information in coefficient matrix elements
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
      call jacobian_F()
"""
new="""!     incorporate Jacobian information in coefficient matrix elements
      ! SWKIMPL=0 stores the off-diagonal operator outside the Newton loop.
      ! Restore its unscaled endpoint form before every trapezoidal Jacobian build
      ! so the 0.5 transform below is applied exactly once per iteration.
      if (timeint15_mode == 1 .and. SwKimpl == 0) then
         do i = 2, NN
            fsi_ws%dfdh_upper(i)   = - state%kmean(i) / grid_disnod(i)
            fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
         end do
      end if
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
      call jacobian_F()
      if (timeint15_mode == 1) then
         do i = 1, NN
            ! Full storage derivative plus half of the endpoint flux derivative.
            fsi_ws%dfdh_main(i) = state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt + &
                 0.5d0*(fsi_ws%dfdh_main(i)-state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt)
            fsi_ws%dfdh_upper(i) = 0.5d0*fsi_ws%dfdh_upper(i)
            fsi_ws%dfdh_lower(i) = 0.5d0*fsi_ws%dfdh_lower(i)
         end do
      end if
"""
if old not in src:
    raise SystemExit("TIMEINT15 Jacobian call point missing")
src=src.replace(old,new,1)

old="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F
"""
new="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

   if (timeint15_mode == 1) then
      ! At the accepted origin the physical storage increment is zero, so the
      ! first residual exposes the complete non-storage operator G_n.
      if (timeint15_origin_ready == 0) then
         do i = 1, NN
            timeint15_origin_flux(i) = fsi_ws%residual(i) - &
                 (state%theta(i)-state%thetm1(i))*matrix_fraction(i)*grid_dz(i)/dt
         end do
         timeint15_origin_ready = 1
      else
         do i = 1, NN
            ! Physical storage increment + trapezoidal non-storage operator.
            fsi_ws%residual(i) = (state%theta(i)-state%thetm1(i))*matrix_fraction(i)*grid_dz(i)/dt + &
                 0.5d0*(timeint15_origin_flux(i) + fsi_ws%residual(i) - &
                 (state%theta(i)-state%thetm1(i))*matrix_fraction(i)*grid_dz(i)/dt)
         end do
      end if
   end if

end subroutine vector_F
"""
if old not in src:
    raise SystemExit("TIMEINT15 vector_F exit point missing")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT15_TRAPEZOID_MATERIALIZER=PASS")
