program test_fpm06e_restricted_surface_evaporation_capacity
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, &
       evaluate_b110_default_mvg_conductivity
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_result_t, &
       SURFACE_EVAP_CAPACITY_AVAILABLE, SURFACE_EVAP_CAPACITY_INVALID_INPUT, &
       SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  use mod_b110_surface_evaporation_capacity_provider, only: b110_surface_evaporation_capacity_provider_t, &
       bind_b110_surface_evaporation_capacity_provider, B110_SURFACE_ATMOSPHERIC_HEAD_CM
  implicit none

  integer, parameter :: n = 2
  real(real64), parameter :: heads(5) = [0.0_real64, -0.1_real64, -100.0_real64, &
       -10000.0_real64, -300000.0_real64]
  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: hydraulics
  type(b110_default_mvg_provider_t) :: full_provider
  type(b110_surface_evaporation_capacity_provider_t) :: capacity_provider
  type(soil_water_physical_state_t) :: state
  type(surface_evaporation_capacity_result_t) :: result, dry_result
  real(real64) :: cofgen(24,n), all_heads(n), water(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: scalar_k, k_atm, k_top, k_face, expected, fingerprint, saved_head, saved_pond
  real(real64) :: nan_value
  logical :: ok
  integer :: i, method

  call configure_fixture(geometry, hydraulics, cofgen)
  call bind_b110_default_mvg_provider(full_provider, hydraulics, 0.25_real64)

  ! The new scalar constitutive entry point must preserve the existing B1.10 conductivity bit pattern.
  do i = 1, size(heads)
    all_heads = heads(i)
    call full_provider%evaluate(all_heads, water, conductivity, capacity, dkdh)
    call evaluate_b110_default_mvg_conductivity(hydraulics, 1, heads(i), scalar_k, ok)
    call require(ok, 'scalar conductivity available')
    call require(transfer(scalar_k,0_int64) == transfer(conductivity(1),0_int64), &
         'scalar conductivity exact identity with established provider')
  end do

  state%active_nodes = n
  allocate(state%pressure_head(n), state%water_content(n))
  state%pressure_head = -100.0_real64
  state%water_content = 0.2_real64
  state%ponding_depth = 0.0_real64
  state%groundwater_level = -200.0_real64

  fingerprint = 0.0_real64
  call evaluate_b110_default_mvg_conductivity(hydraulics, 1, B110_SURFACE_ATMOSPHERIC_HEAD_CM, k_atm, ok)
  call require(ok, 'atmospheric conductivity available')

  ! Source-bound HCOMEAN policies 1 through 6 and the signed B1.10 Emax equation.
  do method = 1, 6
    call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
         method, .false., .false., ok)
    call require(ok, 'capacity provider binds')
    do i = 1, size(heads)
      state%pressure_head(1) = heads(i)
      saved_head = state%pressure_head(1)
      saved_pond = state%ponding_depth
      call capacity_provider%evaluate(state, result)
      call require(result%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 'qualified capacity route available')
      call evaluate_b110_default_mvg_conductivity(hydraulics, 1, heads(i), k_top, ok)
      call require(ok, 'top conductivity available')
      k_face = legacy_hcomean_1_to_6(method, k_atm, k_top, geometry%dz(1), geometry%dz(1))
      expected = -k_face*((B110_SURFACE_ATMOSPHERIC_HEAD_CM-heads(i))/geometry%node_distance(1) + 1.0_real64)
      call require(fp_equal(result%evaporation_capacity, expected), 'B1.10 Emax source equation identity')
      call require(state%pressure_head(1) == saved_head .and. state%ponding_depth == saved_pond, &
           'capacity evaluation does not mutate physical state')
      fingerprint = fingerprint + result%evaporation_capacity*real(10*method+i,real64)
    end do
  end do

  ! Negative Emax is physically meaningful at a head below the atmospheric limiting head and must remain signed.
  call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
       1, .false., .false., ok)
  state%pressure_head(1) = -300000.0_real64
  state%ponding_depth = 0.0_real64
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 'negative-capacity case available')
  call require(result%evaporation_capacity < 0.0_real64, 'negative Emax is not clamped')

  ! Ponding classification belongs to the downstream structural process, not to this hydraulic capability.
  state%pressure_head(1) = -100.0_real64
  state%ponding_depth = 0.0_real64
  call capacity_provider%evaluate(state, dry_result)
  state%ponding_depth = 0.5_real64
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 'finite ponded base state accepted')
  call require(transfer(result%evaporation_capacity,0_int64) == &
       transfer(dry_result%evaporation_capacity,0_int64), 'Emax independent of ponding classification')

  ! Szymkiewicz mean policy 7 is deliberately fail-closed until its own clean hydraulic capability exists.
  call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
       7, .false., .false., ok)
  call require(ok, 'policy 7 configuration binds for diagnostic rejection')
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 'policy 7 rejected')

  call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
       0, .false., .false., ok)
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 'unknown mean rejected')

  call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
       1, .true., .false., ok)
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 'frost rejected')

  call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
       1, .false., .true., ok)
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 'macropore rejected')

  call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
       1, .false., .false., ok)
  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  state%ponding_depth = nan_value
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 'nonfinite ponding rejected')
  state%ponding_depth = 0.0_real64
  state%pressure_head(1) = nan_value
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 'nonfinite top head rejected')
  state%pressure_head(1) = -100.0_real64

  geometry%node_distance(1) = 0.0_real64
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 'zero top distance rejected')
  geometry%node_distance(1) = 2.5_real64

  deallocate(state%pressure_head)
  call capacity_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 'missing pressure head rejected')

  write(*,'(A,Z16.16)') 'FPM06E_FINGERPRINT=', transfer(fingerprint,0_int64)
  write(*,'(A)') 'FPM06E_RESTRICTED_SURFACE_EVAPORATION_CAPACITY PASS'

contains

  subroutine configure_fixture(p, hp, c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    real(real64), intent(out) :: c(24,n)
    integer :: k

    p%parameter_set_id = 6006_int64
    p%active_nodes = n
    allocate(p%z(n), p%dz(n), p%node_distance(n))
    p%z = [-2.5_real64, -10.0_real64]
    p%dz = [5.0_real64, 10.0_real64]
    p%node_distance = [2.5_real64, 7.5_real64]

    c = 0.0_real64
    do k = 1, n
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp, c)
  end subroutine configure_fixture

  pure real(real64) function legacy_hcomean_1_to_6(method, kup, klow, dzup, dzlow) result(kmean)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow
    real(real64) :: a1, a2
    a1 = dzup/(dzup+dzlow)
    a2 = 1.0_real64-a1
    select case(method)
    case(1)
      kmean = 0.5_real64*(kup+klow)
    case(2)
      kmean = (dzup*kup+dzlow*klow)/(dzup+dzlow)
    case(3)
      kmean = sqrt(kup*klow)
    case(4)
      kmean = kup**a1 * klow**a2
    case(5)
      kmean = 1.0_real64/(0.5_real64/kup+0.5_real64/klow)
    case(6)
      kmean = 1.0_real64/(a1/kup+a2/klow)
    case default
      kmean = -huge(1.0_real64)
    end select
  end function legacy_hcomean_1_to_6

  pure logical function fp_equal(a,b) result(equal)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale = max(abs(a),abs(b),tiny(1.0_real64))
    equal = abs(a-b) <= 256.0_real64*epsilon(1.0_real64)*scale
  end function fp_equal

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FPM06E_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm06e_restricted_surface_evaporation_capacity
