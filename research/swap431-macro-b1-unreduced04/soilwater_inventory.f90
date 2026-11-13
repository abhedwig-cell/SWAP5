module MOD_SoilWater

   private
   public :: soilwater, soilwaterstatevar

   contains
! File VersionID:
!   $Id: soilwater.f90 369 2018-01-22 13:18:25Z heine003 $
! ----------------------------------------------------------------------
      recursive subroutine soilwater(task) 
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
            call unreduced_driver()
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


subroutine unreduced_driver()
 use variables, only:t1900,dt,dtmin,fldecdt,fldtmin
 use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
 use MOD_swap_base, only:swdra,swfrost
 use MOD_macropore, only:MacroStateVar
 use MOD_drain, only:drain
 implicit none
 integer :: attempt,u,ios,status
 character(64) :: direct,name
 real(8) :: target
 if(IDecMpRat/=1.or.abs(t1900-35796.9513533331d0)>1d-9) return
 if(abs(dt-0.0001414213562373095d0)>1d-14) return
 if(swdra/=1.or.swfrost/=0) error stop 'unreduced scope mismatch'
 call inventory_dump('origin')
 open(newunit=u,file='active.marker',status='replace')
 write(u,*) 'Selected same-origin unscaled experiment, never a reference run.'
 close(u)
 ! Explicit experimental choice at this ONE live origin. The original
 ! MACRORATE reduction law and all HEADCALC equations/criteria stay intact.
 IDecMpRat=0
 ! Preserve the origin's existing retry flag: original HEADCALC uses it
 ! to select its doubled iteration budget. Do not shorten that budget.
 call get_environment_variable('UNRED04_DIRECT_DT',direct,status=status)
 if(status==0.and.len_trim(direct)>0) then
  read(direct,*,iostat=ios) target
  if(ios/=0.or.target<dtmin.or.target>dt) error stop 'invalid direct dt'
  do while(dt>target+1d-14)
   fldecdt=.true.
   call TimeControl(5)
  end do
  if(abs(dt-target)>1d-14) error stop 'direct dt not original retry size'
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end if
 do attempt=1,4
  write(name,'(a,i0)') 'begin_',attempt
  call inventory_dump(trim(name))
  call headcalc
  write(name,'(a,i0)') 'returned_',attempt
  call inventory_dump(trim(name))
  if(.not.fldecdt.and..not.FlDecMpRat.and.IDecMpRat==0) then
   call inventory_dump('trial')
   call SoilWater(3)
   call inventory_dump('committed')
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'ACCEPTED_UNREDUCED',attempt,dt
   close(u)
   stop 0
  end if
  ! Perform actual original rollback before classifying a failed attempt.
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
  write(name,'(a,i0)') 'rollback_',attempt
  call inventory_dump(trim(name))
  if(IDecMpRat/=0) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'ORIGINAL_REDUCTION_REQUIRED',attempt,dt
   close(u)
   stop 0
  end if
  if(.not.fldecdt) error stop 'unclassified original outcome'
  if(attempt==4) exit
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
 open(newunit=u,file='outcome.txt',status='replace')
 write(u,*) 'FOUR_ATTEMPT_BOUND',attempt,dt
 close(u)
 stop 0
end subroutine unreduced_driver

subroutine inventory_dump(label)
 use MOD_grid, only:numnod,dz
 use MOD_swap_base, only:swmacro
 use MOD_macropore, only:NumDm,WaSrMp,WaSrMpDm,WaUnMpDm,WaUnMpDmCp, &
 VlMpDmCp,ICpBtDm,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,QOutDrRapCp, &
 TimAbsCumDmCp,FlEndSrpEvt,ThtSrpRefDmCp,SorpDmCp,swmbf,FrReduQ
 use MOD_swap_mp, only:FrArMtrx,QExcMpMtx,IDecMpRat,ArMpSs,QMpLatSs,FlDecMpRat
 use MOD_drain, only:qdra,nrlevs
 use MOD_irrigation, only:qssdi,nird
 use MOD_meteo, only:nraidt
 use MOD_snow, only:melt
 use variables, only:t1900,dt,theta,thetm1,pond,pondm1,qtop,qbot,qrot,qimmob, &
 q,volact,volm1,runon,epd,reva,runots,fldecdt,swkimpl,fldtmin
 implicit none
 character(*),intent(in) :: label
 integer :: u
 open(newunit=u,file=label//'.txt',status='replace')
 write(u,*) 'controls',t1900,dt,IDecMpRat,numnod,NumDm,swmbf,swkimpl,merge(1,0,fldecdt)
 write(u,*) 'policy',FrReduQ,merge(1,0,FlDecMpRat),merge(1,0,fldtmin)
 write(u,*) 'theta',theta(1:numnod)
 write(u,*) 'thetm1',thetm1(1:numnod)
 write(u,*) 'dz',dz(1:numnod)
 write(u,*) 'fraction',FrArMtrx(1:numnod)
 write(u,*) 'pond',pond,pondm1
 write(u,*) 'matrix_stored',volact,volm1
 write(u,*) 'macro_total',WaSrMp
 write(u,*) 'macro_sat',WaSrMpDm(1:NumDm)
 write(u,*) 'macro_domain',WaUnMpDm(1:NumDm)
 write(u,*) 'macro_compartment',WaUnMpDmCp(1:NumDm,1:numnod)
 write(u,*) 'macro_volume',VlMpDmCp(1:NumDm,1:numnod)
 write(u,*) 'macro_bottom',ICpBtDm(1:NumDm)
 write(u,*) 'macro_in_lat',QInTopLatDm(1:NumDm)
 write(u,*) 'macro_in_vert',QInTopVrtDm(1:NumDm)
 write(u,*) 'macro_exchange',QExcMtxDmCp(1:NumDm,1:numnod)
 write(u,*) 'macro_rapid',QOutDrRapCp(1:numnod)
 write(u,*) 'matrix_exchange',QExcMpMtx(1:numnod)
 write(u,*) 'matrix_drains',sum(qdra(1:nrlevs,1:numnod),dim=1)
 write(u,*) 'matrix_root',qrot(1:numnod)
 write(u,*) 'matrix_ssdi',qssdi(1:numnod)
 write(u,*) 'matrix_immob',qimmob(1:numnod)
 write(u,*) 'matrix_vertical',q(1:numnod+1)
 write(u,*) 'boundary_rates',qtop,qbot,nraidt,nird,melt,runon,epd,reva
 write(u,*) 'surface',runots,ArMpSs,QMpLatSs
 write(u,*) 'clock',TimAbsCumDmCp(1:NumDm,1:numnod)
 write(u,*) 'event',merge(1,0,FlEndSrpEvt(1:NumDm,1:numnod))
 write(u,*) 'reference',ThtSrpRefDmCp(1:NumDm,1:numnod)
 write(u,*) 'sorptivity',SorpDmCp(1:NumDm,1:numnod)
 close(u)
end subroutine inventory_dump
end module MOD_SoilWater
