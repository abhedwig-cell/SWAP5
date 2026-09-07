! TO DO
! module MOD_solve_Richards met public subroutine headcalc
!
! aangeven per variabelel: lokaal, input, output
! sommige globale variabelen mogelijk alleen voor headcalc?
!

! ----------------------------------------------------------------------
subroutine headcalc(worker, fsi_workspace, history, state_binding)
! ----------------------------------------------------------------------
!     date               : April 2005 / Sept 2005
!     purpose            : calculate pressure heads, water contents,
!                          and conductivities for next time step
! ----------------------------------------------------------------------
   ! input
   use MOD_swap_base,      only: swmacro, i_instance
   use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, a23bu_initialize_worker
   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace
   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
   use MOD_arrays,         only: macp, mabbc
   use MOD_params,         only: nihil
   use MOD_grid,           only: numnod, z, dz, disnod
   use MOD_MvG,            only: watcon, hconduc, moiscap, dhconduc, cofgen
   use MOD_top,            only: q0, flrunoff, ftoph
   use MOD_meteo,          only: nraidt
   use MOD_macropore,      only: macropore
   use MOD_rootextraction, only: RootExtraction
   use MOD_snow,           only: melt
   use MOD_frost,          only: rfcp
   use MOD_top,            only: boundtop, pondrunoff, hsurf
   use MOD_drain,          only: qdra, nrlevs
   use MOD_irrigation,     only: qssdi, nird
   use variables,          only: fldaystart, swbotb, runon, epd, reva, pondm1, dt, runots, t1900, thetm1, qrot,      &
                                 swkimpl, swkmean, hplate, swbotb3impl, swbotb3resvert, deepgw, rimlay,              &
                                 sw4, qbotab, fldtmin, maxit, maxbacktr, critdevh2cp, critdevh1cp, critdevponddt,    &
                                 dtmin, nodgwl, gwlm1, hm1, CritDevBalCp, CritDevBalTot
   ! inout
   use variables,          only: h, theta, kmean, gwlinp, pond, dtold, qtop, qbot, hbot, itnumb
   ! output
   use variables,          only: fllowgwl, k, dimoca, numbit, fldecdt, gwl     ! note: K not always up-to-date at t+Dt

   ! macropore
   use MOD_swap_mp,        only: armpss, frarmtrx, qexcmpmtx, dfdhmp, ictopmp                        ! all input
   use MOD_swap_mp,        only: qmplatss, idecmprat                                                 ! input + output
   use MOD_swap_mp,        only: fldecmprat, fldecMPmbf                                              ! output
   implicit none

   type(a23bu_worker_context_t), target, intent(inout), optional :: worker

   type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
   type(reference_richards_workspace_t), target :: local_fsi_workspace
   type(reference_richards_workspace_t), pointer :: fsi_ws
   type(a23bu_solver_history_t), target, intent(inout), optional :: history
   type(a23bu_solver_history_t), target :: local_history
   type(a23bu_solver_history_t), pointer :: hist
   type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
   type(reference_richards_state_binding_t), target :: local_state_binding
   type(reference_richards_state_binding_t), pointer :: st
!  local
   type(a23bu_worker_context_t), target :: local_worker
   type(a23bu_worker_context_t), pointer :: ctx
   logical :: canonical_trial
   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit
   real(8)                          :: factor, Fmax
   real(8)                          :: factmax, factmax1, sump, sum1, sumold, deviat, q1
   logical                          :: flnonconv, flnonconv3
   logical                          :: flboth, flok
   character(len=200)               :: message
   character(len=19)                :: datetime
   character(len=10)                :: cval

!  macropore related
   real(8)                          :: QMpLatSsSav

!  functions
   real(8)                          :: hcomean

!  criteria
   real(8), parameter               :: Critdz = 1.0d-5

!---------------------------------------------------------------------

   if (present(state_binding)) then
      if (state_binding%active_nodes /= numnod) error stop 'F-SI07 HeadCalc state/grid mismatch'
      st => state_binding
   else
      call fsi07_load_state_from_legacy(local_state_binding)
      st => local_state_binding
   end if

   canonical_trial = present(worker)
   if (canonical_trial) then
      ctx => worker
   else
      ctx => local_worker
   end if
   if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)
   if (present(history)) then
      hist => history
   else
      hist => local_history
   end if
   if (present(fsi_workspace)) then
      fsi_ws => fsi_workspace
   else
      fsi_ws => local_fsi_workspace
   end if
   call initialize_reference_workspace(fsi_ws, numnod)
   ctx%diagnostics%headcalc_calls = ctx%diagnostics%headcalc_calls + 1

!  reset some variables at the start of a new day
   if (fldaystart) then
      hist%flwarn = .TRUE.
      hist%iwarn  = 0
   end if
 
