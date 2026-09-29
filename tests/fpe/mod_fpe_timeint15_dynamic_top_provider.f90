module mod_fpe_timeint15_dynamic_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, soil_water_parameter_set_t, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_UNAVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, evaluate_b110_default_mvg_conductivity
  implicit none
  private

  real(real64), parameter :: ATM_HEAD=-2.75e5_real64
  real(real64), parameter :: HEAD_SWITCH=1.0e-6_real64
  real(real64), parameter :: MIN_RSRO=1.0e-3_real64

  type, extends(dynamic_top_boundary_provider_t), public :: fpe_timeint15_dynamic_top_provider_t
    type(soil_water_parameter_set_t), pointer :: geometry => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulics => null()
    real(real64) :: pond_n = 0.0_real64
    real(real64) :: pond_nm1 = 0.0_real64
    real(real64) :: dt = 0.0_real64
    real(real64) :: rain = 0.0_real64
    real(real64) :: pmax = 0.0_real64
    real(real64) :: rsro = 0.0_real64
    real(real64) :: fixed_top_k = -1.0_real64
    real(real64) :: a0 = 1.0_real64
    real(real64) :: a1 = -1.0_real64
    real(real64) :: a2 = 0.0_real64
    real(real64) :: previous_runoff_depth = 0.0_real64
  contains
    procedure :: evaluate => timeint15_evaluate
  end type

  public :: bind_fpe_timeint15_dynamic_top_provider

