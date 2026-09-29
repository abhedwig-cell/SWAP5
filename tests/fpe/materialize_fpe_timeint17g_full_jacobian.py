#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

# Invoke audit after the normal analytic Jacobian is assembled, before the real linear solve.
marker="""      call jacobian_F()

!     solve the tridiagonal matrix
"""
insert="""      call jacobian_F()
      if (provider_dynamic_top_active .and. SwKimpl == 0) call timeint17g_full_jacobian_audit()

!     solve the tridiagonal matrix
"""
if marker not in src: raise SystemExit("TIMEINT17G jacobian call marker missing")
src=src.replace(marker,insert,1)

# Add contained audit before existing first contained function.
marker="""contains

logical function pond_balance_option_allows()
"""
helper=r'''contains

subroutine timeint17g_full_jacobian_audit()
   type(reference_richards_state_binding_t) :: saved_state
   type(reference_richards_workspace_t) :: saved_ws
   type(soil_water_top_boundary_result_t) :: saved_top
   real(8), allocatable :: fplus(:), fminus(:), best_abs(:,:), best_rel(:,:)
   real(8), parameter :: epsg(4) = [1.0d-4,3.0d-5,1.0d-5,3.0d-6]
   real(8) :: fd, an, ae, re, max_abs_mis, max_rel_mis
   integer :: col, row, ie, eligible, fails, worst_row, worst_col
   logical :: saved_tuple_valid, saved_tuple_from_candidate
   character(len=64) :: base_route, plus_route, minus_route

   saved_state = state
   saved_ws = fsi_ws
   saved_top = provider_dynamic_top_result
   saved_tuple_valid = provider_tuple_valid
   saved_tuple_from_candidate = provider_tuple_from_candidate
   base_route = trim(provider_dynamic_top_result%route)

   allocate(fplus(NN),fminus(NN),best_abs(NN,NN),best_rel(NN,NN))
   best_abs = huge(1.0d0)
   best_rel = huge(1.0d0)

   do ie = 1,4
      do col = 1,NN
         state = saved_state
         fsi_ws = saved_ws
         provider_dynamic_top_result = saved_top
         provider_tuple_valid = saved_tuple_valid
         provider_tuple_from_candidate = saved_tuple_from_candidate
         state%h(col) = saved_state%h(col) + epsg(ie)
         call timeint17g_refresh_theta_gradient()
         call vector_F(2)
         plus_route = trim(provider_dynamic_top_result%route)
         fplus(1:NN) = fsi_ws%residual(1:NN)

         state = saved_state
         fsi_ws = saved_ws
         provider_dynamic_top_result = saved_top
         provider_tuple_valid = saved_tuple_valid
         provider_tuple_from_candidate = saved_tuple_from_candidate
         state%h(col) = saved_state%h(col) - epsg(ie)
         call timeint17g_refresh_theta_gradient()
         call vector_F(2)
         minus_route = trim(provider_dynamic_top_result%route)
         fminus(1:NN) = fsi_ws%residual(1:NN)

         if (trim(plus_route) /= trim(base_route) .or. trim(minus_route) /= trim(base_route)) cycle

         do row = max(1,col-1),min(NN,col+1)
            if (abs(row-col) > 1) cycle
            fd = (fplus(row)-fminus(row))/(2.0d0*epsg(ie))
            if (row == col) then
               an = saved_ws%dfdh_main(row)
            else if (row == col+1) then
               an = saved_ws%dfdh_upper(row)
            else
               an = saved_ws%dfdh_lower(row)
            end if
            ae = abs(an-fd)
            re = ae/max(1.0d-30,abs(fd))
            best_abs(row,col)=min(best_abs(row,col),ae)
            best_rel(row,col)=min(best_rel(row,col),re)
         end do
      end do
   end do

   eligible=0; fails=0; max_abs_mis=0.0d0; max_rel_mis=0.0d0; worst_row=0; worst_col=0
   do col=1,NN
      do row=max(1,col-1),min(NN,col+1)
         if (best_abs(row,col) >= 0.5d0*huge(1.0d0)) cycle
         eligible=eligible+1
         if (best_abs(row,col) > 1.0d-7 .and. best_rel(row,col) > 1.0d-5) fails=fails+1
         if (best_rel(row,col) > max_rel_mis) then
            max_rel_mis=best_rel(row,col); max_abs_mis=best_abs(row,col)
            worst_row=row; worst_col=col
         end if
      end do
   end do

   write(*,'(*(g0))') 'F_PE_TIMEINT17G_ITER|ITER=',state%numbit,'|ROUTE=',trim(base_route), &
        '|ELIGIBLE=',eligible,'|FAILS=',fails,'|MAX_ABS=',max_abs_mis,'|MAX_REL=',max_rel_mis, &
        '|WORST_ROW=',worst_row,'|WORST_COL=',worst_col

   state = saved_state
   fsi_ws = saved_ws
   provider_dynamic_top_result = saved_top
   provider_tuple_valid = saved_tuple_valid
   provider_tuple_from_candidate = saved_tuple_from_candidate
end subroutine timeint17g_full_jacobian_audit

subroutine timeint17g_refresh_theta_gradient()
   if (provider_constitutive_active) then
      call evaluation_context%constitutive%evaluate_demand(state%h(1:numnod), &
           CONSTITUTIVE_DEMAND_WATER_CONTENT, fsi_ws%provider_theta, fsi_ws%provider_k, &
           fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
      state%theta(1:NN)=fsi_ws%provider_theta(1:NN)
   else
      do i=1,NN
         state%theta(i)=watcon(i,state%h(i))
      end do
   end if
   do i=2,NN
      fsi_ws%head_gradient(i)=(state%h(i-1)-state%h(i))/grid_disnod(i)+1.0d0
   end do
end subroutine timeint17g_refresh_theta_gradient

logical function pond_balance_option_allows()
'''
if marker not in src: raise SystemExit("TIMEINT17G contains marker missing")
src=src.replace(marker,helper,1)

if "F_PE_TIMEINT17G_ITER" not in src: raise SystemExit("TIMEINT17G injection failed")
Path(args.output).write_text(src)
print("F_PE_TIMEINT17G_MATERIALIZER=PASS")
