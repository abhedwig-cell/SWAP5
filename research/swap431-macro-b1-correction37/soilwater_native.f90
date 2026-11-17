module MOD_SoilWater
   use MOD_arrays,only:macp,madm

   private
   public :: soilwater, soilwaterstatevar,retry07_checkpoint,day11_boundary,prefix14_start
   logical,save :: checkpoint_pending=.false.,followup_pending=.false.,restart_pending=.false.
   integer,save :: checkpoint_phase=0
   character(64),save :: qualification_outcome=''
   real(8),save :: accepted_dt=0d0
   integer,save :: budget_unit,budget_count=0,prefix_unit
   logical,save :: budget_open=.false.,period_begin_done=.false.,reject26_pending=.false.


   real(8),save::pre_theta(macp),pre_domain(madm),pre_pond,pre_canopy
   integer,save::inventory_unit

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


subroutine prefix14_start()
 use DIAG19,only:start,qualification_active
 use CONTRACT06_CONTROL,only:use_patch
 implicit none
 use_patch=.true.;qualification_active=.true.
 call start()
 open(newunit=budget_unit,file='step_budget.txt',status='replace')
 open(newunit=inventory_unit,file='inventory_trace.txt',status='replace')
 budget_open=.true.;budget_count=0
 call inventory_dump('initial')
 call native09_dump('context_initial')
 call ledger12_dump('ledger_initial')
end subroutine

subroutine capture33()
 use MOD_grid,only:numnod
 use MOD_macropore,only:NumDm,WaUnMpDm
 use variables,only:theta,pond,dt
 use plant_interface,only:sicact
 pre_theta(1:numnod)=theta(1:numnod)
 pre_domain(1:NumDm)=WaUnMpDm(1:NumDm)
 pre_pond=pond;pre_canopy=sicact;accepted_dt=dt
end subroutine

logical function retry07_driver() result(handled)
 use DIAG19,only:head_start,head_end,attempts,detail33,active_in_attempt,apply37
 use variables,only:t1900,dt,fldecdt
 use MOD_swap_mp,only:IDecMpRat,FlDecMpRat
 use MOD_macropore,only:MacroStateVar
 use MOD_drain,only:drain
 implicit none
 character(24)::mode
 character(80)::text
 character(60)::label
 character(8)::policy34
 integer::i,target_attempt,u
 handled=.true.
 if(.not.period_begin_done) then
  period_begin_done=.true.
  call inventory_dump('begin')
  call native09_dump('context_begin')
  call ledger12_dump('ledger_begin')
 end if
 call get_environment_variable('DAY10_MODE',mode)
 call get_environment_variable('PERIOD34_ORIGINAL_POLICY',policy34)
 target_attempt=-1
 if(trim(mode)/='TRAJ') then
  call get_environment_variable('TRAJECTORY33_ATTEMPT',text)
  read(text,*) target_attempt
 end if
 if(attempts+1/=target_attempt) then
  detail33=.false.
  call capture33()
  call head_start()
  call headcalc
  call head_end()
  if(fldecdt.or.FlDecMpRat) then
   if(active_in_attempt>0) then
    call inventory_dump('refused')
    call native09_dump('context_refused')
    call ledger12_dump('ledger_refused')
    open(newunit=u,file='event33.txt',status='replace')
    write(u,*) attempts,t1900,dt,active_in_attempt,IDecMpRat,merge(1,0,fldecdt),merge(1,0,FlDecMpRat)
    close(u)
    call SoilWaterStateVar(2)
    call MacroStateVar(2)
    call inventory_dump('rollback')
    call native09_dump('context_rollback')
    call ledger12_dump('ledger_rollback')
    call finish33('FIRST_ACTIVE_REFUSAL')
   else if((FlDecMpRat.or.IDecMpRat/=0).and.trim(policy34)/='1') then
    call finish33('SCALED_REQUEST_BEFORE_ACTIVE_REFUSAL')
   end if
  end if
  return
 end if
 if(abs(t1900-35797.370324351359d0)>1d-10.or.abs(dt-0.0006875745394909628d0)>1d-16) error stop 'INACTIVE35 replay context mismatch'
 if(IDecMpRat/=0) error stop 'TRAJECTORY33 scaled replay excluded'
 apply37=.true.
 call jac37_calibrate()
 detail33=.true.
 call inventory_dump('origin')
 call native09_dump('context_origin')
 call ledger12_dump('ledger_origin')
 if(trim(mode)=='DIRECT') then
  fldecdt=.true.
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end if
 do i=1,4
  write(label,'(a,i0)') 'begin_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  call capture33()
  call head_start()
  call headcalc
  call head_end()
  write(label,'(a,i0)') 'returned_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  if(.not.fldecdt.and..not.FlDecMpRat) then
   if(IDecMpRat/=0) error stop 'TRAJECTORY33 scaled retry excluded'
   call inventory_dump('accepted_return')
   call native09_dump('context_accepted_return')
   call ledger12_dump('ledger_accepted_return')
   reject26_pending=.true.
   return
  end if
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
  write(label,'(a,i0)') 'rollback_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  if(FlDecMpRat.or.IDecMpRat/=0.or.i==4) call finish33('NO_UNSCALED_RETRY_WITHIN_BOUND')
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
end function

