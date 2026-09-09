! TO DO
! module MOD_solve_Richards met public subroutine headcalc
!
! aangeven per variabelel: lokaal, input, output
! sommige globale variabelen mogelijk alleen voor headcalc?
!

! ----------------------------------------------------------------------
subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                    numerical_config, physical_config, explicit_step_duration, parameter_set)
! ----------------------------------------------------------------------
!     date               : April 2005 / Sept 2005
!     purpose            : calculate pressure heads, water contents,
!                          and conductivities for next time step
! ----------------------------------------------------------------------
   ! input
   use MOD_swap_base,      only: legacy_swmacro => swmacro, i_instance
   use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t, a23bu_initialize_worker
   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace
   use mod_reference_linear_solver, only: reference_tridag, reference_band_solve
   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, validate_reference_state_binding, &
        FSI_TOP_MODE_EXPLICIT_FLUX
   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
        soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
   use MOD_arrays,         only: mabbc
   use MOD_params,         only: nihil
   use MOD_grid,           only: legacy_numnod => numnod, legacy_z => z, legacy_dz => dz, legacy_disnod => disnod
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
   use variables,          only: legacy_fldaystart => fldaystart, legacy_swbotb => swbotb, runon, epd, reva, pondm1, legacy_dt => dt, runots, t1900, thetm1, qrot,      &
                                 legacy_swkimpl => swkimpl, legacy_swkmean => swkmean, hplate, swbotb3impl, swbotb3resvert, deepgw, rimlay,              &
                                 sw4, qbotab, legacy_fldtmin => fldtmin, legacy_maxit => maxit, legacy_maxbacktr => maxbacktr, legacy_critdevh2cp => critdevh2cp, legacy_critdevh1cp => critdevh1cp, legacy_critdevponddt => critdevponddt,    &
                                 legacy_dtmin => dtmin, nodgwl, gwlm1, hm1, legacy_CritDevBalCp => CritDevBalCp, legacy_CritDevBalTot => CritDevBalTot
   ! inout
   use variables,          only: h, theta, kmean, gwlinp, pond, dtold, qtop, qbot, hbot, itnumb
   ! output
   use variables,          only: fllowgwl, k, dimoca, numbit, fldecdt, gwl     ! note: K not always up-to-date at t+Dt

   ! macropore
   use MOD_swap_mp,        only: legacy_armpss => armpss, legacy_frarmtrx => frarmtrx, qexcmpmtx, dfdhmp, ictopmp ! all input
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
   type(reference_richards_state_binding_t), pointer :: state
   type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
   type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
   type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
   type(soil_water_physical_config_t), intent(in), optional :: physical_config
   real(8), intent(in), optional :: explicit_step_duration
   type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved
   logical :: explicit_geometry
   logical :: provider_constitutive_active, provider_source_sink_active, provider_root_sink_active