!  summation of fsi_ws%sink terms (constant for the current time step)
   iBackTr        = 0
   fsi_ws%unsaturated_flags(1:3) = .FALSE.
   do i = 1, numnod
      fsi_ws%sink(i) = 0.0d0
      do j = 1, nrlevs
         fsi_ws%sink(i) = fsi_ws%sink(i) + qdra(j,i)
      end do
   end do 
   fsi_ws%source(1:numnod) = qssdi(1:numnod)

!  special case: groundwater level specified
   if (swbotb == 1) then
      st%fllowgwl = .FALSE.
      if (st%gwlinp >= z(1)-1.0d-4) then

         q0 = (nraidt+nird+melt)*(1.0d0-ArMpSs) + runon - reva - epd
         call fsi07_publish_state_to_legacy()
      call pondrunoff ()
      call fsi07_absorb_state_from_legacy()
         q1 = - q0 + (st%pond - st%pondm1)/dt + runots/dt
         st%theta(1) = watcon(1,st%gwlinp)
         st%kmean(1) = hconduc(1,st%gwlinp,st%theta(1),rfcp(1))
!        in case of static macropores FrArMtrx < 1
         if (swmacro == 1) st%kmean(1) = FrArMtrx(1) * st%kmean(1)

         fsi_ws%vertical_flux(1) = q1
         do i = 1, numnod
            fsi_ws%vertical_flux(i+1) = fsi_ws%vertical_flux(i) + dz(i)*FrArMtrx(i)*(st%theta(i)-st%thetm1(i)) / dt + fsi_ws%sink(i) - fsi_ws%source(i) + qrot(i) 
         end do
         st%qbot = fsi_ws%vertical_flux(numnod+1)
         st%h(1) = st%gwlinp + disnod(1)*(fsi_ws%vertical_flux(1)/st%kmean(1) + 1.0d0)
         do i = 2, numnod
            st%h(i) = st%h(i-1) + disnod(i)*(fsi_ws%vertical_flux(i)/st%kmean(i) + 1.0d0)    ! gaat dit goed: immers st%kmean(i) nog behorend bij oude tijd???, maar st%k(1) werd wel eerst opnieuw berekend
         end do

!        special case: SwKimpl = 1
         if (SwKimpl == 1) then
            do i = 1, numnod
               st%k(i) = hconduc(i,st%h(i),st%theta(i),rfcp(i))
               if (swmacro == 1)  st%k(i) = FrArMtrx(i) * st%k(i)
               if (i > 1) then
                  st%kmean(i)=hcomean(swkmean,st%k(i-1),st%k(i),dz(i-1),dz(i), i, st%h(i-1), st%h(i))
               end if
            end do
            st%kmean(numnod+1) = st%k(numnod)                  
         end if
         !call calcgwl () replaced to call soilwater(3)
!        ready
         if (.not. present(state_binding)) call fsi07_publish_state_to_legacy()
         return
      else
         NN = 0
         do while (z(NN+1) > st%gwlinp .AND. NN < numnod)
            NN = NN + 1
         end do
         if (z(NN+1) < (st%gwlinp+nihil)) then
!           groundwater within soil profile
            if ((z(NN)-st%gwlinp) < 1.0d-4 .AND. (NN > 0)) then
!              difference st%gwlinp with node to small to calculate gradient properly
               st%gwlinp = z(NN)
               NN     = NN-1
            end if
         else
!           groundwater below soil profile
            st%fllowgwl = .TRUE.
            st%hbot     = st%gwlinp - z(numnod) + 0.5d0*dz(numnod)
         end if
      end if

   else
!     for all other swbotb cases
      NN = numnod
      if (swbotb == 9) NN = numnod - 1
   end if

!  reset conductivities (st%k, st%kmean) to time level t
   do i = 1, numnod
      st%k(i) = hconduc(i,st%h(i),st%theta(i),rfcp(i))
!
      if (swmacro == 1)  st%k(i)     = FrArMtrx(i) * st%k(i)
      if (i > 1)         st%kmean(i) = hcomean(swkmean,st%k(i-1),st%k(i),dz(i-1),dz(i), i, st%h(i-1), st%h(i))
   end do
   st%kmean(numnod+1) = st%k(numnod)

!  lower and upper diagnal elements
   if (SwKimpl == 0) then
      fsi_ws%dfdh_upper = 0.0d0
      fsi_ws%dfdh_lower = 0.0d0
      do i = 2, numnod
         fsi_ws%dfdh_upper(i)   = - st%kmean(i)  /disnod(i)
         fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
      end do
   end if

!  gradient in st%h
   do i = 2, NN
      fsi_ws%head_gradient(i) = (st%h(i-1)-st%h(i))/disnod(i) + 1.0d0
   end do