subroutine retry07_checkpoint()
 use DIAG19,only:log_start,log_end,commit,attempts,steps,residual,active_in_attempt
 use variables,only:t1900,dt,qbot,qrot,runon,epd,reva,runots,theta,pond
 use MOD_meteo,only:graidt,nraidt
 use MOD_irrigation,only:gird,nird,qssdi
 use MOD_drain,only:qdra,nrlevs
 use MOD_macropore,only:QOutDrRapCp,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,FrReduQ,NumDm,WaUnMpDm
 use MOD_swap_mp,only:FrArMtrx
 use MOD_grid,only:numnod,dz
 use plant_interface,only:crsflx_out,sicact
 implicit none
 real(8)::dm,dp,dc,dx,external,domain_error(5)
 logical::done35
 integer::j
 call log_start()
 write(budget_unit,*) t1900,accepted_dt,graidt,gird,runon,crsflx_out,epd,reva,sum(qrot(1:numnod)),qbot,sum(qdra(1:nrlevs,1:numnod)),sum(qssdi(1:numnod)),sum(QOutDrRapCp(1:numnod)),runots,nraidt,nird,FrReduQ, &
  QInTopLatDm(1:NumDm),QInTopVrtDm(1:NumDm),sum(QExcMtxDmCp(1:NumDm,1:numnod),dim=2)
 budget_count=budget_count+1
 dm=sum((theta(1:numnod)-pre_theta(1:numnod))*dz(1:numnod)*FrArMtrx(1:numnod))
 dx=sum(WaUnMpDm(1:NumDm)-pre_domain(1:NumDm));dp=pond-pre_pond;dc=sicact-pre_canopy
 external=accepted_dt*(graidt+gird+runon-crsflx_out-epd-reva-sum(qrot(1:numnod))+qbot-sum(qdra(1:nrlevs,1:numnod))+sum(qssdi(1:numnod))-sum(QOutDrRapCp(1:numnod)))-runots
 do j=1,NumDm
  domain_error(j)=WaUnMpDm(j)-pre_domain(j)-accepted_dt*(QInTopLatDm(j)+QInTopVrtDm(j)-sum(QExcMtxDmCp(j,1:numnod)))
  if(j==1) domain_error(j)=domain_error(j)+accepted_dt*sum(QOutDrRapCp(1:numnod))
 end do
 write(inventory_unit,*) budget_count,attempts,t1900,accepted_dt,dm,dx,dp,dc,external,dm+dx+dp+dc-external,residual*accepted_dt,FrReduQ,active_in_attempt,domain_error(1:NumDm)
 if(mod(budget_count,128)==0) then
  flush(budget_unit);flush(inventory_unit)
 end if
 call log_end()
 if(reject26_pending) then
  done35=commit()
  call inventory_dump('committed')
  call native09_dump('context_committed')
  call ledger12_dump('ledger_committed')
  call finish33('TARGET_RETRY_HOST_COMMITTED')
 end if
 if(commit()) call finish33('INTERNAL_BUDGET_BEFORE_PERIOD_END')
end subroutine

subroutine finish33(reason)
 use DIAG19,only:attempts,steps,active_total,finish_target
 use variables,only:t1900,dt
 implicit none
 character(*),intent(in)::reason
 integer::u
 call inventory_dump('final')
 call native09_dump('context_final')
 call ledger12_dump('ledger_final')
 close(budget_unit);close(inventory_unit)
 call finish_target()
 open(newunit=u,file='outcome.txt',status='replace')
 write(u,*) trim(reason),steps,attempts,t1900,dt,active_total
 close(u)
 stop 0
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
  call finish33('CANDIDATE_PERIOD_COMPLETE')
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