!  local
   type(a23bu_worker_context_t), target :: local_worker
   type(a23bu_worker_context_t), pointer :: ctx
   logical :: canonical_trial
   logical :: at_min_dt, day_start_event
   integer                          :: numnod
   integer                          :: swmacro, swbotb, swkimpl, swkmean, maxit, maxbacktr
   real(8)                          :: dt, dtmin, critdevh2cp, critdevh1cp, critdevponddt
   real(8)                          :: CritDevBalCp, CritDevBalTot
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

   legacy_state_binding = .not. present(state_binding)
   explicit_geometry = .not. legacy_state_binding
   if (explicit_geometry) then
      if (.not. present(parameter_set)) error stop 'HeadCalc: explicit parameter geometry required'
      numnod = parameter_set%active_nodes
      if (numnod <= 0) error stop 'HeadCalc: explicit active_nodes must be positive'
      if (.not. allocated(parameter_set%z) .or. .not. allocated(parameter_set%dz) .or. &
          .not. allocated(parameter_set%node_distance)) error stop 'HeadCalc: incomplete explicit grid geometry'
      if (size(parameter_set%z) /= numnod .or. size(parameter_set%dz) /= numnod .or. &
          size(parameter_set%node_distance) /= numnod) error stop 'HeadCalc: explicit grid geometry shape mismatch'
   else
      numnod = legacy_numnod
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
   if (present(state_binding)) then
      state => state_binding
      call validate_reference_state_binding(state, state_ok)
      if (.not. state_ok) error stop 'HeadCalc: invalid explicit state binding'
   else
      state => local_state_binding
      call capture_legacy_state(state)
   end if
   swmacro = legacy_swmacro
   swbotb = legacy_swbotb
   dt = legacy_dt
   swkimpl = legacy_swkimpl
   swkmean = legacy_swkmean
   maxit = legacy_maxit
   maxbacktr = legacy_maxbacktr
   dtmin = legacy_dtmin
   critdevh2cp = legacy_critdevh2cp
   critdevh1cp = legacy_critdevh1cp
   critdevponddt = legacy_critdevponddt
   CritDevBalCp = legacy_CritDevBalCp
   CritDevBalTot = legacy_CritDevBalTot
   if (legacy_state_binding) then
      at_min_dt = legacy_fldtmin
      day_start_event = legacy_fldaystart
   else
      at_min_dt = ctx%control%at_min_dt
      day_start_event = ctx%time%day_start_event
   end if
   if (.not. legacy_state_binding) then
      if (.not. present(physical_config)) error stop 'HeadCalc: explicit physical config required'
      if (physical_config%macropore_active) error stop 'HeadCalc: active explicit macropore route not admitted'
      swmacro = 0
      if (.not. present(boundary_conditions)) error stop 'HeadCalc: explicit boundary conditions required'
      swbotb = boundary_conditions%bottom_mode
      if (.not. present(numerical_config)) error stop 'HeadCalc: explicit numerical config required'
      if (.not. present(explicit_step_duration)) error stop 'HeadCalc: explicit step duration required'
      if (explicit_step_duration <= 0.0d0) error stop 'HeadCalc: explicit step duration must be positive'
      dt = explicit_step_duration
      swkimpl = numerical_config%conductivity_implicit_mode
      swkmean = numerical_config%conductivity_mean_method
      maxit = numerical_config%max_iterations
      maxbacktr = numerical_config%max_backtracking
      dtmin = numerical_config%min_step_duration
      CritDevBalCp = numerical_config%compartment_balance_tolerance
      CritDevBalTot = numerical_config%total_balance_tolerance
      critdevh2cp = numerical_config%head_abs_tolerance
      critdevh1cp = numerical_config%head_rel_tolerance
      critdevponddt = numerical_config%ponding_tolerance
   end if
   provider_top_active = .false.
   provider_constitutive_active = .false.
   provider_source_sink_active = .false.
   provider_root_sink_active = .false.
   if (.not. legacy_state_binding .and. present(evaluation_context)) then
      provider_constitutive_active = associated(evaluation_context%constitutive)
      provider_source_sink_active = associated(evaluation_context%source_sink)
      provider_root_sink_active = associated(evaluation_context%root_sink)
      if (.not. provider_constitutive_active) error stop 'HeadCalc: explicit constitutive provider required'
      if (.not. provider_source_sink_active) error stop 'HeadCalc: explicit source/sink provider required'
      if (provider_root_sink_active .and. SwKimpl /= 0) &
           error stop 'HeadCalc: root-sink provider requires swkimpl=0 in F-SI11'
   end if
   if (.not. legacy_state_binding .and. present(evaluation_context) .and. present(boundary_conditions)) then
      provider_top_active = associated(evaluation_context%top_boundary) .and. &
                            boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX
   end if
   provider_runoff_resolved = .false.
   if (present(fsi_workspace)) then
      fsi_ws => fsi_workspace
   else
      fsi_ws => local_fsi_workspace
   end if
   call initialize_reference_workspace(fsi_ws, numnod)
   ctx%diagnostics%headcalc_calls = ctx%diagnostics%headcalc_calls + 1

!  reset some variables at the start of a new day
   if (day_start_event) then
      hist%flwarn = .TRUE.
      hist%iwarn  = 0
   end if
 
!  summation of fsi_ws%sink terms (constant for the current time step)
   iBackTr        = 0
   fsi_ws%unsaturated_flags(1:3) = .FALSE.
   if (provider_source_sink_active) then
      call evaluation_context%source_sink%evaluate(state%h(1:numnod), state%theta(1:numnod), &
           fsi_ws%source(1:numnod), fsi_ws%sink(1:numnod))
   else
      do i = 1, numnod
         fsi_ws%sink(i) = 0.0d0
         do j = 1, nrlevs
            fsi_ws%sink(i) = fsi_ws%sink(i) + qdra(j,i)
         end do
      end do
      fsi_ws%source(1:numnod) = qssdi(1:numnod)
   end if
   fsi_ws%provider_root_sink = 0.0d0
   if (provider_root_sink_active) then
      call evaluation_context%root_sink%evaluate(state%h(1:numnod), state%theta(1:numnod), &
           fsi_ws%provider_root_sink(1:numnod))
   end if

!  special case: groundwater level specified
   if (swbotb == 1) then
      state%fllowgwl = .FALSE.
      if (state%gwlinp >= grid_z(1)-1.0d-4) then

         state%q0 = (nraidt+nird+melt)*(1.0d0-macropore_surface_fraction()) + runon - reva - epd
         call pondrunoff_state_bridge()
         q1 = - state%q0 + (state%pond - state%pondm1)/dt + state%runots/dt
         state%theta(1) = watcon(1,state%gwlinp)
         state%kmean(1) = hconduc(1,state%gwlinp,state%theta(1),rfcp(1))
