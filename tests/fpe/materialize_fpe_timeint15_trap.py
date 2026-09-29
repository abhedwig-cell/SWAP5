#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

decl="   implicit none\n"
decl_new=decl+"""   integer :: timeint15_mode
   real(8) :: timeint15_origin_operator(1000)
   common /timeint15_trap_common/ timeint15_mode, timeint15_origin_operator
"""
if decl not in src:
    raise SystemExit("implicit none patch point missing")
src=src.replace(decl,decl_new,1)

old="""!  local
!  functions
   real(8)                    :: afgen
"""
new="""!  local
!  functions
   real(8)                    :: afgen
   real(8)                    :: timeint15_storage_term
"""
if old not in src:
    raise SystemExit("vector_F declaration patch point missing")
src=src.replace(old,new,1)

old="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F
"""
new="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

   ! TIMEINT15 test-only trapezoidal operator. The existing residual at this
   ! point is storage_rate + endpoint_operator. Replace the endpoint operator
   ! by the arithmetic mean of accepted-origin and endpoint physical operators.
   if (timeint15_mode == 1) then
      do i = 1, NN
         timeint15_storage_term = (state%theta(i)-state%thetm1(i)) * &
              matrix_fraction(i)*grid_dz(i)/dt
         fsi_ws%residual(i) = 0.5d0*fsi_ws%residual(i) + &
              0.5d0*timeint15_storage_term + 0.5d0*timeint15_origin_operator(i)
      end do
   end if

end subroutine vector_F
"""
if old not in src:
    raise SystemExit("vector_F tail patch point missing")
src=src.replace(old,new,1)

old="""   if (SwKimpl == 0) then
      do i = 2, numnod
         fsi_ws%dfdh_upper(i)   = - state%kmean(i)  /grid_disnod(i)
         fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
      end do
   end if
"""
new="""   if (SwKimpl == 0) then
      do i = 2, numnod
         if (timeint15_mode == 1) then
            fsi_ws%dfdh_upper(i) = -0.5d0*state%kmean(i)/grid_disnod(i)
         else
            fsi_ws%dfdh_upper(i) = -state%kmean(i)/grid_disnod(i)
         end if
         fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
      end do
   end if
"""
if old not in src:
    raise SystemExit("offdiagonal initialization patch point missing")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT15_TRAP_MATERIALIZER=PASS")
