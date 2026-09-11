program test_fsi30_adapter_identity
  use, intrinsic :: iso_fortran_env, only: real64, error_unit
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX, B110_DYN_TOP_REGIME_HEAD
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  integer, parameter :: nnode = 2
  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: hydraulics
  type(b110_dynamic_top_boundary_solver_provider_t) :: provider
  type(b110_dynamic_top_boundary_solver_provider_t) :: replay_provider(8)
  type(b110_dynamic_top_boundary_request_t) :: req, req_before, replay_req(8)
  type(b110_dynamic_top_boundary_result_t) :: direct
  type(soil_water_top_boundary_result_t) :: adapted, replay_ref(8), replay_got
  type(soil_water_boundary_conditions_t) :: requested
  real(real64) :: raw(24,nnode)
  real(real64), parameter :: hcases(4) = [-1000.0_real64, -100.0_real64, -10.0_real64, -1.0_real64]
  real(real64), parameter :: prevpond(3) = [0.0_real64, 1.0e-8_real64, 0.02_real64]
  real(real64), parameter :: candpond(3) = [0.0_real64, 0.005_real64, 0.05_real64]
  real(real64), parameter :: pondmx_cases(2) = [0.01_real64, 2.0_real64]
  integer :: method, ih, iprev, icand, ipondmx, ievap, isupply, cases, i

  call configure_family(raw, geometry)
  call initialize_b110_default_mvg_parameters(hydraulics, raw)
  requested = soil_water_boundary_conditions_t()
  cases = 0

  do method = 1, 6
    do ih = 1, size(hcases)
      do iprev = 1, size(prevpond)
        do icand = 1, size(candpond)
          do ipondmx = 1, size(pondmx_cases)
            do ievap = 1, 3
              do isupply = 1, 7
                call initialize_request(req, method)
                req%pressure_head_top_cm = hcases(ih)
                req%previous_ponding_depth_cm = prevpond(iprev)
                req%candidate_ponding_depth_cm = candpond(icand)
                req%ponding_max_cm = pondmx_cases(ipondmx)
                call set_evaporation_case(req, ievap)
                call set_supply_case(req, isupply)
                req_before = req

                call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, direct)
                call require(direct%status == B110_DYN_TOP_AVAILABLE, 30001)
                call bind_from_request(provider, req)
                call provider%evaluate(req%pressure_head_top_cm, req%water_content_top, &
                     req%candidate_ponding_depth_cm, requested, adapted)
                call require(same_request(req, req_before), 30002)
                call compare_adapter(direct, adapted, 30010)
                cases = cases + 1
              end do
            end do
          end do
        end do
      end do
    end do
  end do

  call require(cases == 9072, 30003)

  ! Eight independent provider contexts are bound once, then replayed in reverse order.
  ! This is the MultiSWAP-style isolation check: no call may mutate shared geometry,
  ! hydraulics, request data or another provider instance.
  do i = 1, 8
    call initialize_request(replay_req(i), 1 + mod(i-1,6))
    replay_req(i)%pressure_head_top_cm = hcases(1 + mod(i-1,size(hcases)))
    replay_req(i)%previous_ponding_depth_cm = prevpond(1 + mod(i-1,size(prevpond)))
    replay_req(i)%candidate_ponding_depth_cm = candpond(1 + mod(2*i-1,size(candpond)))
    replay_req(i)%ponding_max_cm = pondmx_cases(1 + mod(i-1,size(pondmx_cases)))
    call set_evaporation_case(replay_req(i), 1 + mod(i-1,3))
    call set_supply_case(replay_req(i), 1 + mod(i-1,7))
    call bind_from_request(replay_provider(i), replay_req(i))
    call replay_provider(i)%evaluate(replay_req(i)%pressure_head_top_cm, replay_req(i)%water_content_top, &
         replay_req(i)%candidate_ponding_depth_cm, requested, replay_ref(i))
  end do
  do i = 8, 1, -1
    call replay_provider(i)%evaluate(replay_req(i)%pressure_head_top_cm, replay_req(i)%water_content_top, &
         replay_req(i)%candidate_ponding_depth_cm, requested, replay_got)
    call require(same_generic_result(replay_got, replay_ref(i)), 30004)
  end do

  write(*,'(A,I0)') 'FSI30_ADAPTER_IDENTITY_CASES=', cases
  write(*,'(A)') 'FSI30_ADAPTER_DIRECT_FSI29_IDENTITY=PASS'
  write(*,'(A)') 'FSI30_ADAPTER_EIGHT_CONTEXT_REPLAY=PASS'
  write(*,'(A)') 'FSI30_ADAPTER_IDENTITY_GATE=PASS'

