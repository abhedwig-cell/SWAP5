module MOD_SoilWater

   private
   public :: soilwater, soilwaterstatevar

   contains
! File VersionID:
!   $Id: soilwater.f90 369 2018-01-22 13:18:25Z heine003 $
! ----------------------------------------------------------------------
      subroutine soilwater(task) 
! ----------------------------------------------------------------------
!     Date               : Aug 2004   
!     Purpose            : calculate soil water state variables
! ----------------------------------------------------------------------
!     input
      use MOD_swap_base, only: swmacro, swinco, swhyst, swsolve
      use MOD_arrays,    only: mabbc
      use MOD_grid,      only: z, dz, numnod
      use MOD_macropore, only: macrostatevar, macropore
      use MOD_MvG,       only: watcon, moiscap, hconduc
      use MOD_frost,     only: rfcp
      use MOD_top,       only: boundtop
      use MOD_gwl,       only: calcgwl
      use MOD_swap_mp,   only: frarmtrx
      use variables,     only: swkmean
      use variables,     only: htb,nhead, swbotb, gwli, gwltab, t1900, dt
!     inout
      use variables,     only: h, pond, volact

!     out
      use variables,     only: gwl
      use variables,     only: theta, dimoca, k, kmean, ithetabeg
!     out (integral)
      use variables,     only: volini, pondini, ivolbeg, ipondbeg

      implicit none
!     global
      integer, intent(in)  :: task
! --- local variables
      integer              :: node, i, j, ipos
      
!     functions
      real(8)              :: afgen, hcomean

      select case (task)
      case (1)

! === initialize Soilwater rate/state variables ========================
!         if (.NOT. allocated(local_h))     allocate(local_h(18))
!         if (.NOT. allocated(local_theta)) allocate(local_theta(18))

! ---    additional Input checks
         if (swinco == 1) then
! ---       pressure head profile is input 
            h = 0.0d0; ipos = 0
            do i = 1, numnod
               call afgen_2(htb, nhead, dabs(z(i)), h(i), ipos)
            end do
            if (allocated(htb)) deallocate(htb)
            
! ---       determine groundwater level
            if (h(numnod) > -1.d-5) then
               i = numnod
               do while ((h(i) > -1.d-5) .AND. (i > 1))
                  i = i - 1
               end do
               if (h(i) < -1.d-5) then 
                  gwl = z(i+1) + h(i+1) / (h(i+1) - h(i)) * (z(i) - z(i+1))
! ---             assume hydrostatic equilibrium in saturated part
                  do j = i+1, numnod
                     h(j) = gwl - z(j)
                  end do
               end if
            end if
         end if
         if (swinco == 2) then
! ---    pressure head profile is calculated from groundwater level
            if (swbotb == 1) then  
               gwl = afgen (gwltab,mabbc*2,t1900+dt-1.d0)
               if (abs(gwl-(z(numnod)-0.5d0*dz(numnod))) < 1.0d-4) call swap_error ('soilwater', 'Initial groundwaterlevel (GWLI) as bottom boundary (SWBOTB=1) is below or to close to bottom of soil profile must be corrected!')
            else
               if (swbotb /= 8 ) then
                  if (abs(gwli-(z(numnod)-0.5d0*dz(numnod))) < 1.0d-4) call swap_error ('soilwater', 'Initial groundwaterlevel (SWINCO=2) is too close to bottom of soil profile must be corrected!')
               end if
               gwl = gwli
            end if
            if (gwl > 0.0d0) then 
               pond = gwl
            else
               pond = 0.0d0
            end if
            do i = 1,numnod
               h(i) = gwl - z(i)
            end do
         end if

         if (swsolve == 1) then
! ---       in case of preferential flow, adjust Van Genuchten parameters
            do i = 1, numnod
               theta(i) = watcon(i,h(i))
               ithetabeg(i) = theta(i)
            end do

! ---       hydr. conductivities, differential moisture capacities and mean hydraulic conductivities for each node
            do node = 1,numnod
               dimoca(node) = moiscap(node,h(node))
               k(node) = hconduc (node,h(node),theta(node),rfcp(node))
               if (swmacro == 1)  k(node)     = FrArMtrx(node) * k(node)
               if (node > 1)      kmean(node) = hcomean(swkmean, k(node-1), k(node), dz(node-1), dz(node), node, h(node-1), h(node))
            end do
            kmean(numnod+1) = k(numnod)

! ---       initial soil water storage
            if (swmacro == 0) then
               call watstor ()
               volini = volact
               ivolbeg = volact
            end if
            pondini = pond 
            ipondbeg = pond

! ---       initial groundwater level
            call calcgwl ()

            call boundtop(1)
         else
!!!            call watstor ()
            volini  = volact
            pondini = pond
         end if
            

      case (2)

! === calculate Soilwater rate/state variables ========================

! ---    save state variables of time = t
         call SoilWaterStateVar(1)
         if (swmacro == 1) call MacroStateVar(1)
     
! ---    calculate new soil water state variables
         if (swsolve == 1) then
            call audit_retry()
            call headcalc
         else
         end if

      case (3)

         if (swsolve == 1) then
! ---       update hydraulic conductivities to time level t+1
            do i = 1,numnod
               k(i) = hconduc(i,h(i),theta(i),rfcp(i))
               if (swmacro == 1)  k(i) = FrArMtrx(i) * k(i)
               if (i > 1) then
                  kmean(i) = hcomean(swkmean, k(i-1), k(i), dz(i-1), dz(i), i, h(i-1), h(i))
               end if
            end do
            kmean(numnod+1) = k(numnod)
         end if