!        in case of static macropores FrArMtrx < 1
         if (swmacro == 1) state%kmean(1) = matrix_fraction(1) * state%kmean(1)

         fsi_ws%vertical_flux(1) = q1
         do i = 1, numnod
            fsi_ws%vertical_flux(i+1) = fsi_ws%vertical_flux(i) + grid_dz(i)*matrix_fraction(i)*(state%theta(i)-state%thetm1(i)) / dt + fsi_ws%sink(i) - fsi_ws%source(i) + root_sink_term(i) 
         end do
         state%qbot = fsi_ws%vertical_flux(numnod+1)
         state%h(1) = state%gwlinp + grid_disnod(1)*(fsi_ws%vertical_flux(1)/state%kmean(1) + 1.0d0)
         do i = 2, numnod
            state%h(i) = state%h(i-1) + grid_disnod(i)*(fsi_ws%vertical_flux(i)/state%kmean(i) + 1.0d0)    ! gaat dit goed: immers state%kmean(i) nog behorend bij oude tijd???, maar state%k(1) werd wel eerst opnieuw berekend
         end do

!        special case: SwKimpl = 1
         if (SwKimpl == 1) then
            do i = 1, numnod
               state%k(i) = hconduc(i,state%h(i),state%theta(i),rfcp(i))
               if (swmacro == 1)  state%k(i) = matrix_fraction(i) * state%k(i)
               if (i > 1) then
                  state%kmean(i)=hcomean(swkmean,state%k(i-1),state%k(i),grid_dz(i-1),grid_dz(i), i, state%h(i-1), state%h(i))
               end if
            end do
            state%kmean(numnod+1) = state%k(numnod)                  
         end if
         !call calcgwl () replaced to call soilwater(3)
!        ready
         if (legacy_state_binding) call publish_legacy_state(state)
         return
      else
         NN = 0
         do while (grid_z(NN+1) > state%gwlinp .AND. NN < numnod)
            NN = NN + 1
         end do
         if (grid_z(NN+1) < (state%gwlinp+nihil)) then
!           groundwater within soil profile
            if ((grid_z(NN)-state%gwlinp) < 1.0d-4 .AND. (NN > 0)) then
!              difference state%gwlinp with node to small to calculate gradient properly
               state%gwlinp = grid_z(NN)
               NN     = NN-1
            end if
         else
!           groundwater below soil profile
            state%fllowgwl = .TRUE.
            state%hbot     = state%gwlinp - grid_z(numnod) + 0.5d0*grid_dz(numnod)
         end if
      end if

   else
!     for all other swbotb cases
      NN = numnod
      if (swbotb == 9) NN = numnod - 1
   end if

!  reset conductivities (state%k, state%kmean) to time level t
   if (provider_constitutive_active) then
      call evaluation_context%constitutive%evaluate(state%h(1:numnod), fsi_ws%provider_theta, fsi_ws%provider_k, &
           fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
      state%k(1:numnod) = fsi_ws%provider_k(1:numnod)
   else
      do i = 1, numnod
         state%k(i) = hconduc(i,state%h(i),state%theta(i),rfcp(i))
      end do
   end if
   do i = 1, numnod
      if (swmacro == 1)  state%k(i)     = matrix_fraction(i) * state%k(i)
      if (i > 1)         state%kmean(i) = hcomean(swkmean,state%k(i-1),state%k(i),grid_dz(i-1),grid_dz(i), i, state%h(i-1), state%h(i))
   end do
   state%kmean(numnod+1) = state%k(numnod)

!  lower and upper diagnal elements
   if (SwKimpl == 0) then
      fsi_ws%dfdh_upper = 0.0d0
      fsi_ws%dfdh_lower = 0.0d0
      do i = 2, numnod
         fsi_ws%dfdh_upper(i)   = - state%kmean(i)  /grid_disnod(i)
         fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
      end do
   end if

!  gradient in state%h
   do i = 2, NN
      fsi_ws%head_gradient(i) = (state%h(i-1)-state%h(i))/grid_disnod(i) + 1.0d0
   end do

!  calculate vector fsi_ws%residual (first time)
   fsi_ws%residual = 0.0d0
   call vector_F(1)

!  initial estimate of fsi_ws%residual inner product
   sumold = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))

!  start iteration loop, MaxIt specified in the input
   MaxIt1 = MaxIt
   if (at_min_dt) MaxIt1 = 2*MaxIt
   if (legacy_state_binding) then
      if (fldecmprat) MaxIt1 = 2*MaxIt
   else if (swmacro == 1) then
      if (fldecmprat) MaxIt1 = 2*MaxIt
   end if
   sump = 0.d0
   do solver_numbit = 1, MaxIt1
      state%numbit = solver_numbit
      ctx%diagnostics%nonlinear_iterations = ctx%diagnostics%nonlinear_iterations + 1

