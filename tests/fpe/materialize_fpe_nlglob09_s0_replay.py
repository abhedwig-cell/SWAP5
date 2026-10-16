#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

src=src.replace("   implicit none\n","   use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n   implicit none\n",1)

marker="   real(8)                          :: CritDevBalCp, CritDevBalTot\n"
insert=marker+"""   real(8), allocatable :: nl09_theta0(:), nl09_theta1(:)
   real(8) :: nl09_dinf1,nl09_dinf2,nl09_ds1,nl09_ds2,nl09_us1,nl09_us2
   real(8) :: nl09_rbal,nl09_rstorage,nl09_rhead,nl09_rpond,nl09_ulp
   integer :: nl09_hist,nl09_node
   logical :: nl09_guard,nl09_s0,nl09_finite,nl09_pond_app
   character(len=64) :: nl09_route0,nl09_route1
"""
if marker not in src: raise SystemExit("declaration marker missing")
src=src.replace(marker,insert,1)

marker="""   sump = 0.d0
   do solver_numbit = 1, MaxIt1
"""
insert="""   sump = 0.d0
   allocate(nl09_theta0(NN),nl09_theta1(NN))
   nl09_hist=0
   nl09_route0=''
   nl09_route1=''
   do solver_numbit = 1, MaxIt1
"""
if marker not in src: raise SystemExit("loop marker missing")
src=src.replace(marker,insert,1)

needle="""      if (.NOT.flnonconv) then      ! convergence has been reached
"""
repl="""      nl09_finite=.true.
      do i=1,NN
         nl09_finite=nl09_finite .and. ieee_is_finite(state%theta(i)) .and. ieee_is_finite(state%h(i))
      end do
      nl09_rbal=max(Fmax/max(CritDevBalCp,tiny(1.0d0)),dabs(sum1)/max(CritDevBalTot,tiny(1.0d0)))
      nl09_node=maxloc(dabs(fsi_ws%residual(1:NN)),dim=1)
      nl09_ulp=(dabs(spacing(state%theta(nl09_node)))+dabs(spacing(state%thetm1(nl09_node)))) * &
           dabs(matrix_fraction(nl09_node))*dabs(grid_dz(nl09_node))/dt
      nl09_rstorage=dabs(fsi_ws%residual(nl09_node))/max(nl09_ulp,tiny(1.0d0))
      nl09_rhead=0.0d0
      do i=1,NN
         if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
            nl09_rhead=max(nl09_rhead,dabs(state%h(i)-fsi_ws%old_head(i))/critdevh2cp)
         else
            nl09_rhead=max(nl09_rhead,(dabs(state%h(i)-fsi_ws%old_head(i))/dabs(fsi_ws%old_head(i)))/critdevh1cp)
         end if
      end do
      nl09_pond_app=provider_dynamic_top_active .and. index(trim(provider_dynamic_top_result%route),'surface-flux') == 0
      nl09_rpond=0.0d0
      if (nl09_pond_app) then
         nl09_rpond=dabs(state%pond-state%pondm1-provider_dynamic_top_result%net_potential_surface_flux*dt + &
              state%runots-state%qtop*dt)/critdevponddt
      end if
      nl09_guard=nl09_rbal<=10.0d0 .and. nl09_rstorage<=10.0d0 .and. nl09_rhead<=1.0d0 .and. &
           ((.not.nl09_pond_app) .or. nl09_rpond<=1.0d0) .and. nl09_finite
      nl09_s0=.false.
      if (nl09_hist >= 2) then
         nl09_dinf1=0.0d0; nl09_dinf2=0.0d0; nl09_ds1=0.0d0; nl09_ds2=0.0d0; nl09_us1=0.0d0; nl09_us2=0.0d0
         do i=1,NN
            nl09_ulp=dabs(spacing(nl09_theta0(i)))+dabs(spacing(nl09_theta1(i)))
            nl09_dinf1=max(nl09_dinf1,dabs(nl09_theta1(i)-nl09_theta0(i))/max(nl09_ulp,tiny(1.0d0)))
            nl09_ds1=nl09_ds1+dabs(matrix_fraction(i))*dabs(grid_dz(i))*dabs(nl09_theta1(i)-nl09_theta0(i))
            nl09_us1=nl09_us1+dabs(matrix_fraction(i))*dabs(grid_dz(i))*nl09_ulp
            nl09_ulp=dabs(spacing(nl09_theta1(i)))+dabs(spacing(state%theta(i)))
            nl09_dinf2=max(nl09_dinf2,dabs(state%theta(i)-nl09_theta1(i))/max(nl09_ulp,tiny(1.0d0)))
            nl09_ds2=nl09_ds2+dabs(matrix_fraction(i))*dabs(grid_dz(i))*dabs(state%theta(i)-nl09_theta1(i))
            nl09_us2=nl09_us2+dabs(matrix_fraction(i))*dabs(grid_dz(i))*nl09_ulp
         end do
         nl09_ds1=nl09_ds1/max(nl09_us1,tiny(1.0d0))
         nl09_ds2=nl09_ds2/max(nl09_us2,tiny(1.0d0))
         nl09_s0=nl09_guard .and. nl09_dinf1<=32.0d0 .and. nl09_ds1<=32.0d0 .and. &
              nl09_dinf2<=32.0d0 .and. nl09_ds2<=32.0d0 .and. nl09_ds2<=2.0d0*max(nl09_ds1,1.0d0) .and. &
              trim(nl09_route0)==trim(nl09_route1) .and. trim(nl09_route1)==trim(provider_dynamic_top_result%route)
      end if
      if (nl09_s0 .and. flnonconv) then
         flnonconv=.false.
         write(*,'(*(g0))') 'F_PE_NLGLOB09_ACCEPT|REASON=S0_STATE_STATIONARITY|ITER=',state%numbit, &
              '|ROUTE=',trim(provider_dynamic_top_result%route),'|RBAL=',nl09_rbal,'|RSTORAGE=',nl09_rstorage
      end if
      if (nl09_hist == 0) then
         nl09_theta1(1:NN)=state%theta(1:NN)
         nl09_route1=trim(provider_dynamic_top_result%route)
         nl09_hist=1
      else
         nl09_theta0(1:NN)=nl09_theta1(1:NN)
         nl09_route0=nl09_route1
         nl09_theta1(1:NN)=state%theta(1:NN)
         nl09_route1=trim(provider_dynamic_top_result%route)
         nl09_hist=min(2,nl09_hist+1)
      end if

      if (.NOT.flnonconv) then      ! convergence has been reached
"""
if needle not in src: raise SystemExit("convergence marker missing")
src=src.replace(needle,repl,1)

if "F_PE_NLGLOB09_ACCEPT" not in src: raise SystemExit("injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB09_MATERIALIZER=PASS")
