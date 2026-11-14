module MOD_SoilWater

   private
   public :: soilwater, soilwaterstatevar,retry07_checkpoint
   logical,save :: checkpoint_pending=.false.,followup_pending=.false.,restart_pending=.false.
   integer,save :: checkpoint_phase=0
   character(64),save :: qualification_outcome=''


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
            if(.not.retry07_driver()) call headcalc
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


logical function retry07_driver() result(handled)
 use CONTRACT06_CONTROL, only:use_patch,trace_on
 use variables, only:t1900,dt,dtmin,fldecdt
 use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
 use MOD_macropore, only:MacroStateVar
 use MOD_swap_base, only:swdra,swfrost
 use MOD_drain, only:drain
 implicit none
 character(64),save :: mode='',context=''
 character(64) :: name
 integer :: u,attempt
 handled=.false.
 if(len_trim(mode)==0) then
  call get_environment_variable('RETRY07_MODE',mode)
  call get_environment_variable('RETRY07_CONTEXT',context)
 end if
 if(trim(mode)=='RESTART') then
  use_patch=.true.;trace_on=.false.
  call inventory_dump('restart_initialized')
 call native09_dump('extended_restart_initialized')
  open(newunit=u,file='active.marker',status='replace');close(u)
  call headcalc
  call inventory_dump('restart_solver_return')
  if(fldecdt.or.FlDecMpRat) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'NATIVE_RESTART_FIRST_STEP_REJECTED'
   close(u);stop 0
  end if
  restart_pending=.true.;checkpoint_pending=.true.;handled=.true.
  return
 end if
 if(followup_pending) then
  followup_pending=.false.
  call inventory_dump('continuous_next_begin')
 call native09_dump('extended_continuous_next_begin')
  call headcalc
  call inventory_dump('continuous_next_return')
 call native09_dump('extended_continuous_next_return')
  if(fldecdt.or.FlDecMpRat) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'CONTINUOUS_NEXT_STEP_REJECTED'
   close(u);stop 0
  end if
  checkpoint_pending=.true.;handled=.true.
  return
 end if
 if(checkpoint_phase/=0) return
 if(trim(context)=='A') then
  if(abs(t1900-35796.92d0)>1d-8.or.abs(dt-.002d0)>1d-12) return
 else if(trim(context)=='B') then
  if(abs(t1900-35796.9513533331d0)>1d-9.or.abs(dt-2d-5)>1d-14) return
 else
  return
 end if
 if(swdra/=1.or.swfrost/=0.or.IDecMpRat/=0) error stop 'scope mismatch'
 call inventory_dump('origin')
 use_patch=.true.;trace_on=.false.
 open(newunit=u,file='active.marker',status='replace');close(u)
 if(trim(mode)=='DIRECT') then
  fldecdt=.true.
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
  qualification_outcome='DIRECT_SMALL'
 else
  qualification_outcome='PATCH_LARGE'
 end if
 do attempt=1,4
  write(name,'(a,i0)') 'begin_',attempt
  call inventory_dump(trim(name))
  call headcalc
  write(name,'(a,i0)') 'returned_',attempt
  call inventory_dump(trim(name))
  if(.not.fldecdt.and..not.FlDecMpRat) then
   if(IDecMpRat/=0) error stop 'scaled acceptance excluded'
   if(attempt>1) qualification_outcome='REAL_REJECT_SMALL_RETRY'
   call inventory_dump('accepted_solver_return')
   checkpoint_pending=.true.;handled=.true.
   return
  end if
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
  write(name,'(a,i0)') 'rollback_',attempt
  call inventory_dump(trim(name))
  if(FlDecMpRat.or.IDecMpRat/=0.or.attempt==4) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'NO_UNSCALED_RETRY_WITHIN_BOUND',attempt,dt
   close(u);stop 0
  end if
  if(.not.fldecdt) error stop 'unclassified refusal'
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
end function retry07_driver