!     store fsi_ws%old_head and get moiscap
      do i = 1, NN
         fsi_ws%old_head(i) = state%h(i)
      end do
      if (provider_constitutive_active) then
         call evaluation_context%constitutive%evaluate(state%h(1:numnod), fsi_ws%provider_theta, fsi_ws%provider_k, &
              fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
         state%dimoca(1:NN) = fsi_ws%provider_capacity(1:NN)
      else
         do i = 1, NN
            state%dimoca(i) = moiscap(i, state%h(i))
         end do
      end if

!     special case: SwKimpl = 1
      if (SwKimpl == 1) then
         do i = 1, NN
            fsi_ws%dconductivity_dhead(i)= dhconduc(i,state%h(i),state%theta(i),state%dimoca(i),rfcp(i))
            if (swmacro == 1) fsi_ws%dconductivity_dhead(i) = matrix_fraction(i) * fsi_ws%dconductivity_dhead(i)
         end do
         do i = 2, NN
            fsi_ws%dfdh_upper(i)   = - state%kmean(i) / grid_disnod(i)
            fsi_ws%dfdh_lower(i-1) = fsi_ws%dfdh_upper(i)
         end do
      end if

!     incorporate Jacobian information in coefficient matrix elements
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
      call jacobian_F()

!     solve the tridiagonal matrix
      ctx%diagnostics%linear_solves = ctx%diagnostics%linear_solves + 1
      call reference_tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, &
           fsi_ws%residual, fsi_ws%delta_head, fsi_ws%tridag_gamma, ierror)

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
!        factor reduces the change of state%h (fsi_ws%delta_head) calculated as a full Newton Raphson step

!        update state%h
         if (at_min_dt .AND. state%numbit > MaxIt) then              
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
               state%h(i) = fsi_ws%old_head(i) - fsi_ws%delta_head(i) * factmax1
            end do
         else
            do i = 1, NN
               state%h(i) = fsi_ws%old_head(i) - factor * fsi_ws%delta_head(i)
            end do
         end if