!  calculate vector fsi_ws%residual (first time)
   fsi_ws%residual = 0.0d0
   call vector_F(1)

!  initial estimate of fsi_ws%residual inner product
   sumold = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))

!  start iteration loop, MaxIt specified in the input
   MaxIt1 = MaxIt
   if (fldtmin .OR. fldecmprat) MaxIt1 = 2*MaxIt
   sump = 0.d0
   do solver_numbit = 1, MaxIt1
      st%numbit = solver_numbit
      ctx%diagnostics%nonlinear_iterations = ctx%diagnostics%nonlinear_iterations + 1

!     store fsi_ws%old_head and get moiscap
      do i = 1, NN
         fsi_ws%old_head(i)   = st%h(i)
         st%dimoca(i) = moiscap(i, st%h(i))
      end do

!     special case: SwKimpl = 1
      if (SwKimpl == 1) then
         do i = 1, NN
            fsi_ws%dconductivity_dhead(i)= dhconduc(i,st%h(i),st%theta(i),st%dimoca(i),rfcp(i))
            if (swmacro == 1) fsi_ws%dconductivity_dhead(i) = FrArMtrx(i) * fsi_ws%dconductivity_dhead(i)
         end do
         do i = 2, NN
            fsi_ws%dfdh_upper(i)   = - st%kmean(i) / disnod(i)
            fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
         end do
      end if

!     incorporate Jacobian information in coefficient matrix elements
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
      call jacobian_F()

!     solve the tridiagonal matrix
      ctx%diagnostics%linear_solves = ctx%diagnostics%linear_solves + 1
      call tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, fsi_ws%residual, fsi_ws%delta_head, ierror)

!     in the rare case that TRIDAG fails, use alternative solution
      if (ierror /= 0) then
         call dtdpst ('year-month-day', t1900+1.001d0, datetime)
         write(cval,'(I10)') i_instance
         message = cval//' Tri-band matrix in HeadCalc appeared to be singular at '//adjustl(trim(datetime))//' Alternative SOLVER chosen'
         if (.NOT.canonical_trial) call swap_warning ('headcalc', message)
         ctx%diagnostics%alternative_solver_calls = ctx%diagnostics%alternative_solver_calls + 1
         call alternative_solver()
      end if

!     back tracking cycle
      factor = 1.0d0
      do itry = 1, MaxBackTr
         iBackTr = iBackTr + 1
         ctx%diagnostics%backtracking_attempts = ctx%diagnostics%backtracking_attempts + 1
!        factor reduces the change of st%h (fsi_ws%delta_head) calculated as a full Newton Raphson step

!        update st%h
         if (fldtmin .AND. st%numbit > MaxIt) then              
            factmax = 0.0d0
            do i = 1, NN
               if (dabs(fsi_ws%old_head(i) ) < 1.0d0 ) then
                  factmax = max(factmax, dabs(fsi_ws%delta_head(i))) 
               else
                  factmax = max(factmax, dabs(fsi_ws%delta_head(i) / fsi_ws%old_head(i)))
               end if
            end do
            factmax1 = min(1.0d0, 1.0d0 / factmax)
            do i = 1, NN
               st%h(i) = fsi_ws%old_head(i) - fsi_ws%delta_head(i) * factmax1
            end do
         else
            do i = 1, NN
               st%h(i) = fsi_ws%old_head(i) - factor * fsi_ws%delta_head(i)
            end do
         end if

!        update st%theta
         do i = 1, NN
           st%theta(i) = watcon(i,st%h(i))
         end do

!        update gradient in st%h
         do i = 2, NN
            fsi_ws%head_gradient(i) = (st%h(i-1)-st%h(i))/disnod(i) + 1.0d0
         end do

!        special case: update st%k and st%kmean if SwKimpl = 1
         if (SwKimpl == 1) then
            call Rootextraction(2)
            do i = 1, NN
               st%k(i) = hconduc(i,st%h(i),st%theta(i),rfcp(i))
               if (swmacro == 1) st%k(i) = FrArMtrx(i) * st%k(i)
               if (i > 1) then
                  st%kmean(i) = hcomean(swkmean, st%k(i-1), st%k(i), dz(i-1), dz(i), i, st%h(i-1), st%h(i))
               end if
            end do
            st%kmean(NN+1) = st%k(NN)
         end if

!        re-calculate fsi_ws%residual-function
         call vector_F(2)

!        calculate maximum deviation per compartment and new inner product
         sump = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))
         sum1 = sum(fsi_ws%residual(1:NN))
         Fmax = maxval(dabs(fsi_ws%residual(1:NN)))

!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0

      end do
 1    continue

!     check on convergence of solution

!     initialize flags
!     main flag for testing the convergence
      flnonconv = .FALSE.

