module MOD_SoilWater

   private
   public :: soilwater, soilwaterstatevar,retry07_checkpoint,day11_boundary,prefix14_start
   logical,save :: checkpoint_pending=.false.,followup_pending=.false.,restart_pending=.false.
   integer,save :: checkpoint_phase=0
   character(64),save :: qualification_outcome=''
   real(8),save :: accepted_dt=0d0
   integer,save :: budget_unit,budget_count=0
   logical,save :: budget_open=.false.,period_begin_done=.false.


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
            if(.not.retry07_driver()) call head_start()
 call headcalc
 call head_end()
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


subroutine prefix14_start()
 use variables,only:t1900
 use DIAG19,only:start
 use CONTRACT06_CONTROL,only:use_patch
 implicit none
 character(24)::mode
 integer::u
 call get_environment_variable('DAY10_MODE',mode)
 use_patch=.true.
 call start()
 if(trim(mode)=='PREFIX') then
  call prefix14_coverage(t1900)
  call inventory_dump('initial')
  call ledger12_dump('ledger_initial')
  call native09_dump('context_initial')
 end if
 open(newunit=budget_unit,file='step_budget.txt',status='replace')
 budget_open=.true.;budget_count=0
end subroutine
logical function retry07_driver() result(handled)
 use DIAG19,only:head_start,head_end
 use CONTRACT06_CONTROL, only:use_patch
 use variables,only:fldecdt,dt,t1900
 use MOD_swap_mp,only:FlDecMpRat
 implicit none
 character(24)::mode
 handled=.true.;use_patch=.true.
 call get_environment_variable('DAY10_MODE',mode)
 if(t1900>=35797d0.and..not.period_begin_done) then
  period_begin_done=.true.
  call inventory_dump('begin')
 call ledger12_dump('ledger_begin')
  call native09_dump('context_begin')
 end if
 accepted_dt=dt
 call headcalc
end function
subroutine retry07_checkpoint()
 use DIAG19,only:log_start,log_end,commit
 use variables,only:t1900,dt,qbot,qrot,runon,epd,reva,runots
 use MOD_meteo,only:graidt,nraidt
 use MOD_irrigation,only:gird,nird,qssdi
 use MOD_drain,only:qdra,nrlevs
 use MOD_macropore,only:QOutDrRapCp,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,FrReduQ,NumDm
 use MOD_grid,only:numnod
 use plant_interface,only:crsflx_out,sicact
 implicit none
 integer::u
 character(24)::mode
 call get_environment_variable('DAY10_MODE',mode)
 call log_start()
 if(budget_open) then
  write(budget_unit,*) t1900,accepted_dt,graidt,gird,runon,crsflx_out,epd,reva,sum(qrot(1:numnod)),qbot,sum(qdra(1:nrlevs,1:numnod)),sum(qssdi(1:numnod)),sum(QOutDrRapCp(1:numnod)),runots,nraidt,nird,FrReduQ, &
   QInTopLatDm(1:NumDm),QInTopVrtDm(1:NumDm),sum(QExcMtxDmCp(1:NumDm,1:numnod),dim=2)
  budget_count=budget_count+1
  if(mod(budget_count,128)==0) flush(budget_unit)
 end if
 call log_end()
 if(commit()) then
  if(budget_open) close(budget_unit)
  stop 0
 end if
end subroutine
subroutine day11_boundary()
 use variables,only:t1900,outfil,fldayend
 use MOD_swap_base,only:sw_end,sw_endtype,sw_endfilter,fl_initialize
 implicit none
 integer::u
 character(80)::old_outfil
 character(24)::mode
 if(.not.fldayend) return
 call get_environment_variable('DAY10_MODE',mode)
 if(t1900==35797d0.and.trim(mode)=='PREFIX') then
  call inventory_dump('period_initial')
  call native09_dump('context_period_initial')
  call ledger12_dump('ledger_prior_period')
  call native11_ready()
  old_outfil=outfil
  outfil='midnight';sw_end=1;sw_endtype=2;sw_endfilter=0;fl_initialize=.false.
  call inoutend(1)
  outfil=old_outfil
 else if(t1900==35798d0) then
  call inventory_dump('period_final')
  call native09_dump('context_period_final')
  call ledger12_dump('ledger_period_final')
  if(budget_open) close(budget_unit)
  open(newunit=u,file='outcome.txt',status='replace');write(u,*) 'NEXT18_PERIOD_COMPLETE';close(u)
  stop 0
 end if
end subroutine

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