!        calculate new groundwater level
         if (swsolve == 1) then
            call calcgwl ()
         else
         end if

! ---    calculate actual water content of profile
         call watstor ()

! ---    calculate water fluxes between soil compartments
         call fluxes ()

! ---    calculation of states macropores and intermediate & cumulative values
         if (swmacro == 1) call macropore(4)

! ---    update parameters for soil water hystereses
         if (swhyst /= 0) call hysteresis ()

      case default
         call swap_error ('soilwater', 'Illegal value for TASK')
      end select

      return
      end subroutine soilwater

      subroutine SoilWaterStateVar(task) 
! ----------------------------------------------------------------------
!     Date               : January 2007
!     Purpose            : save and reset soil water state variables
! ----------------------------------------------------------------------

! --- global variables
      use MOD_grid,  only: numnod
      use variables, only: hm1, h, thetm1, theta, gwlm1, gwl, pondm1, pond, kmean, k

      implicit none
      integer, intent(in) :: task
! --- local variables

      select case (task)
      case (1)
! ---    save state variables of time = t
         hm1(1:numnod)    = h(1:numnod)
         thetm1(1:numnod) = theta(1:numnod)
         gwlm1  = gwl
         pondm1 = pond

      case (2)
! --- reset soil state variables
         h(1:numnod)     = hm1(1:numnod)
         theta(1:numnod) = thetm1(1:numnod)
         kmean(numnod+1) = k(numnod)
         gwl  = gwlm1
         pond = pondm1

      case default
         call swap_error ('soilwaterstatevar', 'Illegal value for TASK')
      end select

      return
      end subroutine SoilWaterStateVar


subroutine audit_retry()
 use iso_c_binding, only:c_int
 use MOD_grid, only:numnod
 use MOD_swap_base, only:swdra,swfrost
 use MOD_drain, only:drain
 use MOD_macropore, only:macrostatevar,NumDm,WaUnMpDmCp,WaSrMpDm,WaUnMpDm,WaSrMp, &
  VlMpDmCp,ICpBtDm,FlEndSrpEvt,TimAbsCumDmCp,ThtSrpRefDmCp,SorpDmCp,FrMpWalWet,FrMpWalWetOld
 use MOD_swap_mp, only:QExcMpMtx,IDecMpRat,FlDecMpRat
 use variables, only:t1900,dt,h,theta,pond,gwl,k,kmean,fldecdt,fldtmin
 implicit none
 logical,save :: done=.false.
 integer :: kind,status
 character(32) :: mode
 interface
  integer(c_int) function retry_fork(knd) bind(C,name='audit_retry_fork')
   import c_int
   integer(c_int),value :: knd
  end function
  subroutine end_fork() bind(C,name='audit_fork_end')
  end subroutine
 end interface
 if(done.or.abs(t1900-35796.92d0)>1d-8.or.abs(dt-0.002d0)>1d-12) return
 done=.true.
 if(swdra/=1.or.swfrost/=0) error stop 'retry scope mismatch'
 call get_environment_variable('STATE02_MODE',mode)
 if(trim(mode)/='reject'.and.trim(mode)/='direct') return
 call dump('origin')
 if(trim(mode)=='reject') then
  call headcalc
  call dump('rejected')
  if(.not.fldecdt.or.FlDecMpRat) error stop 'expected ordinary rejection'
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
 else
  fldecdt=.true.
 end if
 call TimeControl(5)
 call dump('rollback')
 call drain(2)
 call SoilWaterStateVar(1)
 call MacroStateVar(1)
 call headcalc
 call dump('retry')
 if(fldecdt.or.FlDecMpRat) error stop 'retry not accepted'
 ! Execute the actual accepted hydraulic/macro transition, including the clock.
 call SoilWater(3)
 call dump('committed')
 stop 0

contains
 subroutine dump(label)
  character(*),intent(in)::label
  integer :: u
  open(newunit=u,file=label//'.txt',status='replace')
  write(u,*) 'controls',t1900,dt,IDecMpRat,merge(1,0,fldecdt),merge(1,0,fldtmin),merge(1,0,FlDecMpRat)
  write(u,*) 'h',h(1:numnod)
  write(u,*) 'theta',theta(1:numnod)
  write(u,*) 'surface_gwl',pond,gwl
  write(u,*) 'k',k(1:numnod)
  write(u,*) 'kmean',kmean(1:numnod+1)
  write(u,*) 'macro_total',WaSrMp
  write(u,*) 'sat_store',WaSrMpDm(1:NumDm)
  write(u,*) 'unsat_store',WaUnMpDm(1:NumDm)
  write(u,*) 'comp_store',WaUnMpDmCp(1:NumDm,1:numnod)
  write(u,*) 'volumes',VlMpDmCp(1:NumDm,1:numnod)
  write(u,*) 'bottom',ICpBtDm(1:NumDm)
  write(u,*) 'clock',TimAbsCumDmCp(1:NumDm,1:numnod)
  write(u,*) 'reference_theta',ThtSrpRefDmCp(1:NumDm,1:numnod)
  write(u,*) 'sorptivity',SorpDmCp(1:NumDm,1:numnod)
  write(u,*) 'event',merge(1,0,FlEndSrpEvt(1:NumDm,1:numnod))
  write(u,*) 'wet_wall',FrMpWalWet(1:NumDm,1:numnod)
  write(u,*) 'wet_wall_old',FrMpWalWetOld(1:NumDm,1:numnod)
  write(u,*) 'exchange',QExcMpMtx(1:numnod)
  close(u)
 end subroutine dump
end subroutine audit_retry

end module MOD_SoilWater
