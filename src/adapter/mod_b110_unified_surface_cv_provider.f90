module mod_b110_unified_surface_cv_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, &
       soil_water_boundary_conditions_t, soil_water_top_boundary_result_t, soil_water_parameter_set_t, &
       SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       evaluate_b110_default_mvg_conductivity
  implicit none
  private

  type, extends(dynamic_top_boundary_provider_t), public :: b110_unified_surface_cv_provider_t
    type(soil_water_parameter_set_t), pointer :: geometry => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulics => null()
    real(real64) :: previous_storage_cm = 0.0_real64
    real(real64) :: step_duration_day = 0.0_real64
    real(real64) :: external_head_cm = 0.0_real64
    real(real64) :: sill_cm = 0.0_real64
    real(real64) :: microrelief_depth_cm = 0.0_real64
    real(real64) :: contact_conductance_scale = 0.0_real64
    real(real64) :: atmospheric_input_rate_cm_per_day = 0.0_real64
    real(real64) :: fixed_top_node_conductivity = 0.0_real64
  contains
    procedure :: evaluate => b110_unified_surface_cv_evaluate
  end type b110_unified_surface_cv_provider_t

  public :: bind_b110_unified_surface_cv_provider

contains

  subroutine bind_b110_unified_surface_cv_provider(provider, geometry, hydraulics, previous_storage_cm, &
       step_duration_day, external_head_cm, sill_cm, microrelief_depth_cm, contact_conductance_scale, &
       atmospheric_input_rate_cm_per_day, fixed_top_node_conductivity)
    type(b110_unified_surface_cv_provider_t), intent(out) :: provider
    type(soil_water_parameter_set_t), target, intent(in) :: geometry
    type(b110_default_mvg_parameters_t), target, intent(in) :: hydraulics
    real(real64), intent(in) :: previous_storage_cm, step_duration_day, external_head_cm, sill_cm
    real(real64), intent(in) :: microrelief_depth_cm, contact_conductance_scale
    real(real64), intent(in) :: atmospheric_input_rate_cm_per_day, fixed_top_node_conductivity

    provider%geometry => geometry
    provider%hydraulics => hydraulics
    provider%previous_storage_cm = previous_storage_cm
    provider%step_duration_day = step_duration_day
    provider%external_head_cm = external_head_cm
    provider%sill_cm = sill_cm
    provider%microrelief_depth_cm = microrelief_depth_cm
    provider%contact_conductance_scale = contact_conductance_scale
    provider%atmospheric_input_rate_cm_per_day = atmospheric_input_rate_cm_per_day
    provider%fixed_top_node_conductivity = fixed_top_node_conductivity
  end subroutine bind_b110_unified_surface_cv_provider

  subroutine b110_unified_surface_cv_evaluate(self, pressure_head_top, water_content_top, &
       candidate_ponding_depth, requested, result)
    class(b110_unified_surface_cv_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result
    real(real64) :: d, dt, kface, g, g_surface, sill, s0, hs, hlo, hhi, mid, flo, fhi, fmid
    real(real64) :: qext, qsoil, hr_excess, hs_excess, storage_slope, derivative, ksat
    logical :: ok
    integer :: iteration

    result = soil_water_top_boundary_result_t()
    if (.not. associated(self%geometry) .or. .not. associated(self%hydraulics)) return
    if (.not. all_finite([pressure_head_top, water_content_top, candidate_ponding_depth, &
         self%previous_storage_cm, self%step_duration_day, self%external_head_cm, self%sill_cm, &
         self%microrelief_depth_cm, self%contact_conductance_scale, &
         self%atmospheric_input_rate_cm_per_day, self%fixed_top_node_conductivity])) return
    if (self%step_duration_day <= 0.0_real64 .or. self%microrelief_depth_cm <= 0.0_real64 .or. &
        self%contact_conductance_scale <= 0.0_real64 .or. self%fixed_top_node_conductivity <= 0.0_real64) return
    if (self%previous_storage_cm < 0.0_real64 .or. self%atmospheric_input_rate_cm_per_day < 0.0_real64) return
    d = self%geometry%node_distance(1)
    if (d <= 0.0_real64) return
    dt = self%step_duration_day
    s0 = self%previous_storage_cm
    sill = self%sill_cm
    kface = 0.5_real64*(self%hydraulics%cofgen(3,1)+self%fixed_top_node_conductivity)
    call evaluate_b110_default_mvg_conductivity(self%hydraulics,1,0.0_real64,ksat,ok)
    if (.not.ok .or. kface <= 0.0_real64 .or. ksat <= 0.0_real64) return
    g = self%contact_conductance_scale*kface/d

    hlo = min(-self%microrelief_depth_cm,self%external_head_cm,pressure_head_top,sill)-100.0_real64
    hhi = max(self%microrelief_depth_cm,self%external_head_cm,pressure_head_top,s0,sill)+100.0_real64
    flo = residual(hlo)
    fhi = residual(hhi)
    if (.not. all_finite([flo,fhi]) .or. flo > 0.0_real64 .or. fhi < 0.0_real64) return
    do iteration=1,100
      mid = 0.5_real64*(hlo+hhi)
      fmid = residual(mid)
      if (.not. ieee_finite_scalar(fmid)) return
      if (fmid > 0.0_real64) then
        hhi = mid
      else
        hlo = mid
      end if
      if (abs(hhi-hlo) <= 2.0e-14_real64*max(1.0_real64,abs(mid))) exit
    end do
    hs = 0.5_real64*(hlo+hhi)
    hr_excess = max(self%external_head_cm-sill,0.0_real64)
    hs_excess = max(hs-sill,0.0_real64)
    qext = g*(hr_excess-hs_excess)
    qsoil = kface*((hs-pressure_head_top)/d+1.0_real64)
    storage_slope = storage_derivative(hs)
    g_surface = 0.0_real64
    if (hs > sill) g_surface = g
    derivative = storage_slope+dt*g_surface+dt*kface/d
    if (derivative <= 0.0_real64) return

    result%status = SW_TOP_BOUNDARY_AVAILABLE
    result%regime = SW_TOP_BOUNDARY_REGIME_HEAD
    result%actual_top_flux = -qsoil
    result%surface_head = hs
    result%surface_face_conductivity = kface
    result%candidate_ponding_depth = storage(hs)
    result%net_potential_surface_flux = self%atmospheric_input_rate_cm_per_day+qext
    result%surface_head_derivative_available = .true.
    result%surface_head_dpressure_head_top = dt*kface/d/derivative
    result%carries_surface_mass_terms = .true.
    result%runoff_resolved = .true.
    result%route = 'unified-surface-control-volume'

  contains

    real(real64) function storage(head)
      real(real64), intent(in) :: head
      real(real64) :: depth
      depth = self%microrelief_depth_cm
      if (head <= -depth) then
        storage = 0.0_real64
      else if (head < depth) then
        storage = (head+depth)**2/(4.0_real64*depth)
      else
        storage = head
      end if
    end function storage

    real(real64) function storage_derivative(head)
      real(real64), intent(in) :: head
      real(real64) :: depth
      depth = self%microrelief_depth_cm
      if (head <= -depth) then
        storage_derivative = 0.0_real64
      else if (head < depth) then
        storage_derivative = (head+depth)/(2.0_real64*depth)
      else
        storage_derivative = 1.0_real64
      end if
    end function storage_derivative

    real(real64) function residual(head)
      real(real64), intent(in) :: head
      real(real64) :: external_flux, soil_flux
      external_flux = g*(max(self%external_head_cm-sill,0.0_real64)-max(head-sill,0.0_real64))
      soil_flux = kface*((head-pressure_head_top)/d+1.0_real64)
      residual = storage(head)-s0-dt*(self%atmospheric_input_rate_cm_per_day+external_flux-soil_flux)
    end function residual

    logical function all_finite(values)
      real(real64), intent(in) :: values(:)
      integer :: index
      all_finite = .true.
      do index=1,size(values)
        if (.not.ieee_finite_scalar(values(index))) all_finite = .false.
      end do
    end function all_finite

    logical function ieee_finite_scalar(value)
      use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
      real(real64), intent(in) :: value
      ieee_finite_scalar = ieee_is_finite(value)
    end function ieee_finite_scalar

  end subroutine b110_unified_surface_cv_evaluate

end module mod_b110_unified_surface_cv_provider