!     flags introduced for debugging purposes
      fsi_ws%nonconverged_balance(1:numnod) = .FALSE.
      fsi_ws%nonconverged_head(1:numnod) = .FALSE.
      flnonconv3 = .FALSE.

!     apply performance criteria per compartment
      do i = 1, NN

!        test for water balance deviation of soil compartments
         if (dabs(fsi_ws%residual(i)) >  CritDevBalCp) then
            fsi_ws%nonconverged_balance(i) = .TRUE.
            flnonconv     = .TRUE.
         end if

!        test for change of pressure head
         if (dabs(fsi_ws%old_head(i)) < 1.0d0) then
            if (abs(st%h(i)-fsi_ws%old_head(i) ) > CritDevh2Cp) then
               fsi_ws%nonconverged_head(i) = .TRUE.
               flnonconv     = .TRUE.
            end if
         else
            if (abs(st%h(i)-fsi_ws%old_head(i) )/abs(fsi_ws%old_head(i)) > CritDevh1Cp) then
               fsi_ws%nonconverged_head(i) = .TRUE.
               flnonconv     = .TRUE.
            end if
         end if
    
      end do

!     test for waterbalance of ponding layer
      if (ftoph) then
         st%qtop = -st%kmean(1)*((hsurf - st%h(1))/disnod(1) + 1.0d0)
         if (.NOT.flnonconv .AND. (swmacro == 0 .OR. IcTopMp > 1)) then
            deviat = st%pond - st%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - st%qtop * dt
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
      end if

!     in case of macropores
      if (swmacro == 1 .AND. IcTopMp == 1) then
         deviat = st%pond - st%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - st%qtop * dt + ArMpSs * (nraidt+nird+Melt)*dt + QMpLatSs
         if (abs(deviat) > CritDevPondDt) then
            flnonconv3 = .TRUE.
            flnonconv  = .TRUE.
         end if
      end if
      if (swmacro == 1 .AND. fldecMPmbf) then
         flnonconv = .TRUE.
      end if
      

!     implemented to improve iteration performance in case of macropores
      if (dt <  0.01d0 .AND. swmacro == 1 .AND. .NOT.flnonconv3) then 
         flok = .TRUE.
         if (dt > 10.d0*dtmin) then
            do i = 1, nodgwl
               if (st%h(i) > 0.0d0 .AND. fsi_ws%nonconverged_balance(i) .AND. fsi_ws%nonconverged_head(i)) flok = .FALSE.
            end do
         else
            continue
         end if
         if (flok) then
            if (.NOT.fsi_ws%unsaturated_flags(1)) then
               fsi_ws%unsaturated_flags(1) = .TRUE.
            else if (.NOT. fsi_ws%unsaturated_flags(2)) then
               fsi_ws%unsaturated_flags(2) = .TRUE.
            else
               fsi_ws%unsaturated_flags(3) = .TRUE.                 
            end if
         else
            fsi_ws%unsaturated_flags(1:3) = .FALSE.
         end if
      end if

      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.

!     save sump voor next iteration
      sumold = sump

      if (.NOT.flnonconv) then      ! convergence has been reached
     
!        special case for macropores
         if (swmacro == 1) then
            FlDecMpRat = .FALSE.
            if (IDecMpRat > 0) then
               if (hist%nstep < 10) then
                  hist%nstep = hist%nstep + 1
               end if
               if (dt > dtold .OR. hist%nstep >= 10) then
                  dtold = dt
                  hist%nstep = 0
                  IDecMpRat = IDecMpRat - 1
               end if
            end if
         end if

!        special case swbotb = 1
         if (swbotb == 1 .AND. (.NOT.st%fllowgwl)) then
!           derive vertical flux profile in order to find st%qbot as a lower boundary condition for the saturated part of the soil system
            fsi_ws%vertical_flux(1) = st%qtop
            do i = NN+1, numnod
               st%theta(i) = cofgen(2,i)
            end do
            do i = 1, numnod
              fsi_ws%vertical_flux(i+1) = fsi_ws%vertical_flux(i) + dz(i)*FrArMtrx(i)*(st%theta(i)-st%thetm1(i)) / dt + fsi_ws%sink(i) - fsi_ws%source(i) + qrot(i)
            end do
            st%qbot = fsi_ws%vertical_flux(numnod+1)
!           st%h in saturated zone
            do i = NN+1, numnod
               st%h(i) = st%h(i-1) + disnod(i)*(fsi_ws%vertical_flux(i)/st%kmean(i) + 1.0d0)
            end do
         end if
   
!        calculate new groundwater level
         !call calcgwl () replaced to call soilwater(3)