contains

  subroutine bind_from_request(p, x)
    type(b110_dynamic_top_boundary_solver_provider_t), intent(out) :: p
    type(b110_dynamic_top_boundary_request_t), intent(in) :: x
    call bind_b110_dynamic_top_boundary_solver_provider(p, geometry, hydraulics, &
         x%conductivity_mean_method, x%previous_ponding_depth_cm, x%step_duration_day, &
         x%precipitation_rate_cm_per_day, x%irrigation_rate_cm_per_day, x%snowmelt_rate_cm_per_day, &
         x%runon_rate_cm_per_day, x%potential_bare_soil_evaporation_cm_per_day, &
         x%potential_pond_evaporation_cm_per_day, x%ponding_max_cm, &
         x%runoff_resistance_day, x%runoff_exponent)
  end subroutine bind_from_request

  subroutine compare_adapter(a, b, code)
    type(b110_dynamic_top_boundary_result_t), intent(in) :: a
    type(soil_water_top_boundary_result_t), intent(in) :: b
    integer, intent(in) :: code
    call require(b%status == SW_TOP_BOUNDARY_AVAILABLE, code+0)
    select case (a%regime)
    case (B110_DYN_TOP_REGIME_FLUX)
      call require(b%regime == SW_TOP_BOUNDARY_REGIME_FLUX, code+1)
    case (B110_DYN_TOP_REGIME_HEAD)
      call require(b%regime == SW_TOP_BOUNDARY_REGIME_HEAD, code+2)
    case default
      call require(.false., code+3)
    end select
    call require(b%actual_top_flux == a%actual_top_flux_cm_per_day, code+4)
    call require(b%surface_head == a%surface_head_cm, code+5)
    call require(b%surface_face_conductivity == a%surface_face_conductivity_cm_per_day, code+6)
    call require(b%candidate_ponding_depth == a%candidate_ponding_depth_cm, code+7)
    call require(b%bare_soil_evaporation == a%bare_soil_evaporation_cm_per_day, code+8)
    call require(b%ponded_water_evaporation == a%ponded_water_evaporation_cm_per_day, code+9)
    call require(b%runoff_depth == a%runoff_depth_cm, code+10)
    call require(b%net_potential_surface_flux == a%net_potential_surface_flux_cm_per_day, code+11)
    call require(b%carries_surface_mass_terms, code+12)
    call require(b%runoff_potential .eqv. a%runoff_potential, code+13)
    call require(b%runoff_resolved, code+14)
    call require(b%route == a%route, code+15)
  end subroutine compare_adapter

  logical function same_generic_result(a, b) result(same)
    type(soil_water_top_boundary_result_t), intent(in) :: a, b
    same = a%status == b%status .and. a%regime == b%regime .and. &
         a%actual_top_flux == b%actual_top_flux .and. a%surface_head == b%surface_head .and. &
         a%surface_face_conductivity == b%surface_face_conductivity .and. &
         a%candidate_ponding_depth == b%candidate_ponding_depth .and. &
         a%bare_soil_evaporation == b%bare_soil_evaporation .and. &
         a%ponded_water_evaporation == b%ponded_water_evaporation .and. &
         a%runoff_depth == b%runoff_depth .and. &
         a%net_potential_surface_flux == b%net_potential_surface_flux .and. &
         (a%carries_surface_mass_terms .eqv. b%carries_surface_mass_terms) .and. &
         (a%runoff_potential .eqv. b%runoff_potential) .and. &
         (a%runoff_resolved .eqv. b%runoff_resolved) .and. a%route == b%route
  end function same_generic_result

  subroutine set_evaporation_case(x, idx)
    type(b110_dynamic_top_boundary_request_t), intent(inout) :: x
    integer, intent(in) :: idx
    select case(idx)
    case(1)
      x%potential_bare_soil_evaporation_cm_per_day = 0.0_real64
      x%potential_pond_evaporation_cm_per_day = 0.0_real64
    case(2)
      x%potential_bare_soil_evaporation_cm_per_day = 0.30_real64
      x%potential_pond_evaporation_cm_per_day = 0.40_real64
    case(3)
      x%potential_bare_soil_evaporation_cm_per_day = 5.0_real64
      x%potential_pond_evaporation_cm_per_day = 5.0_real64
    end select
  end subroutine set_evaporation_case

  subroutine set_supply_case(x, idx)
    type(b110_dynamic_top_boundary_request_t), intent(inout) :: x
    integer, intent(in) :: idx
    x%precipitation_rate_cm_per_day = 0.0_real64
    x%irrigation_rate_cm_per_day = 0.0_real64
    x%snowmelt_rate_cm_per_day = 0.0_real64
    x%runon_rate_cm_per_day = 0.0_real64
    select case(idx)
    case(1)
    case(2)
      x%precipitation_rate_cm_per_day = 0.10_real64
    case(3)
      x%irrigation_rate_cm_per_day = 0.20_real64
    case(4)
      x%snowmelt_rate_cm_per_day = 0.30_real64
    case(5)
      x%runon_rate_cm_per_day = 0.40_real64
    case(6)
      x%precipitation_rate_cm_per_day = 0.10_real64
      x%irrigation_rate_cm_per_day = 0.20_real64
      x%snowmelt_rate_cm_per_day = 0.30_real64
      x%runon_rate_cm_per_day = 0.40_real64
    case(7)
      x%precipitation_rate_cm_per_day = 20.0_real64
    end select
  end subroutine set_supply_case

  subroutine initialize_request(x, method)
    type(b110_dynamic_top_boundary_request_t), intent(out) :: x
    integer, intent(in) :: method
    x = b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method = method
    x%pressure_head_top_cm = -100.0_real64
    x%water_content_top = 0.20_real64
    x%candidate_ponding_depth_cm = 0.0_real64
    x%previous_ponding_depth_cm = 0.0_real64
    x%step_duration_day = 0.10_real64
    x%potential_bare_soil_evaporation_cm_per_day = 0.30_real64
    x%potential_pond_evaporation_cm_per_day = 0.40_real64
    x%ponding_max_cm = 2.0_real64
    x%runoff_resistance_day = 0.5_real64
    x%runoff_exponent = 1.0_real64
  end subroutine initialize_request

  subroutine configure_family(c, p)
    real(real64), intent(out) :: c(24,nnode)
    type(soil_water_parameter_set_t), intent(out) :: p
    integer :: j
    p%active_nodes = nnode
    allocate(p%z(nnode), p%dz(nnode), p%node_distance(nnode))
    p%z = [-2.5_real64, -11.0_real64]
    p%dz = [5.0_real64, 12.0_real64]
    p%node_distance = [2.75_real64, 8.5_real64]
    c = 0.0_real64
    do j = 1, nnode
      c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
      c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=0.0_real64
      c(10,j)=c(3,j); c(11,j)=0.999_real64; c(12,j)=0.99_real64*c(3,j)
      c(13,j)=0.10_real64; c(14,j)=1.50_real64; c(15,j)=0.50_real64
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine configure_family

  logical function same_request(a, b) result(same)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: a, b
    same = a%conductivity_mean_method == b%conductivity_mean_method .and. &
      a%pressure_head_top_cm == b%pressure_head_top_cm .and. a%water_content_top == b%water_content_top .and. &
      a%candidate_ponding_depth_cm == b%candidate_ponding_depth_cm .and. &
      a%previous_ponding_depth_cm == b%previous_ponding_depth_cm .and. &
      a%step_duration_day == b%step_duration_day .and. &
      a%precipitation_rate_cm_per_day == b%precipitation_rate_cm_per_day .and. &
      a%irrigation_rate_cm_per_day == b%irrigation_rate_cm_per_day .and. &
      a%snowmelt_rate_cm_per_day == b%snowmelt_rate_cm_per_day .and. &
      a%runon_rate_cm_per_day == b%runon_rate_cm_per_day .and. &
      a%potential_bare_soil_evaporation_cm_per_day == b%potential_bare_soil_evaporation_cm_per_day .and. &
      a%potential_pond_evaporation_cm_per_day == b%potential_pond_evaporation_cm_per_day .and. &
      a%ponding_max_cm == b%ponding_max_cm .and. &
      a%runoff_resistance_day == b%runoff_resistance_day .and. a%runoff_exponent == b%runoff_exponent
  end function same_request

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(error_unit,'(A,I0)') 'FSI30_ADAPTER_IDENTITY_FAIL_CODE=', code
      error stop 1
    end if
  end subroutine require

end program test_fsi30_adapter_identity