!        update state%theta
         if (provider_constitutive_active) then
            call evaluation_context%constitutive%evaluate(state%h(1:numnod), fsi_ws%provider_theta, fsi_ws%provider_k, &
                 fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
            state%theta(1:NN) = fsi_ws%provider_theta(1:NN)
         else
            do i = 1, NN
               state%theta(i) = watcon(i,state%h(i))
            end do
         end if

!        update gradient in state%h
         do i = 2, NN
            fsi_ws%head_gradient(i) = (state%h(i-1)-state%h(i))/grid_disnod(i) + 1.0d0
         end do

!        special case: update state%k and state%kmean if SwKimpl = 1
         if (SwKimpl == 1) then
            call Rootextraction(2)
            do i = 1, NN
               state%k(i) = hconduc(i,state%h(i),state%theta(i),rfcp(i))
               if (swmacro == 1) state%k(i) = matrix_fraction(i) * state%k(i)
               if (i > 1) then
                  state%kmean(i) = hcomean(swkmean, state%k(i-1), state%k(i), grid_dz(i-1), grid_dz(i), i, state%h(i-1), state%h(i))
               end if
            end do
            state%kmean(NN+1) = state%k(NN)
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
            if (abs(state%h(i)-fsi_ws%old_head(i) ) > CritDevh2Cp) then
               fsi_ws%nonconverged_head(i) = .TRUE.
               flnonconv     = .TRUE.
            end if
         else
            if (abs(state%h(i)-fsi_ws%old_head(i) )/abs(fsi_ws%old_head(i)) > CritDevh1Cp) then
               fsi_ws%nonconverged_head(i) = .TRUE.
               flnonconv     = .TRUE.
            end if
         end if
    
      end do

!     test for waterbalance of ponding layer
      if (state%ftoph) then
         state%qtop = -state%kmean(1)*((state%hsurf - state%h(1))/grid_disnod(1) + 1.0d0)
         if (.NOT.flnonconv .AND. pond_balance_option_allows()) then
            deviat = state%pond - state%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + state%runots - state%qtop * dt
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
      end if

!     in case of macropores
      if (swmacro == 1) then
         if (IcTopMp == 1) then
            deviat = state%pond - state%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + state%runots - state%qtop * dt + macropore_surface_fraction() * (nraidt+nird+Melt)*dt + QMpLatSs
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
         if (fldecMPmbf) flnonconv = .TRUE.
      end if
      

!     implemented to improve iteration performance in case of macropores
      if (dt <  0.01d0 .AND. swmacro == 1 .AND. .NOT.flnonconv3) then 
         flok = .TRUE.
         if (dt > 10.d0*dtmin) then
            do i = 1, nodgwl
               if (state%h(i) > 0.0d0 .AND. fsi_ws%nonconverged_balance(i) .AND. fsi_ws%nonconverged_head(i)) flok = .FALSE.
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
               if (dt > state%dtold .OR. hist%nstep >= 10) then
                  state%dtold = dt
                  hist%nstep = 0
                  IDecMpRat = IDecMpRat - 1
               end if
            end if
         end if

!        special case swbotb = 1
         if (swbotb == 1 .AND. (.NOT.state%fllowgwl)) then
!           derive vertical flux profile in order to find state%qbot as a lower boundary condition for the saturated part of the soil system
            fsi_ws%vertical_flux(1) = state%qtop
            do i = NN+1, numnod
               state%theta(i) = cofgen(2,i)
            end do
            do i = 1, numnod
              fsi_ws%vertical_flux(i+1) = fsi_ws%vertical_flux(i) + grid_dz(i)*matrix_fraction(i)*(state%theta(i)-state%thetm1(i)) / dt + fsi_ws%sink(i) - fsi_ws%source(i) + root_sink_term(i)
            end do
            state%qbot = fsi_ws%vertical_flux(numnod+1)
!           state%h in saturated zone
            do i = NN+1, numnod
               state%h(i) = state%h(i-1) + grid_disnod(i)*(fsi_ws%vertical_flux(i)/state%kmean(i) + 1.0d0)
            end do
         end if
   
!        calculate new groundwater level
         !call calcgwl () replaced to call soilwater(3)

!        recording of number of iteration steps needed
         state%itnumb(min(100,state%numbit),1) = state%itnumb(min(100,state%numbit),1) + 1 
         state%itnumb(min(100,state%numbit),2) = state%itnumb(min(100,state%numbit),2) + iBackTr 

         ctx%control%last_numbit = state%numbit
         if (legacy_state_binding) call publish_legacy_state(state)
         return
      end if
   ! end do solver_numbit = 1, MaxIt1
   end do
   ! Preserve the legacy DO-variable value after normal loop exhaustion.
   state%numbit = solver_numbit

!  Convergence could not been reached
   if (.NOT.at_min_dt) then

!     reset soil state variables
      do j = 1, numnod
         state%h(j)     = state%hm1(j)
         state%theta(j) = state%thetm1(j)
      end do
      state%kmean(numnod+1) = state%k(numnod)
      state%gwl             = state%gwlm1
      state%pond            = state%pondm1

!     reset and continue iteration with smaller timestep!
      state%fldecdt = .TRUE.
      ctx%control%request_dt_reduction = .TRUE.
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1

      if (legacy_state_binding) call publish_legacy_state(state)

      return
   else if (macropore_exchange_retry_available()) then
!     in case of macropores, retry with reduction of exchange fluxes with matrix
      IDecMpRat  = IDecMpRat + 1
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1
      FlDecMpRat = .TRUE.
      state%dtold      = dt
      at_min_dt = .FALSE.
      if (legacy_state_binding) legacy_fldtmin = .FALSE.

      if (legacy_state_binding) call publish_legacy_state(state)

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
      if (legacy_state_binding) call publish_legacy_state(state)
      return
   end if

contains

logical function pond_balance_option_allows()
   if (swmacro == 0) then
      pond_balance_option_allows = .true.
   else
      pond_balance_option_allows = IcTopMp > 1
   end if
end function pond_balance_option_allows

logical function macropore_exchange_retry_available()
   if (swmacro /= 1) then
      macropore_exchange_retry_available = .false.
   else
      macropore_exchange_retry_available = IDecMpRat < 3
   end if
end function macropore_exchange_retry_available

real(8) function matrix_fraction(node)
   integer, intent(in) :: node
   if (legacy_state_binding .or. swmacro == 1) then
      matrix_fraction = legacy_frarmtrx(node)
   else
      matrix_fraction = 1.0d0
   end if
end function matrix_fraction

real(8) function macropore_surface_fraction()
   if (legacy_state_binding .or. swmacro == 1) then
      macropore_surface_fraction = legacy_armpss
   else
      macropore_surface_fraction = 0.0d0
   end if
end function macropore_surface_fraction

real(8) function grid_z(node)
   integer, intent(in) :: node
   if (explicit_geometry) then
      grid_z = parameter_set%z(node)
   else
      grid_z = legacy_z(node)
   end if
end function grid_z

real(8) function grid_dz(node)
   integer, intent(in) :: node
   if (explicit_geometry) then
      grid_dz = parameter_set%dz(node)
   else
      grid_dz = legacy_dz(node)
   end if
end function grid_dz

real(8) function grid_disnod(node)
   integer, intent(in) :: node
   if (explicit_geometry) then
      if (node == numnod+1) then
         ! Exact B1.10 swap_base geometry: lower face is half the last compartment thickness.
         grid_disnod = 0.5d0*parameter_set%dz(numnod)
      else
         grid_disnod = parameter_set%node_distance(node)
      end if
   else
      grid_disnod = legacy_disnod(node)
   end if
end function grid_disnod


real(8) function root_sink_term(node)
   integer, intent(in) :: node
   if (provider_source_sink_active) then
      if (provider_root_sink_active) then
         root_sink_term = fsi_ws%provider_root_sink(node)
      else
         root_sink_term = 0.0d0
      end if
   else
      root_sink_term = qrot(node)
   end if
end function root_sink_term

subroutine capture_legacy_state(s)
   type(reference_richards_state_binding_t), intent(inout) :: s
   s%active_nodes = numnod
   s%h = h(1:numnod)
   s%theta = theta(1:numnod)
   s%hm1 = hm1(1:numnod)
   s%thetm1 = thetm1(1:numnod)
   s%k = k(1:numnod)
   s%kmean = kmean(1:numnod+1)
   s%dimoca = dimoca(1:numnod)
   s%pond = pond
   s%pondm1 = pondm1
   s%gwl = gwl
   s%gwlm1 = gwlm1
   s%gwlinp = gwlinp
   s%dtold = dtold
   s%qtop = qtop
   s%qbot = qbot
   s%hbot = hbot
   s%itnumb = itnumb
   s%numbit = numbit
   s%fllowgwl = fllowgwl
   s%fldecdt = fldecdt
   s%q0 = q0
   s%hsurf = hsurf
   s%runots = runots
   s%flrunoff = flrunoff
   s%ftoph = ftoph
end subroutine capture_legacy_state

subroutine publish_legacy_state(s)
   type(reference_richards_state_binding_t), intent(in) :: s
   h(1:numnod) = s%h
   theta(1:numnod) = s%theta
   hm1(1:numnod) = s%hm1
   thetm1(1:numnod) = s%thetm1
   k(1:numnod) = s%k
   kmean(1:numnod+1) = s%kmean
   dimoca(1:numnod) = s%dimoca
   pond = s%pond
   pondm1 = s%pondm1
   gwl = s%gwl
   gwlm1 = s%gwlm1
   gwlinp = s%gwlinp
   dtold = s%dtold
   qtop = s%qtop
   qbot = s%qbot
   hbot = s%hbot
   itnumb = s%itnumb
   numbit = s%numbit
   fllowgwl = s%fllowgwl
   fldecdt = s%fldecdt
   q0 = s%q0
   hsurf = s%hsurf
   runots = s%runots
   flrunoff = s%flrunoff
   ftoph = s%ftoph
end subroutine publish_legacy_state

subroutine boundtop_state_bridge(task)
   integer, intent(in) :: task
   type(reference_richards_state_binding_t) :: saved
   real(8) :: provider_runoff_flux
   provider_runoff_resolved = .false.
   if (provider_top_active) then
      call evaluation_context%top_boundary%evaluate(state%h(1), state%theta(1), boundary_conditions, &
           state%qtop, state%hsurf, provider_runoff_flux)
      state%ftoph = .false.
      state%runots = provider_runoff_flux * dt
      state%flrunoff = abs(provider_runoff_flux) > 0.0d0
      provider_runoff_resolved = .true.
      return
   end if
   if (legacy_state_binding) then
      call publish_legacy_state(state)
      call boundtop(task)
      call capture_legacy_state(state)
   else
      call capture_legacy_state(saved)
      call publish_legacy_state(state)
      call boundtop(task)
      call capture_legacy_state(state)
      call publish_legacy_state(saved)
   end if
end subroutine boundtop_state_bridge

subroutine pondrunoff_state_bridge()
   type(reference_richards_state_binding_t) :: saved
   if (legacy_state_binding) then
      call publish_legacy_state(state)
      call pondrunoff()
      call capture_legacy_state(state)
   else
      call capture_legacy_state(saved)
      call publish_legacy_state(state)
      call pondrunoff()
      call capture_legacy_state(state)
      call publish_legacy_state(saved)
   end if
end subroutine pondrunoff_state_bridge

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

   do i = 1, NN
      fsi_ws%band_matrix(i,1) = fsi_ws%dfdh_upper(i)
      fsi_ws%band_matrix(i,2) = fsi_ws%dfdh_main(i)
      fsi_ws%band_matrix(i,3) = fsi_ws%dfdh_lower(i)
   end do
   fsi_ws%band_rhs(1:NN) = fsi_ws%residual(1:NN)
   call reference_band_solve(fsi_ws%band_matrix, fsi_ws%band_aux, fsi_ws%band_pivots(1:NN), &
        fsi_ws%band_rhs(1:NN))
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
   fsi_ws%residual(1) = (state%theta(1) - state%thetm1(1)) * matrix_fraction(1) * grid_dz(1) / dt + fsi_ws%sink(1) - fsi_ws%source(1) + root_sink_term(1) + state%kmean(2) * fsi_ws%head_gradient(2)

!  depending on iTask
   if (iTask == 2 .AND. swmacro == 1) QMpLatSsSav = QMpLatSs

!  take care of top BC
   call boundtop_state_bridge(2)

!  depending on iTask
   if (swmacro == 1) then
      if (iTask == 1 .OR. .NOT. fsi_ws%unsaturated_flags(3)) then 
         call MACROPORE(2)
      else
         QMpLatSs = QMpLatSsSav
      end if
   end if

!  take care of top BC: ponding, runoff
   if (.NOT. provider_runoff_resolved) then
      if (state%flrunoff .OR. macropore_surface_fraction() > 0.0d0) call pondrunoff_state_bridge()
   end if

!  first layer, continued
   if (state%ftoph) then
      fsi_ws%head_gradient(1) = (state%hsurf-state%h(1))/grid_disnod(1) + 1.d0
      fsi_ws%residual(1)     = fsi_ws%residual(1) - state%kmean(1) * fsi_ws%head_gradient(1)
   else
      fsi_ws%residual(1) = fsi_ws%residual(1) + state%qtop
   end if

!  layers 2 to (NN-1)
   do i = 2, NN-1
      fsi_ws%residual(i) = (state%theta(i) - state%thetm1(i)) * matrix_fraction(i) * grid_dz(i) / dt + fsi_ws%sink(i) - fsi_ws%source(i) + root_sink_term(i) - state%kmean(i) * fsi_ws%head_gradient(i) + state%kmean(i+1) * fsi_ws%head_gradient(i+1)
   end do

!  for bottom BC
   if (swbotb == 1 .AND. (.NOT.state%fllowgwl)) then
      fsi_ws%head_gradient(NN+1) = state%h(NN)/(grid_z(nn)-state%gwlinp) + 1.0d0
   else if (swbotb == 5 .OR. (swbotb == 1 .AND. state%fllowgwl)) then
      fsi_ws%head_gradient(NN+1) = (state%h(NN) - state%hbot) / grid_disnod(NN+1) + 1.0d0
   else if (swbotb == 9) then
      fsi_ws%head_gradient(NN+1) = (state%h(NN) - state%h(NN+1)) / grid_disnod(NN+1) + 1.0d0
   end if

!  for swbotb = 8, depending on iTask
   if (iTask == 1) then
      if (swbotb == 8) then
         if (state%h(NN) > Critdz - grid_disnod(NN+1) + hplate) then
            fsi_ws%head_gradient(NN+1) = (state%h(NN) - hplate) / grid_disnod(NN+1) + 1.0d0
            flboth = .TRUE.
         else
            flboth = .FALSE.
         end if
      else
         flboth = .FALSE.
      end if
   else
      if (swbotb == 8 .AND. flboth) then
         fsi_ws%head_gradient(NN+1) = (state%h(NN) - hplate) / grid_disnod(NN+1) + 1.0d0
      end if
   end if

   ! for bottom BC, continued
   if (swbotb == 1 .AND. (.NOT.state%fllowgwl)) then
      state%theta(NN) = watcon(NN,state%h(NN))
      state%k(NN)     = hconduc(NN,state%h(NN),state%theta(NN),rfcp(NN))
      ! in case of static macropores FrArMtrx < 1
      if (swmacro == 1) state%k(NN) = matrix_fraction(NN) * state%k(NN)
      state%kmean(NN+1) = hcomean(swkmean, state%k(NN), cofgen(3,(NN+1)), grid_dz(NN), grid_dz(NN+1), NN, state%h(NN), 0.0d0)
      fsi_ws%residual(NN)       = (state%theta(NN) - state%thetm1(NN))*matrix_fraction(NN)*grid_dz(NN)/dt - state%kmean(NN) * fsi_ws%head_gradient(NN) + state%kmean(NN+1) * fsi_ws%head_gradient(NN+1) + fsi_ws%sink(NN) - fsi_ws%source(NN) + root_sink_term(NN)
   else
      fsi_ws%residual(NN) = (state%theta(NN) - state%thetm1(NN))*matrix_fraction(NN)*grid_dz(NN)/dt - state%kmean(NN) * fsi_ws%head_gradient(NN) + fsi_ws%sink(NN) - fsi_ws%source(NN) + root_sink_term(NN) 
      if (swbotb == 3 .AND. swbotb3Impl == 1) then
         
         ! Cauchy-relation, implemented as head boundary
         if (SwBotb3ResVert == 0) then
            state%qbot = - (state%h(NN)+grid_z(NN)-deepgw) / (grid_disnod(NN+1)/state%kmean(NN+1)+rimlay)
         else if (SwBotb3ResVert == 1) then
            state%qbot = - (state%h(NN)+grid_z(NN)-deepgw) / rimlay
         end if
         
         ! extra groundwater flux might be added
         if (sw4 == 1) state%qbot = state%qbot + afgen(qbotab,mabbc*2,t1900+dt)
         fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot     
      
      else if (swbotb == 5 .OR. (swbotb == 1 .AND. state%fllowgwl)) then
         
         ! pressure head at lower boundary specified
         fsi_ws%residual(NN) = fsi_ws%residual(NN) + state%kmean(NN+1) * fsi_ws%head_gradient(NN+1)

      else if (swbotb == 9) then
         
         ! pressure head at lower boundary specified
         fsi_ws%residual(NN) = fsi_ws%residual(NN) + state%kmean(NN+1) * fsi_ws%head_gradient(NN+1)
         !!!fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot
      
      else if (swbotb == 7 .OR. swbotb == -2) then 
         
         ! free drainage option
         if (provider_constitutive_active) then
            state%kmean(numnod+1) = fsi_ws%provider_k(numnod)
         else
            state%kmean(numnod+1) = hconduc(numnod,state%h(numnod),state%theta(numnod),rfcp(numnod))
         end if
         if (swmacro == 1) state%kmean(numnod+1) = matrix_fraction(numnod) * state%kmean(numnod+1)
         state%qbot = -1.0d0 * state%kmean(numnod+1)
         fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot
      
      else if (swbotb == 8) then                                  
         
         ! lysimeter option
         if (flboth) then
            state%hbot = hplate
            fsi_ws%residual(NN) = fsi_ws%residual(NN) + state%kmean(NN+1) * fsi_ws%head_gradient(NN+1)
         else
            state%qbot = 0.0d0
         end if
      
      else
         
          ! flux bottom boundary
         fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot
      
      end if

   end if

   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F

subroutine jacobian_F()

!  first layer
   fsi_ws%dfdh_main(1) = state%dimoca(1)*matrix_fraction(1)*grid_dz(1)/dt - fsi_ws%dfdh_lower(1)
 
!  if the head boundary condition applies: add the k1/(0.5*dz1) term to the first element of the main diagonal 
   if (state%ftoph) fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + state%kmean(1)/grid_disnod(1)  

!  layers 2 to (NN-1)
   do i = 2, NN-1
      fsi_ws%dfdh_main(i) = state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt - fsi_ws%dfdh_upper(i) - fsi_ws%dfdh_lower(i) 
   end do

!  last layer: handle bottom BC
   fsi_ws%dfdh_main(NN) = state%dimoca(NN)*matrix_fraction(NN)*grid_dz(NN)/dt - fsi_ws%dfdh_upper(NN) 
   if (swbotb == 1 .AND. (.NOT.state%fllowgwl)) then
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + state%kmean(NN+1)/(grid_z(NN)-state%gwlinp) 
   else if (swbotb == 3 .AND. swbotb3Impl == 1) then ! Cauchy
      if (SwBotb3ResVert == 0) then
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 1.0d0 / (grid_disnod(NN+1)/state%kmean(NN+1) + rimlay)   
      else if (SwBotb3ResVert == 1) then
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 1.0d0 / rimlay
      end if
   else if (swbotb == 5 .OR. (swbotb == 1 .AND. state%fllowgwl) .OR. swbotb == 9) then
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + state%kmean(NN+1)/grid_disnod(NN+1)         
   else if (swbotb == 7 .OR. swbotb == -2) then ! implicitly: state%kmean(NN+1)
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + fsi_ws%dconductivity_dhead(NN) * 0.5d0
   else if (swbotb == 8 .AND. flboth) then
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + state%kmean(NN+1)/grid_disnod(NN+1)
   end if

!  special case when SwKimpl = 1
   if (SwKimpl == 1) then
      if (swbotb == 9) call swap_error ('headcalc', 'swbotb = 9 AND swkimpl = 1 not yet implemented')
!     first layer
      fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(2) * dkmean(swkmean,state%k(1),state%k(2),grid_dz(1),grid_dz(2))
      if (state%ftoph) fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) - fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(1) * 0.5d0
      fsi_ws%dfdh_lower(1) = fsi_ws%dfdh_lower(1) + fsi_ws%dconductivity_dhead(2) * fsi_ws%head_gradient(2) * dkmean(swkmean,state%k(2),state%k(1),grid_dz(2),grid_dz(1)) 
