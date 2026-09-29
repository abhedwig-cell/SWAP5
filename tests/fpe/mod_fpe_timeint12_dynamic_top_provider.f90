module mod_fpe_timeint12_dynamic_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, soil_water_parameter_set_t, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none
  private

  type, extends(dynamic_top_boundary_provider_t), public :: fpe_timeint12_dynamic_top_provider_t
    type(soil_water_parameter_set_t), pointer :: geometry => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulics => null()
    integer :: conductivity_mean_method = 1
    real(real64) :: previous_ponding_depth = 0.0_real64
    real(real64) :: step_duration = 0.0_real64
    real(real64) :: precipitation_rate = 0.0_real64
    real(real64) :: ponding_max = 0.05_real64
    real(real64) :: runoff_resistance = 0.05_real64
  contains
    procedure :: evaluate => fpe_timeint12_evaluate
  end type

  public :: bind_fpe_timeint12_dynamic_top_provider

contains

  subroutine bind_fpe_timeint12_dynamic_top_provider(provider, geometry, hydraulics, previous_ponding_depth, &
       step_duration, precipitation_rate)
    type(fpe_timeint12_dynamic_top_provider_t), intent(out) :: provider
    type(soil_water_parameter_set_t), target, intent(in) :: geometry
    type(b110_default_mvg_parameters_t), target, intent(in) :: hydraulics
    real(real64), intent(in) :: previous_ponding_depth, step_duration, precipitation_rate
    provider%geometry => geometry
    provider%hydraulics => hydraulics
    provider%previous_ponding_depth = previous_ponding_depth
    provider%step_duration = step_duration
    provider%precipitation_rate = precipitation_rate
  end subroutine

  subroutine fpe_timeint12_evaluate(self, pressure_head_top, water_content_top, candidate_ponding_depth, requested, result)
    class(fpe_timeint12_dynamic_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result

    type(b110_dynamic_top_boundary_solver_provider_t) :: base
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64), allocatable :: heads(:), dirs(:), dtheta(:), dk(:), basek(:)
    real(real64) :: dk_top, p1, p1p, denom, aprime
    logical :: available
    character(len=64) :: route
    integer :: n

    result = soil_water_top_boundary_result_t()
    if (.not. associated(self%geometry) .or. .not. associated(self%hydraulics)) return

    call bind_b110_dynamic_top_boundary_solver_provider(base, self%geometry, self%hydraulics, &
         self%conductivity_mean_method, self%previous_ponding_depth, self%step_duration, &
         self%precipitation_rate, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
         self%ponding_max, self%runoff_resistance, 1.0_real64)
    call base%evaluate(pressure_head_top, water_content_top, candidate_ponding_depth, requested, result)
    if (result%status /= SW_TOP_BOUNDARY_AVAILABLE) return
    if (result%regime /= SW_TOP_BOUNDARY_REGIME_HEAD) return
    if (result%surface_head_derivative_available) return
    if (self%conductivity_mean_method /= 1) then
      result%status = 0
      result%route = 'timeint12-mean-method-deferred'
      return
    end if

    n=self%geometry%active_nodes
    allocate(heads(n),dirs(n),dtheta(n),dk(n),basek(n))
    heads=pressure_head_top
    dirs=0.0_real64
    dirs(1)=1.0_real64
    call bind_b110_default_mvg_provider(constitutive,self%hydraulics,self%step_duration)
    call evaluate_b110_default_mvg_state_direction(constitutive,heads,dirs,dtheta,dk,available,route,basek)
    if (.not. available) then
      result%status = 0
      result%route = 'timeint12-dkdh-unavailable'
      return
    end if

    dk_top=dk(1)
    p1=result%surface_face_conductivity/self%geometry%node_distance(1)*self%step_duration
    p1p=0.5_real64*dk_top/self%geometry%node_distance(1)*self%step_duration
    if (result%runoff_depth > 0.0_real64) then
      denom=1.0_real64+p1+self%step_duration/self%runoff_resistance
    else
      denom=1.0_real64+p1
    end if
    aprime=-0.5_real64*dk_top*self%step_duration + p1p*pressure_head_top + p1
    result%surface_head_derivative_available=.true.
    result%surface_head_dpressure_head_top=(aprime-result%surface_head*p1p)/denom
  end subroutine

end module mod_fpe_timeint12_dynamic_top_provider