!        recording of number of iteration steps needed
         itnumb(min(100,st%numbit),1) = itnumb(min(100,st%numbit),1) + 1 
         itnumb(min(100,st%numbit),2) = itnumb(min(100,st%numbit),2) + iBackTr 

         ctx%control%last_numbit = st%numbit
         if (.not. present(state_binding)) call fsi07_publish_state_to_legacy()
         return
      end if
   ! end do st%numbit = 1, MaxIt1
   end do

!  Convergence could not been reached
   if (.NOT.fldtmin) then

!     reset soil state variables
      do j = 1, numnod
         st%h(j)     = st%hm1(j)
         st%theta(j) = st%thetm1(j)
      end do
      st%kmean(numnod+1) = st%k(numnod)
      st%gwl             = st%gwlm1
      st%pond            = st%pondm1

!     reset and continue iteration with smaller timestep!
      st%fldecdt = .TRUE.
      ctx%control%request_dt_reduction = .TRUE.
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1

      if (.not. present(state_binding)) call fsi07_publish_state_to_legacy()

      return
   else if (swmacro == 1 .AND. IDecMpRat < 3) then
!     in case of macropores, retry with reduction of exchange fluxes with matrix
      IDecMpRat  = IDecMpRat + 1
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1
      FlDecMpRat = .TRUE.
      dtold      = dt
      fldtmin    = .FALSE.

      if (.not. present(state_binding)) call fsi07_publish_state_to_legacy()

      return
   else
!     write warning to screen and log file
      if (hist%flwarn) then
         hist%iwarn = hist%iwarn + 1
         call dtdpst('year-month-day,hour:minute:seconds',t1900,datetime)
         write(cval,'(I10)') i_instance
         message = cval//' No convergence was reached of Richards equation at '//datetime//' no more than 4 warnings per date - SWAP did continue!'
         if (.NOT.canonical_trial) call swap_warning ('headcalc', message)
         if (hist%iwarn > 3) hist%flwarn = .FALSE.  
      end if

!     continue without convergence !!!
      if (.not. present(state_binding)) call fsi07_publish_state_to_legacy()
      return
   end if

contains

subroutine fsi07_load_state_from_legacy(target)
   type(reference_richards_state_binding_t), intent(inout) :: target
   call target%ensure_shape(numnod)
   target%h = h(1:numnod)
   target%theta = theta(1:numnod)
   target%hm1 = hm1(1:numnod)
   target%thetm1 = thetm1(1:numnod)
   target%k = k(1:numnod)
   target%kmean = kmean(1:numnod+1)
   target%dimoca = dimoca(1:numnod)
   target%pond = pond
   target%pondm1 = pondm1
   target%gwl = gwl
   target%gwlm1 = gwlm1
   target%qtop = qtop
   target%qbot = qbot
   target%hbot = hbot
   target%gwlinp = gwlinp
   target%fllowgwl = fllowgwl
   target%fldecdt = fldecdt
   target%numbit = numbit
end subroutine fsi07_load_state_from_legacy

subroutine fsi07_publish_state_to_legacy()
   h(1:numnod) = st%h
   theta(1:numnod) = st%theta
   hm1(1:numnod) = st%hm1
   thetm1(1:numnod) = st%thetm1
   k(1:numnod) = st%k
   kmean(1:numnod+1) = st%kmean
   dimoca(1:numnod) = st%dimoca
   pond = st%pond
   pondm1 = st%pondm1
   gwl = st%gwl
   gwlm1 = st%gwlm1
   qtop = st%qtop
   qbot = st%qbot
   hbot = st%hbot
   gwlinp = st%gwlinp
   fllowgwl = st%fllowgwl
   fldecdt = st%fldecdt
   numbit = st%numbit
end subroutine fsi07_publish_state_to_legacy

subroutine fsi07_absorb_state_from_legacy()
   st%h = h(1:numnod)
   st%theta = theta(1:numnod)
   st%hm1 = hm1(1:numnod)
   st%thetm1 = thetm1(1:numnod)
   st%k = k(1:numnod)
   st%kmean = kmean(1:numnod+1)
   st%dimoca = dimoca(1:numnod)
   st%pond = pond
   st%pondm1 = pondm1
   st%gwl = gwl
   st%gwlm1 = gwlm1
   st%qtop = qtop
   st%qbot = qbot
   st%hbot = hbot
   st%gwlinp = gwlinp
   st%fllowgwl = fllowgwl
   st%fldecdt = fldecdt
   st%numbit = numbit
end subroutine fsi07_absorb_state_from_legacy