!     layers 2 to (NN-1)
      do i = 2, NN-1
         fsi_ws%dfdh_upper(i) = fsi_ws%dfdh_upper(i) - fsi_ws%dconductivity_dhead(i-1) * fsi_ws%head_gradient(i) * dkmean(swkmean,state%k(i-1),state%k(i),grid_dz(i-1),grid_dz(i)) 
         fsi_ws%dfdh_main(i) = fsi_ws%dfdh_main(i) - fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i) * dkmean(swkmean,state%k(i),state%k(i-1),grid_dz(i),grid_dz(i-1)) + fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i+1) * dkmean(swkmean,state%k(i),state%k(i+1),grid_dz(i),grid_dz(i+1))
         fsi_ws%dfdh_lower(i) = fsi_ws%dfdh_lower(i) + fsi_ws%dconductivity_dhead(i+1) * fsi_ws%head_gradient(i+1) * dkmean(swkmean,state%k(i+1),state%k(i),grid_dz(i+1),grid_dz(i)) 
      end do
!     last layer
      fsi_ws%dfdh_upper(NN) = fsi_ws%dfdh_upper(NN) - fsi_ws%dconductivity_dhead(NN-1) * fsi_ws%head_gradient(NN) * dkmean(swkmean,state%k(NN-1),state%k(NN),grid_dz(NN-1),grid_dz(NN)) 
      fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) - fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN) * dkmean(swkmean,state%k(NN),state%k(NN-1),grid_dz(NN),grid_dz(NN-1))

      if (swbotb == 1 .OR. swbotb == 5 .OR. swbotb == 8 .AND. flboth) then
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0 * fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN+1)
      end if
   end if

!  special case macropore
   if (swmacro == 1 .AND. .NOT.fsi_ws%unsaturated_flags(3)) then
      call MACROPORE(3)
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
