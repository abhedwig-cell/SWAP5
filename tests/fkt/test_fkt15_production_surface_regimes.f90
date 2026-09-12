program test_fkt15_production_surface_regimes
  use, intrinsic :: iso_fortran_env, only: int64, real64, error_unit
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use mod_b110_production_soil_water_task2, only: try_b110_production_task2
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_b110_dynamic_top_boundary_provider, only: B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_MvG, only: cofgen
  use MOD_meteo, only: nraidt, epond, peva, empreva
  use MOD_irrigation, only: nird, qssdi
  use MOD_snow, only: melt
  use MOD_drain, only: qdra
  use MOD_frost, only: rfcp
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, qtop, qbot, hbot, &
       runon, epd, reva, runots, qrot, dt, swbotb, maxit, fldecdt, pondmx, rsro, rsroexp, &
       kmean, numbit, itnumb
  implicit none

  real(real64), parameter :: hard_gate = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  real(real64) :: k_flux, k_atm, k_sat, ponded_head, runoff_head

  call configure_hydraulic_family()
  geometry%parameter_set_id = 150015_int64
  geometry%active_nodes = numnod
  allocate(geometry%z(numnod), geometry%dz(numnod), geometry%node_distance(numnod))
  geometry%z = z
  geometry%dz = dz
  geometry%node_distance = disnod(1:numnod)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen(:,1:numnod))
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)

  k_flux = node_conductivity(-75.0_real64)
  k_atm = node_conductivity(B110_DYN_TOP_ATMOSPHERIC_HEAD_CM)
  k_sat = node_conductivity(1.0_real64)
  call require(k_flux > 0.0_real64 .and. k_atm > 0.0_real64 .and. k_sat > 0.0_real64, &
       'positive conductivities')

  call run_surface_case('flux', -75.0_real64, 0.0_real64, &
       k_flux, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, 'surface-flux', .true.)

  call run_surface_case('atmospheric', B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, 0.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, 'atmospheric-head', .false.)

  ponded_head = 2.0_real64 - k_sat*dt
  call require(ponded_head > 0.0_real64, 'ponded-head start positive')
  call run_surface_case('ponded', ponded_head, 2.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 10.0_real64, 0.5_real64, 1.0_real64, 'ponded-head', .false.)

  runoff_head = (3.0_real64 - k_sat*dt + (dt/0.5_real64)*0.1_real64) / &
       (1.0_real64 + dt/0.5_real64)
  call require(runoff_head > 0.1_real64, 'runoff start exceeds threshold')
  call run_surface_case('linear-runoff', runoff_head, 3.0_real64, &
       0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
       0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, 'ponded-head-linear-runoff', .false.)

  write(*,'(A)') 'FKT15_PRODUCTION_SURFACE_FLUX=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_PONDED_HEAD=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_LINEAR_RUNOFF=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_SURFACE_METADATA_IDENTITY=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_FLUX_ONLY_TANGENT_SCOPE=PASS'
  write(*,'(A)') 'FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS'

