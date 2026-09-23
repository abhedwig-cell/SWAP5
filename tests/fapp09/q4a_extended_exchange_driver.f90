program q4a_extended_exchange_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_extended_exchange
  implicit none
  integer :: n, i, highest_i, deriv_i
  type(extended_drainage_parameters_t) :: p
  type(extended_drainage_control_t) :: c
  type(extended_drainage_result_t) :: r
  type(extended_drainage_diagnostics_t) :: d
  type(process_hydraulic_view_t) :: v

  read(*,*) n
  do i = 1, n
    read(*,*) p%zbotdr_cm, p%drain_type, p%width_cm, p%talud, p%spacing_cm, &
      p%rdrain_day, p%rinfi_day, p%rentry_day, p%rexit_day, p%gwlinf_cm, &
      highest_i, p%highest_surface_mode, p%rsurfdeep_day, p%rsurfshallow_day, &
      p%interflow_coefficient, p%interflow_exponent, p%pondmx_cm, &
      v%groundwater_level, c%resolved_surface_water_head_cm, v%ponding_depth
    p%highest_level = highest_i /= 0
    call evaluate_extended_drainage_exchange(p, v, c, r, d)
    deriv_i = merge(1, 0, r%derivative_defined)
    write(*,'(I0,1X,I0,1X,ES25.16E3,1X,ES25.16E3,1X,ES25.16E3,1X,I0,1X,ES25.16E3,1X,ES25.16E3,1X,ES25.16E3,1X,I0,1X,I0,1X,I0,1X,I0)') &
      d%status, d%branch, r%signed_soil_to_surface_rate_cm_day, r%resolved_drain_level_cm, &
      r%effective_head_difference_cm, deriv_i, r%dq_dgroundwater_level, r%dq_dcontrol_head, &
      r%dq_dponding_depth, merge(1,0,d%gwlinf_cap_active), merge(1,0,d%sign_resistance_boundary), &
      merge(1,0,d%surface_resistance_boundary), merge(1,0,d%power_activation_boundary)
  end do
end program q4a_extended_exchange_driver