!----------------------------------------------------------------------------------
! Alternative solution procedure in the rare case that TRIDAG failed.
!
! From Numerical Recipes, section 2.4:
! There is no pivoting in TRIDAG. It is for this reason that TRIDAG can fail
! (pause) even when the underlying matrix is nonsingular. In that case, 
! you can instead use the more general method for band diagonal systems,
! by using routines bandec and banbks, as is implemented here.
!----------------------------------------------------------------------------------
   subroutine alternative_solver()
   ! local
   integer                    :: i
   real(8)                    :: d

   do i = 1, NN
      fsi_ws%band_matrix(i,1) = fsi_ws%dfdh_upper(i)
      fsi_ws%band_matrix(i,2) = fsi_ws%dfdh_main(i)
      fsi_ws%band_matrix(i,3) = fsi_ws%dfdh_lower(i)
   end do
   call bandec(fsi_ws%band_matrix, NN, 1, 1, macp, 3, fsi_ws%band_aux, 1, fsi_ws%band_pivots, d)
   fsi_ws%band_rhs(1:NN) = fsi_ws%residual(1:NN)
   call banbks(fsi_ws%band_matrix,nn,1,1,macp,3,fsi_ws%band_aux,1,fsi_ws%band_pivots,fsi_ws%band_rhs)
   fsi_ws%delta_head(1:NN) = fsi_ws%band_rhs(1:NN)
   return
   end subroutine alternative_solver

!----------------------------------------------------------------------------------
! Function fsi_ws%residual: calculate right-hand-side vector fsi_ws%residual
!----------------------------------------------------------------------------------
subroutine vector_F(iTask)
!  global
   integer, intent(in)        :: iTask

!  local
!  functions
   real(8)                    :: afgen

!  top layer
   fsi_ws%residual(1) = (st%theta(1) - st%thetm1(1)) * FrArMtrx(1) * dz(1) / dt + fsi_ws%sink(1) - fsi_ws%source(1) + qrot(1) + st%kmean(2) * fsi_ws%head_gradient(2)

!  depending on iTask
   if (iTask == 2 .AND. swmacro == 1) QMpLatSsSav = QMpLatSs

!  take care of top BC
   call fsi07_publish_state_to_legacy()
      call boundtop(2)
      call fsi07_absorb_state_from_legacy()

!  depending on iTask
   if (swmacro == 1) then
      if (iTask == 1 .OR. .NOT. fsi_ws%unsaturated_flags(3)) then 
         call fsi07_publish_state_to_legacy()
      call MACROPORE(2)
      call fsi07_absorb_state_from_legacy()
      else
         QMpLatSs = QMpLatSsSav
      end if
   end if

!  take care of top BC: ponding, runoff
   if (FlRunoff .OR. ArMpSs > 0.0d0) call fsi07_publish_state_to_legacy()
      call pondrunoff ()
      call fsi07_absorb_state_from_legacy()

!  first layer, continued
   if (ftoph) then
      fsi_ws%head_gradient(1) = (hsurf-st%h(1))/disnod(1) + 1.d0
      fsi_ws%residual(1)     = fsi_ws%residual(1) - st%kmean(1) * fsi_ws%head_gradient(1)
   else
      fsi_ws%residual(1) = fsi_ws%residual(1) + st%qtop
   end if

!  layers 2 to (NN-1)
   do i = 2, NN-1
      fsi_ws%residual(i) = (st%theta(i) - st%thetm1(i)) * FrArMtrx(i) * dz(i) / dt + fsi_ws%sink(i) - fsi_ws%source(i) + qrot(i) - st%kmean(i) * fsi_ws%head_gradient(i) + st%kmean(i+1) * fsi_ws%head_gradient(i+1)
   end do

!  for bottom BC
   if (swbotb == 1 .AND. (.NOT.st%fllowgwl)) then
      fsi_ws%head_gradient(NN+1) = st%h(NN)/(z(nn)-st%gwlinp) + 1.0d0
   else if (swbotb == 5 .OR. (swbotb == 1 .AND. st%fllowgwl)) then
      fsi_ws%head_gradient(NN+1) = (st%h(NN) - st%hbot) / disnod(NN+1) + 1.0d0
   else if (swbotb == 9) then
      fsi_ws%head_gradient(NN+1) = (st%h(NN) - st%h(NN+1)) / disnod(NN+1) + 1.0d0
   end if