subroutine retry07_checkpoint()
 use variables, only:t1900,dt,outfil
 use MOD_swap_base, only:fl_initialize,sw_end,sw_endtype,sw_endfilter
 implicit none
 integer :: u,old_end,old_type,old_filter
 character(80) :: token,old_outfil
 if(.not.checkpoint_pending) return
 checkpoint_pending=.false.
 if(restart_pending) then
  call inventory_dump('restart_after_step')
 call native09_dump('extended_restart_after_step')
  open(newunit=u,file='outcome.txt',status='replace')
  write(u,*) 'NATIVE_RESTART_ONE_STEP_EXECUTED'
  close(u);stop 0
 end if
 if(checkpoint_phase==1) then
  call inventory_dump('continuous_after_step')
 call native09_dump('extended_continuous_after_step')
  open(newunit=u,file='outcome.txt',status='replace')
  write(u,*) trim(qualification_outcome),'_AND_CONTINUED'
  close(u);stop 0
 end if
 checkpoint_phase=1
 call inventory_dump('checkpoint')
 call native09_dump('extended_checkpoint')
 ! Genuine native writer after the actual host has advanced water, integral,
 ! heat/solute and TimeControl(3). No custom macro state is serialized.
 old_outfil=outfil;old_end=sw_end;old_type=sw_endtype;old_filter=sw_endfilter
 sw_end=1;sw_endfilter=0;fl_initialize=.false.
 outfil='candidate';sw_endtype=2
 call inoutend(1)
 outfil='candidate_text';sw_endtype=1
 call inoutend(1)
 outfil=old_outfil;sw_end=old_end;sw_endtype=old_type;sw_endfilter=old_filter
 call inventory_dump('checkpoint_after_io')
 call native09_dump('extended_checkpoint_after_io')
 open(newunit=u,file='restart_dates.txt',status='replace')
 call dtdpst('YEAR-MONTHST-DAY_HOUR:MINUTE:SECONDS.FSECONDS',t1900,token)
 write(u,'(a,a)') 'TSTART = ',trim(token)
 call dtdpst('YEAR-MONTHST-DAY_HOUR:MINUTE:SECONDS.FSECONDS',t1900+2d0*dt,token)
 write(u,'(a,a)') 'TEND = ',trim(token)
 close(u)
 open(newunit=u,file='checkpoint_outcome.txt',status='replace')
 write(u,*) trim(qualification_outcome)
 close(u)
 followup_pending=.true.
end subroutine retry07_checkpoint

subroutine inventory_dump(label)
 use MOD_grid, only:numnod,dz
 use MOD_swap_base, only:swmacro
 use MOD_macropore, only:NumDm,WaSrMp,WaSrMpDm,WaUnMpDm,WaUnMpDmCp, &
 VlMpDmCp,ICpBtDm,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,QOutDrRapCp, &
 TimAbsCumDmCp,FlEndSrpEvt,ThtSrpRefDmCp,SorpDmCp,swmbf,FrReduQ,FrMpWalWet,FrMpWalWetOld
 use MOD_swap_mp, only:FrArMtrx,QExcMpMtx,IDecMpRat,ArMpSs,QMpLatSs,FlDecMpRat
 use MOD_drain, only:qdra,nrlevs
 use MOD_irrigation, only:qssdi,nird
 use MOD_meteo, only:nraidt
 use MOD_snow, only:melt
 use variables, only:t1900,dt,h,hm1,theta,thetm1,pond,pondm1,qtop,qbot,qrot,qimmob, &
 q,volact,volm1,runon,epd,reva,runots,fldecdt,swkimpl,fldtmin
 implicit none
 character(*),intent(in) :: label
 integer :: u
 open(newunit=u,file=label//'.txt',status='replace')
 write(u,*) 'controls',t1900,dt,IDecMpRat,numnod,NumDm,swmbf,swkimpl,merge(1,0,fldecdt)
 write(u,*) 'policy',FrReduQ,merge(1,0,FlDecMpRat),merge(1,0,fldtmin)
 write(u,*) 'h',h(1:numnod)
 write(u,*) 'hm1',hm1(1:numnod)
 write(u,*) 'wet_wall',FrMpWalWet(1:NumDm,1:numnod)
 write(u,*) 'wet_wall_old',FrMpWalWetOld(1:NumDm,1:numnod)
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