contains

  subroutine bind_fpe_timeint15_dynamic_top_provider(provider, geometry, hydraulics, pond_n, pond_nm1, dt, rain, &
       pmax, rsro, fixed_top_k, a0, a1, a2, previous_runoff_depth)
    type(fpe_timeint15_dynamic_top_provider_t), intent(out) :: provider
    type(soil_water_parameter_set_t), target, intent(in) :: geometry
    type(b110_default_mvg_parameters_t), target, intent(in) :: hydraulics
    real(real64), intent(in) :: pond_n, pond_nm1, dt, rain, pmax, rsro, fixed_top_k, a0, a1, a2
    real(real64), intent(in) :: previous_runoff_depth

    provider%geometry => geometry
    provider%hydraulics => hydraulics
    provider%pond_n = pond_n
    provider%pond_nm1 = pond_nm1
    provider%dt = dt
    provider%rain = rain
    provider%pmax = pmax
    provider%rsro = rsro
    provider%fixed_top_k = fixed_top_k
    provider%a0 = a0
    provider%a1 = a1
    provider%a2 = a2
    provider%previous_runoff_depth = previous_runoff_depth
  end subroutine

  subroutine timeint15_evaluate(self, pressure_head_top, water_content_top, candidate_ponding_depth, requested, result)
    class(fpe_timeint15_dynamic_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result

    real(real64) :: k_atm,k_sat,k_top,k1_atm,k1_max,top_dz,top_distance
    real(real64) :: emax,q0,q1,h0,p1,numer,denom,p_no,runoff_rate,runoff_depth
    logical :: ok

    result=soil_water_top_boundary_result_t()
    if (.not.associated(self%geometry) .or. .not.associated(self%hydraulics)) then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-unbound'; return
    end if
    if (.not.ieee_is_finite(pressure_head_top) .or. .not.ieee_is_finite(water_content_top) .or. &
        .not.ieee_is_finite(candidate_ponding_depth)) then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-nonfinite-state'; return
    end if
    if (self%geometry%active_nodes<=0 .or. self%dt<=0.0_real64 .or. self%a0<=0.0_real64 .or. &
        self%rsro<MIN_RSRO .or. self%fixed_top_k<0.0_real64 .or. self%pmax<0.0_real64 .or. &
        self%pond_n<0.0_real64 .or. self%pond_nm1<0.0_real64 .or. self%previous_runoff_depth<0.0_real64) then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-invalid-config'; return
    end if
    if (abs(self%a0+self%a1+self%a2)>64.0_real64*epsilon(1.0_real64)) then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-invalid-coeff-sum'; return
    end if

    top_dz=self%geometry%dz(1)
    top_distance=self%geometry%node_distance(1)
    call evaluate_b110_default_mvg_conductivity(self%hydraulics,1,ATM_HEAD,k_atm,ok)
    if(.not.ok)then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-katm'; return
    end if
    call evaluate_b110_default_mvg_conductivity(self%hydraulics,1,0.0_real64,k_sat,ok)
    if(.not.ok)then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-ksat'; return
    end if
    k_top=self%fixed_top_k
    k1_atm=0.5_real64*(k_atm+k_top)
    k1_max=0.5_real64*(k_sat+k_top)
    if(k1_max<=0.0_real64)then
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE; result%route='timeint15-kface'; return
    end if

    emax=-k1_atm*((ATM_HEAD-pressure_head_top)/top_distance+1.0_real64)
    q0=self%rain
    q1=(self%a1*self%pond_n+self%a2*self%pond_nm1)/self%dt-q0

    if(q1>=0.0_real64 .and. q1>emax)then
      result%regime=SW_TOP_BOUNDARY_REGIME_HEAD
      result%actual_top_flux=-k1_atm*((ATM_HEAD-pressure_head_top)/top_distance+1.0_real64)
      result%surface_head=ATM_HEAD
      result%surface_face_conductivity=k1_atm
      result%candidate_ponding_depth=0.0_real64
      runoff_rate=0.0_real64
      runoff_depth=(self%dt/self%a0)*runoff_rate+(self%a2/self%a0)*self%previous_runoff_depth
      result%runoff_depth=max(0.0_real64,runoff_depth)
      result%surface_head_derivative_available=.true.
      result%surface_head_dpressure_head_top=0.0_real64
      result%carries_surface_mass_terms=.true.
      result%runoff_potential=result%runoff_depth>0.0_real64
      result%runoff_resolved=.true.
      result%status=SW_TOP_BOUNDARY_AVAILABLE
      result%route='timeint15-atmospheric-head'
      return
    end if

    h0=pressure_head_top-top_distance*(q1/k1_max+1.0_real64)
    if(h0<=HEAD_SWITCH)then
      result%regime=SW_TOP_BOUNDARY_REGIME_FLUX
      result%actual_top_flux=q1
      result%surface_head=0.0_real64
      result%surface_face_conductivity=0.0_real64
      result%candidate_ponding_depth=0.0_real64
      runoff_rate=0.0_real64
      runoff_depth=(self%a2/self%a0)*self%previous_runoff_depth
      result%runoff_depth=max(0.0_real64,runoff_depth)
      result%surface_head_derivative_available=.false.
      result%surface_head_dpressure_head_top=0.0_real64
      result%carries_surface_mass_terms=.true.
      result%runoff_potential=result%runoff_depth>0.0_real64
      result%runoff_resolved=.true.
      result%status=SW_TOP_BOUNDARY_AVAILABLE
      result%route='timeint15-surface-flux'
      return
    end if

    p1=k1_max/top_distance*self%dt
    numer=-self%a1*self%pond_n-self%a2*self%pond_nm1+q0*self%dt-k1_max*self%dt+p1*pressure_head_top
    denom=self%a0+p1
    p_no=numer/denom

    result%regime=SW_TOP_BOUNDARY_REGIME_HEAD
    result%surface_face_conductivity=k1_max
    result%surface_head_derivative_available=.true.
    result%runoff_potential=.true.

    if(p_no<=self%pmax)then
      result%candidate_ponding_depth=max(0.0_real64,p_no)
      runoff_rate=0.0_real64
      result%surface_head_dpressure_head_top=p1/denom
      result%route='timeint15-ponded-head'
    else
      denom=self%a0+p1+self%dt/self%rsro
      numer=numer+(self%dt/self%rsro)*self%pmax
      result%candidate_ponding_depth=max(0.0_real64,numer/denom)
      runoff_rate=max(0.0_real64,(result%candidate_ponding_depth-self%pmax)/self%rsro)
      result%surface_head_dpressure_head_top=p1/denom
      result%route='timeint15-ponded-head-linear-runoff'
    end if

    runoff_depth=(self%dt/self%a0)*runoff_rate+(self%a2/self%a0)*self%previous_runoff_depth
    result%runoff_depth=max(0.0_real64,runoff_depth)
    result%surface_head=result%candidate_ponding_depth
    result%actual_top_flux=-k1_max*((result%surface_head-pressure_head_top)/top_distance+1.0_real64)
    result%carries_surface_mass_terms=.true.
    result%runoff_resolved=.true.
    result%status=SW_TOP_BOUNDARY_AVAILABLE

    if(.not.ieee_is_finite(result%actual_top_flux) .or. .not.ieee_is_finite(result%surface_head) .or. &
       .not.ieee_is_finite(result%runoff_depth) .or. .not.ieee_is_finite(result%surface_head_dpressure_head_top))then
      result=soil_water_top_boundary_result_t()
      result%status=SW_TOP_BOUNDARY_UNAVAILABLE
      result%route='timeint15-nonfinite-result'
    end if
  end subroutine
end module mod_fpe_timeint15_dynamic_top_provider