!  for swbotb = 8, depending on iTask
   if (iTask == 1) then
      if (swbotb == 8 .AND. st%h(NN) >  Critdz - disnod(NN+1) + hplate) then
         fsi_ws%head_gradient(NN+1) = (st%h(NN) - hplate) / disnod(NN+1) + 1.0d0
         flboth = .TRUE.
      else
         flboth = .FALSE.
      end if
   else
      if (swbotb == 8 .AND. flboth) then
         fsi_ws%head_gradient(NN+1) = (st%h(NN) - hplate) / disnod(NN+1) + 1.0d0
      end if
   end if

   ! for bottom BC, continued
   if (swbotb == 1 .AND. (.NOT.st%fllowgwl)) then
      st%theta(NN) = watcon(NN,st%h(NN))
      st%k(NN)     = hconduc(NN,st%h(NN),st%theta(NN),rfcp(NN))
      ! in case of static macropores FrArMtrx < 1
      if (swmacro == 1) st%k(NN) = FrArMtrx(NN) * st%k(NN)
      st%kmean(NN+1) = hcomean(swkmean, st%k(NN), cofgen(3,(NN+1)), dz(NN), dz(NN+1), NN, st%h(NN), 0.0d0)
      fsi_ws%residual(NN)       = (st%theta(NN) - st%thetm1(NN))*FrArMtrx(NN)*dz(NN)/dt - st%kmean(NN) * fsi_ws%head_gradient(NN) + st%kmean(NN+1) * fsi_ws%head_gradient(NN+1) + fsi_ws%sink(NN) - fsi_ws%source(NN) + qrot(NN)
   else
      fsi_ws%residual(NN) = (st%theta(NN) - st%thetm1(NN))*FrArMtrx(NN)*dz(NN)/dt - st%kmean(NN) * fsi_ws%head_gradient(NN) + fsi_ws%sink(NN) - fsi_ws%source(NN) + qrot(NN) 
      if (swbotb == 3 .AND. swbotb3Impl == 1) then
         
         ! Cauchy-relation, implemented as head boundary
         if (SwBotb3ResVert == 0) then
            st%qbot = - (st%h(NN)+z(NN)-deepgw) / (disnod(NN+1)/st%kmean(NN+1)+rimlay)
         else if (SwBotb3ResVert == 1) then
            st%qbot = - (st%h(NN)+z(NN)-deepgw) / rimlay
         end if
         
         ! extra groundwater flux might be added
         if (sw4 == 1) st%qbot = st%qbot + afgen(qbotab,mabbc*2,t1900+dt)
         fsi_ws%residual(NN) = fsi_ws%residual(NN) - st%qbot     
      
      else if (swbotb == 5 .OR. (swbotb == 1 .AND. st%fllowgwl)) then
         
         ! pressure head at lower boundary specified
         fsi_ws%residual(NN) = fsi_ws%residual(NN) + st%kmean(NN+1) * fsi_ws%head_gradient(NN+1)

      else if (swbotb == 9) then
         
         ! pressure head at lower boundary specified
         fsi_ws%residual(NN) = fsi_ws%residual(NN) + st%kmean(NN+1) * fsi_ws%head_gradient(NN+1)
         !!!fsi_ws%residual(NN) = fsi_ws%residual(NN) - st%qbot
      
      else if (swbotb == 7 .OR. swbotb == -2) then 
         
         ! free drainage option
         st%kmean(numnod+1) = hconduc(numnod,st%h(numnod),st%theta(numnod),rfcp(numnod))
         if (swmacro == 1) st%kmean(numnod+1) = FrArMtrx(numnod) * st%kmean(numnod+1)
         st%qbot = -1.0d0 * st%kmean(numnod+1)
         fsi_ws%residual(NN) = fsi_ws%residual(NN) - st%qbot
      
      else if (swbotb == 8) then                                  
         
         ! lysimeter option
         if (flboth) then
            st%hbot = hplate
            fsi_ws%residual(NN) = fsi_ws%residual(NN) + st%kmean(NN+1) * fsi_ws%head_gradient(NN+1)
         else
            st%qbot = 0.0d0
         end if
      
      else
         
          ! flux bottom boundary
         fsi_ws%residual(NN) = fsi_ws%residual(NN) - st%qbot
      
      end if

   end if

   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F

subroutine jacobian_F()

!  first layer
   fsi_ws%dfdh_main(1) = st%dimoca(1)*FrArMtrx(1)*dz(1)/dt - fsi_ws%dfdh_lower(1)
 
!  if the head boundary condition applies: add the k1/(0.5*dz1) term to the first element of the main diagonal 
   if (ftoph) fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + st%kmean(1)/disnod(1)  

!  layers 2 to (NN-1)
   do i = 2, NN-1
      fsi_ws%dfdh_main(i) = st%dimoca(i)*FrArMtrx(i)*dz(i)/dt - fsi_ws%dfdh_upper(i) - fsi_ws%dfdh_lower(i) 
   end do

