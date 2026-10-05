module mod_fmr_tillage_reference_material_candidate
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t
  use mod_fmr_tillage_event_transaction, only: tillage_event_candidate_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_state_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t
  implicit none
  private
  integer, parameter, public :: TILLAGE_REFERENCE_CANDIDATE_OK = 0
  integer, parameter, public :: TILLAGE_REFERENCE_CANDIDATE_INVALID = 1
  public :: build_tillage_reference_material_candidate
contains
  subroutine build_tillage_reference_material_candidate(prior_parameters,prior_state,tillage, &
       next_parameter_set_id,parameters_candidate,state_candidate,status)
    type(fmr_b110_physical_parameters_t), intent(in) :: prior_parameters
    type(fmr_b110_physical_state_t), intent(in) :: prior_state
    type(tillage_event_candidate_t), intent(in) :: tillage
    integer(int64), intent(in) :: next_parameter_set_id
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters_candidate
    type(fmr_b110_physical_state_t), intent(out) :: state_candidate
    integer, intent(out) :: status
    real(real64) :: old_water,new_water,reconstructed
    integer :: i,n

    parameters_candidate = fmr_b110_physical_parameters_t()
    state_candidate = fmr_b110_physical_state_t()
    status = TILLAGE_REFERENCE_CANDIDATE_INVALID
    n = prior_parameters%active_nodes
    if (n < 1 .or. next_parameter_set_id <= 0_int64 .or. &
        next_parameter_set_id == prior_parameters%parameter_set_id) return
    if (prior_state%active_nodes /= n .or. prior_parameters%hysteresis_active .or. &
        prior_parameters%macropore_active .or. prior_parameters%tabulated_hydraulics_active .or. &
        prior_parameters%direct_retention_active .or. prior_parameters%ksatexm_extension_active .or. &
        prior_parameters%elasticity_active .or. prior_parameters%frost_active) return
    if (.not. allocated(prior_parameters%cofgen) .or. .not. allocated(prior_parameters%dz) .or. &
        .not. allocated(prior_state%water_content) .or. .not. allocated(prior_state%pressure_head) .or. &
        .not. allocated(tillage%hydraulic_parameters) .or. &
        .not. allocated(tillage%hydraulic%water_content) .or. &
        .not. allocated(tillage%hydraulic%pressure_head_cm)) return
    if (size(prior_parameters%cofgen,1) < 24 .or. size(prior_parameters%cofgen,2) /= n .or. &
        size(prior_parameters%dz) /= n .or. size(prior_state%water_content) /= n .or. &
        size(prior_state%pressure_head) /= n .or. size(tillage%hydraulic_parameters) /= n .or. &
        size(tillage%hydraulic%water_content) /= n .or. &
        size(tillage%hydraulic%pressure_head_cm) /= n) return
    if (.not. all(ieee_is_finite(prior_parameters%dz)) .or. &
        any(prior_parameters%dz <= 0.0_real64) .or. &
        .not. all(ieee_is_finite(prior_state%water_content)) .or. &
        .not. all(ieee_is_finite(prior_state%pressure_head)) .or. &
        .not. ieee_is_finite(prior_state%ponding_depth) .or. &
        .not. all(ieee_is_finite(tillage%hydraulic%water_content)) .or. &
        .not. all(ieee_is_finite(tillage%hydraulic%pressure_head_cm)) .or. &
        .not. ieee_is_finite(tillage%hydraulic%ponding_depth_cm) .or. &
        .not. ieee_is_finite(tillage%hydraulic%mass_residual_cm)) return
    if (prior_state%ponding_depth < 0.0_real64 .or. &
        tillage%hydraulic%ponding_depth_cm < 0.0_real64 .or. &
        any(tillage%hydraulic%water_content < 0.0_real64)) return
    old_water = sum(prior_state%water_content*prior_parameters%dz)+prior_state%ponding_depth
    new_water = sum(tillage%hydraulic%water_content*prior_parameters%dz)+ &
         tillage%hydraulic%ponding_depth_cm
    if (abs(old_water-new_water) > 1.e-12_real64 .or. &
        abs(tillage%hydraulic%mass_residual_cm) > 1.e-12_real64) return
    do i=1,n
      if (.not. valid_vg(tillage%hydraulic_parameters(i))) return
      if (tillage%hydraulic%water_content(i) < tillage%hydraulic_parameters(i)%theta_residual-1.e-12_real64 .or. &
          tillage%hydraulic%water_content(i) > tillage%hydraulic_parameters(i)%theta_saturated+1.e-12_real64) return
      if (tillage%hydraulic%pressure_head_cm(i) >= 0.0_real64) then
        reconstructed = tillage%hydraulic_parameters(i)%theta_saturated
      else
        reconstructed = tillage%hydraulic_parameters(i)%theta_residual + &
             (tillage%hydraulic_parameters(i)%theta_saturated-tillage%hydraulic_parameters(i)%theta_residual)* &
             (1.0_real64+(tillage%hydraulic_parameters(i)%alpha* &
             abs(tillage%hydraulic%pressure_head_cm(i)))**tillage%hydraulic_parameters(i)%n)** &
             (-tillage%hydraulic_parameters(i)%m)
      end if
      if (.not. ieee_is_finite(reconstructed) .or. &
          abs(reconstructed-tillage%hydraulic%water_content(i)) > 1.e-10_real64) return
    end do
    parameters_candidate = prior_parameters
    parameters_candidate%parameter_set_id = next_parameter_set_id
    parameters_candidate%prepared_default_mvg_available = .false.
    parameters_candidate%prepared_default_mvg = b110_default_mvg_parameters_t()
    do i=1,n
      parameters_candidate%cofgen(1,i) = tillage%hydraulic_parameters(i)%theta_residual
      parameters_candidate%cofgen(2,i) = tillage%hydraulic_parameters(i)%theta_saturated
      parameters_candidate%cofgen(3,i) = tillage%hydraulic_parameters(i)%saturated_conductivity
      parameters_candidate%cofgen(4,i) = tillage%hydraulic_parameters(i)%alpha
      parameters_candidate%cofgen(5,i) = tillage%hydraulic_parameters(i)%lambda
      parameters_candidate%cofgen(6,i) = tillage%hydraulic_parameters(i)%n
      parameters_candidate%cofgen(7,i) = tillage%hydraulic_parameters(i)%m
    end do
    state_candidate = prior_state
    state_candidate%water_content = tillage%hydraulic%water_content
    state_candidate%pressure_head = tillage%hydraulic%pressure_head_cm
    state_candidate%ponding_depth = tillage%hydraulic%ponding_depth_cm
    status = TILLAGE_REFERENCE_CANDIDATE_OK
  end subroutine

  pure logical function valid_vg(vg)
    type(tillage_vg_parameters_t), intent(in) :: vg
    valid_vg = all(ieee_is_finite([vg%theta_residual,vg%theta_saturated, &
         vg%saturated_conductivity,vg%alpha,vg%lambda,vg%n,vg%m]))
    if (.not. valid_vg) return
    valid_vg = vg%theta_residual >= 0.0_real64 .and. vg%theta_saturated > vg%theta_residual .and. &
         vg%theta_saturated <= 1.0_real64 .and. vg%saturated_conductivity > 0.0_real64 .and. &
         vg%alpha > 0.0_real64 .and. vg%lambda >= 0.0_real64 .and. vg%n > 1.0_real64 .and. &
         abs(vg%m-(1.0_real64-1.0_real64/vg%n)) <= 1.e-12_real64
  end function
end module