contains

  subroutine configure_hydraulic_family()
    integer :: k
    cofgen = 0.0_real64
    do k = 1, numnod+1
      cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
      cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
      cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k); cofgen(9,k)=0.0_real64
      cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64; cofgen(12,k)=0.99_real64*cofgen(3,k)
      cofgen(13,k)=0.10_real64; cofgen(14,k)=1.50_real64; cofgen(15,k)=0.50_real64
      cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
    end do
  end subroutine configure_hydraulic_family

  real(real64) function node_conductivity(head_value) result(value)
    real(real64), intent(in) :: head_value
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    heads = head_value
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    value = conductivity(1)
  end function node_conductivity

  subroutine run_surface_case(label, head_value, pond_previous, precip, irrigation, snowmelt, runon_rate, &
       bare_evap, pond_evap, pondmax, runoff_resistance, exponent, expected_route, expect_sensitivity)
    character(len=*), intent(in) :: label, expected_route
    real(real64), intent(in) :: head_value, pond_previous, precip, irrigation, snowmelt, runon_rate
    real(real64), intent(in) :: bare_evap, pond_evap, pondmax, runoff_resistance, exponent
    logical, intent(in) :: expect_sensitivity
    type(a23bu_worker_context_t) :: worker
    type(b110_dynamic_top_boundary_solver_provider_t), target :: provider
    type(soil_water_boundary_conditions_t) :: boundary
    type(soil_water_top_boundary_result_t) :: initial_surface, final_surface
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: initial_storage, final_storage, total_mass
    logical :: handled

    heads = head_value
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call seed_globals(heads, water, pond_previous, precip, irrigation, snowmelt, runon_rate, &
         bare_evap, pond_evap, pondmax, runoff_resistance, exponent)

    call bind_b110_dynamic_top_boundary_solver_provider(provider, geometry, hydraulic_parameters, &
         1, pond_previous, dt, precip, irrigation, snowmelt, runon_rate, bare_evap, pond_evap, &
         pondmax, runoff_resistance, exponent)
    boundary = soil_water_boundary_conditions_t()
    call provider%evaluate(h(1), theta(1), pond, boundary, initial_surface)
    call require(initial_surface%status == SW_TOP_BOUNDARY_AVAILABLE, label//' initial provider available')
    call require(trim(initial_surface%route) == expected_route, label//' initial route')

    qtop = initial_surface%actual_top_flux
    qbot = initial_surface%actual_top_flux
    initial_storage = sum(theta*dz) + pond

    ! Poison accepted-only output metadata. The production adapter must replace it
    ! from the accepted F-SI29 result, not inherit stale legacy values.
    reva = 901.0_real64
    epd = 902.0_real64
    runots = 903.0_real64
    q0 = 904.0_real64
    hsurf = 905.0_real64
    ftoph = .not. (initial_surface%regime == SW_TOP_BOUNDARY_REGIME_HEAD)
    flrunoff = .not. initial_surface%runoff_potential

    call a23bu_initialize_worker(worker, numnod, 150)
    call try_b110_production_task2(worker, handled)
    call require(handled, label//' production adapter handled')
    call require(worker%soil_water_trial%typed_attempted, label//' typed attempted')
    call require(worker%soil_water_trial%typed_accepted, label//' typed accepted')
    call require(.not. worker%soil_water_trial%retry_advised, label//' no retry')
    call require(worker%diagnostics%headcalc_calls == 1, label//' single hydraulic authority')

    call provider%evaluate(h(1), theta(1), pond, boundary, final_surface)
    call require(final_surface%status == SW_TOP_BOUNDARY_AVAILABLE, label//' final provider available')
    call require(trim(final_surface%route) == expected_route, label//' final route')
    call require_close(qtop, final_surface%actual_top_flux, hard_gate, label//' qtop identity')
    call require_close(pond, final_surface%candidate_ponding_depth, hard_gate, label//' pond identity')
    call require_close(reva, final_surface%bare_soil_evaporation, hard_gate, label//' reva identity')
    call require_close(epd, final_surface%ponded_water_evaporation, hard_gate, label//' epd identity')
    call require_close(runots, final_surface%runoff_depth, hard_gate, label//' runoff identity')
    call require_close(q0, final_surface%net_potential_surface_flux, hard_gate, label//' q0 identity')
    call require_close(hsurf, final_surface%surface_head, hard_gate, label//' hsurf identity')
    call require(ftoph .eqv. (final_surface%regime == SW_TOP_BOUNDARY_REGIME_HEAD), label//' ftoph identity')
    call require(flrunoff .eqv. (final_surface%runoff_potential .or. abs(final_surface%runoff_depth) > 0.0_real64), &
         label//' flrunoff identity')
    if (ftoph) call require_close(kmean(1), final_surface%surface_face_conductivity, hard_gate, label//' top K identity')

    final_storage = sum(theta*dz) + pond
    total_mass = final_storage - initial_storage - final_surface%net_potential_surface_flux*dt + &
         final_surface%runoff_depth - qbot*dt
    call require(abs(total_mass) <= hard_gate, label//' hard total mass closure')
    call require(.not. fldecdt, label//' no dt reduction')

    if (expect_sensitivity) then
      call require(worker%soil_water_trial%sensitivity_available, label//' tangent available')
      call require(trim(worker%soil_water_trial%sensitivity_method) == 'same-tridag-factor', label//' tangent method')
      call require(worker%soil_water_trial%interface_sensitivity_backsolves == 1, label//' one tangent backsolve')
    else
      call require(.not. worker%soil_water_trial%sensitivity_available, label//' tangent unavailable')
      call require(worker%soil_water_trial%interface_sensitivity_backsolves == 0, label//' zero tangent cost')
    end if
  end subroutine run_surface_case

  subroutine seed_globals(heads, water, pond_previous, precip, irrigation, snowmelt, runon_rate, &
       bare_evap, pond_evap, pondmax, runoff_resistance, exponent)
    real(real64), intent(in) :: heads(:), water(:), pond_previous, precip, irrigation, snowmelt, runon_rate
    real(real64), intent(in) :: bare_evap, pond_evap, pondmax, runoff_resistance, exponent
    h = heads
    theta = water
    hm1 = h
    thetm1 = theta
    pond = pond_previous
    pondm1 = pond_previous
    gwl = -2.0_real64
    gwlm1 = gwl
    hbot = -100.0_real64
    nraidt = precip
    nird = irrigation
    melt = snowmelt
    runon = runon_rate
    peva = bare_evap
    empreva = bare_evap
    epond = pond_evap
    qrot = 0.0_real64
    qdra = 0.0_real64
    qssdi = 0.0_real64
    rfcp = 1.0_real64
    pondmx = pondmax
    rsro = runoff_resistance
    rsroexp = exponent
    swbotb = 2
    maxit = 12
    fldecdt = .false.
    numbit = 0
    itnumb = 0
    kmean = 1.0_real64
  end subroutine seed_globals

  subroutine require_close(actual, expected, tolerance, label)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    real(real64) :: scale
    scale = max(1.0_real64, abs(actual), abs(expected))
    call require(abs(actual-expected) <= tolerance*scale, label)
  end subroutine require_close

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(error_unit,'(A,1X,A)') 'FKT15_SURFACE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt15_production_surface_regimes