!  last layer: handle bottom BC
   fsi_ws%dfdh_main(NN) = st%dimoca(NN)*FrArMtrx(NN)*dz(NN)/dt - fsi_ws%dfdh_upper(NN) 
   if (swbotb == 1 .AND. (.NOT.st%fllowgwl)) then
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + st%kmean(NN+1)/(z(NN)-st%gwlinp) 
   else if (swbotb == 3 .AND. swbotb3Impl == 1) then ! Cauchy
      if (SwBotb3ResVert == 0) then
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 1.0d0 / (disnod(NN+1)/st%kmean(NN+1) + rimlay)   
      else if (SwBotb3ResVert == 1) then
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 1.0d0 / rimlay
      end if
   else if (swbotb == 5 .OR. (swbotb == 1 .AND. st%fllowgwl) .OR. swbotb == 9) then
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + st%kmean(NN+1)/disnod(NN+1)         
   else if (swbotb == 7 .OR. swbotb == -2) then ! implicitly: st%kmean(NN+1)
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + fsi_ws%dconductivity_dhead(NN) * 0.5d0
   else if (swbotb == 8 .AND. flboth) then
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + st%kmean(NN+1)/disnod(NN+1)
   end if

!  special case when SwKimpl = 1
   if (SwKimpl == 1) then
      if (swbotb == 9) call swap_error ('headcalc', 'swbotb = 9 AND swkimpl = 1 not yet implemented')
!     first layer
      fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(2) * dkmean(swkmean,st%k(1),st%k(2),dz(1),dz(2))
      if (ftoph) fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) - fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(1) * 0.5d0
      fsi_ws%dfdh_lower(1) = fsi_ws%dfdh_lower(1) + fsi_ws%dconductivity_dhead(2) * fsi_ws%head_gradient(2) * dkmean(swkmean,st%k(2),st%k(1),dz(2),dz(1)) 
!     layers 2 to (NN-1)
      do i = 2, NN-1
         fsi_ws%dfdh_upper(i) = fsi_ws%dfdh_upper(i) - fsi_ws%dconductivity_dhead(i-1) * fsi_ws%head_gradient(i) * dkmean(swkmean,st%k(i-1),st%k(i),dz(i-1),dz(i)) 
         fsi_ws%dfdh_main(i) = fsi_ws%dfdh_main(i) - fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i) * dkmean(swkmean,st%k(i),st%k(i-1),dz(i),dz(i-1)) + fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i+1) * dkmean(swkmean,st%k(i),st%k(i+1),dz(i),dz(i+1))
         fsi_ws%dfdh_lower(i) = fsi_ws%dfdh_lower(i) + fsi_ws%dconductivity_dhead(i+1) * fsi_ws%head_gradient(i+1) * dkmean(swkmean,st%k(i+1),st%k(i),dz(i+1),dz(i)) 
      end do
!     last layer
      fsi_ws%dfdh_upper(NN) = fsi_ws%dfdh_upper(NN) - fsi_ws%dconductivity_dhead(NN-1) * fsi_ws%head_gradient(NN) * dkmean(swkmean,st%k(NN-1),st%k(NN),dz(NN-1),dz(NN)) 
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) - fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN) * dkmean(swkmean,st%k(NN),st%k(NN-1),dz(NN),dz(NN-1))

      if (swbotb == 1 .OR. swbotb == 5 .OR. swbotb == 8 .AND. flboth) then
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0 * fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN+1)
      end if
   end if

!  special case macropore
   if (swmacro == 1 .AND. .NOT.fsi_ws%unsaturated_flags(3)) then
      call fsi07_publish_state_to_legacy()
      call MACROPORE(3)
      call fsi07_absorb_state_from_legacy()
      fsi_ws%dfdh_main(1:NN) = fsi_ws%dfdh_main(1:NN) - dFdhMp(1:NN)
   end if

end subroutine jacobian_F


      function dkmean(swkmean,kmain,ksub,dzmain,dzsub)
!     d(hcomean)/d(kmain); note kmain = kup in hcomean and ksub = klow in hcomean; dzmain = dzup in hcomena, and dzub = dzlow in hcomean
      implicit none
      ! global
      integer, intent(in)  :: swkmean
      real(8), intent(in)  :: kmain, ksub, dzmain, dzsub
      real(8)              :: dkmean
      ! local
      real(8)              :: a

      if (swkmean == 1) then
         dkmean = 0.5d0
      else if (swkmean == 2) then
         dkmean = dzmain/(dzmain+dzsub)
      else if (swkmean == 3) then
         dkmean = 0.5d0 * dsqrt(ksub / kmain)
      else if (swkmean == 4) then
         a = dzmain/(dzmain+dzsub)
         dkmean = a * (ksub / kmain) ** (1.0d0 - a)
      else if (swkmean == 5) then
         dkmean = 0.5d0/(((0.5d0/kmain)+(0.5d0/ksub))**2 * kmain**2)
      else if (swkmean == 6) then
         a = dzmain/(dzmain+dzsub)
         dkmean = a/(((a/kmain)+((1.0d0-a)/ksub))**2 * kmain**2)
      end if
      return
      end function dkmean

end subroutine headcalc
