module mod_fmr_tillage_event_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t, transform_tillage_vg, &
       consolidate_tillage_density, TILLAGE_OK
  use mod_fmr_tillage_event_owner, only: tillage_owner_state_t, advance_tillage_owner, &
       TILLAGE_OWNER_OK, TILLAGE_OWNER_SPLIT_REQUIRED
  use mod_fmr_tillage_hydraulic_binding, only: tillage_hydraulic_candidate_t, &
       bind_tillage_hydraulic_candidate, TILLAGE_BIND_OK
  implicit none
  private
  integer, parameter, public :: TILLAGE_TRANSACTION_OK = 0
  integer, parameter, public :: TILLAGE_TRANSACTION_INVALID = 1
  integer, parameter, public :: TILLAGE_TRANSACTION_SPLIT = 2
  type, public :: tillage_compatibility_t
    logical :: hysteresis_enabled = .false.
    logical :: solute_enabled = .false.
    logical :: physical_oxygen_enabled = .false.
    logical :: macropore_enabled = .false.
    logical :: extended_saturated_conductivity = .false.
    logical :: vertical_discretization_enabled = .false.
  end type
  type, public :: tillage_event_input_t
    logical, allocatable :: affected(:)
    real(real64), allocatable :: target_density(:)
    real(real64) :: intensity = 0.0_real64
    integer :: n_model = 1
    integer :: redistribution_mode = 1
  end type
  type, public :: tillage_event_candidate_t
    type(tillage_owner_state_t) :: owner
    integer :: applied_event_index = 0
    real(real64), allocatable :: density(:)
    type(tillage_vg_parameters_t), allocatable :: hydraulic_parameters(:)
    type(tillage_hydraulic_candidate_t) :: hydraulic
  end type
  public :: evaluate_tillage_event_transaction, evaluate_tillage_consolidation_transaction
contains
  pure subroutine evaluate_tillage_event_transaction(days,t0,t1,accepted_rain_cm,committed_owner, &
       event_input,prior_density,prior_vg,prior_theta,prior_head_cm,thickness_cm,prior_pond_cm, &
       silt_fraction,clay_fraction,matching_slope,compatibility,candidate,status)
    real(real64), intent(in) :: days(:),t0,t1,accepted_rain_cm
    type(tillage_owner_state_t), intent(in) :: committed_owner
    type(tillage_event_input_t), intent(in) :: event_input(:)
    real(real64), intent(in) :: prior_density(:),prior_theta(:),prior_head_cm(:),thickness_cm(:)
    real(real64), intent(in) :: prior_pond_cm,silt_fraction(:),clay_fraction(:),matching_slope(:)
    type(tillage_vg_parameters_t), intent(in) :: prior_vg(:)
    type(tillage_compatibility_t), intent(in) :: compatibility
    type(tillage_event_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status
    type(tillage_owner_state_t) :: proposed_owner
    type(tillage_event_candidate_t) :: proposed
    real(real64), allocatable :: new_retention(:)
    real(real64) :: new_density, se
    integer :: owner_status,event_index,n,i,transform_status,bind_status

    candidate = tillage_event_candidate_t()
    candidate%owner = committed_owner
    status = TILLAGE_TRANSACTION_INVALID
    if (incompatible(compatibility)) return
    n = size(prior_density)
    if (n < 1 .or. size(days) /= size(event_input)) return
    if (size(prior_theta) /= n .or. size(prior_head_cm) /= n .or. size(thickness_cm) /= n .or. &
        size(prior_vg) /= n .or. size(silt_fraction) /= n .or. size(clay_fraction) /= n .or. &
        size(matching_slope) /= n) return
    call advance_tillage_owner(days,t0,t1,accepted_rain_cm,committed_owner,proposed_owner, &
         event_index,owner_status)
    if (owner_status == TILLAGE_OWNER_SPLIT_REQUIRED) then
      status = TILLAGE_TRANSACTION_SPLIT
      return
    end if
    if (owner_status /= TILLAGE_OWNER_OK) return
    proposed%owner = proposed_owner
    if (event_index == 0) then
      candidate = proposed
      status = TILLAGE_TRANSACTION_OK
      return
    end if
    if (.not. allocated(event_input(event_index)%affected) .or. &
        .not. allocated(event_input(event_index)%target_density)) return
    if (size(event_input(event_index)%affected) /= n .or. &
        size(event_input(event_index)%target_density) /= n) return
    if (.not. ieee_is_finite(event_input(event_index)%intensity) .or. &
        event_input(event_index)%intensity < 0.0_real64 .or. &
        event_input(event_index)%intensity > 1.0_real64) return
    if (any(.not. ieee_is_finite(prior_density)) .or. &
        any(.not. ieee_is_finite(prior_head_cm)) .or. &
        any(.not. ieee_is_finite(event_input(event_index)%target_density))) return
    allocate(proposed%density(n),proposed%hydraulic_parameters(n),new_retention(n))
    proposed%density = prior_density
    proposed%hydraulic_parameters = prior_vg
    do i = 1,n
      if (.not. event_input(event_index)%affected(i)) then
        new_retention(i) = prior_theta(i)
        cycle
      end if
      new_density = prior_density(i)+event_input(event_index)%intensity* &
           (event_input(event_index)%target_density(i)-prior_density(i))
      call transform_tillage_vg(prior_vg(i),prior_density(i),new_density, &
           event_input(event_index)%n_model,silt_fraction(i),clay_fraction(i),matching_slope(i), &
           proposed%hydraulic_parameters(i),transform_status)
      if (transform_status /= TILLAGE_OK) return
      proposed%density(i) = new_density
      if (prior_head_cm(i) >= 0.0_real64) then
        new_retention(i) = proposed%hydraulic_parameters(i)%theta_saturated
      else
        se = (1.0_real64+(proposed%hydraulic_parameters(i)%alpha*abs(prior_head_cm(i)))** &
             proposed%hydraulic_parameters(i)%n)**(-proposed%hydraulic_parameters(i)%m)
        new_retention(i) = proposed%hydraulic_parameters(i)%theta_residual+ &
             (proposed%hydraulic_parameters(i)%theta_saturated- &
              proposed%hydraulic_parameters(i)%theta_residual)*se
      end if
      if (.not. ieee_is_finite(new_retention(i))) return
    end do
    call bind_tillage_hydraulic_candidate(prior_theta,prior_pond_cm,new_retention, &
         thickness_cm,proposed%hydraulic_parameters,event_input(event_index)%redistribution_mode, &
         proposed%hydraulic,bind_status)
    if (bind_status /= TILLAGE_BIND_OK) return
    proposed%applied_event_index = event_index
    candidate = proposed
    status = TILLAGE_TRANSACTION_OK
  end subroutine

  pure subroutine evaluate_tillage_consolidation_transaction(days,t0,t1,accepted_rain_cm, &
       committed_owner,event_density,consolidation_density,rate_per_mm,prior_density,prior_vg, &
       prior_theta,prior_head_cm,thickness_cm,prior_pond_cm,silt_fraction,clay_fraction, &
       matching_slope,n_model,redistribution_mode,compatibility,candidate,status)
    real(real64), intent(in) :: days(:),t0,t1,accepted_rain_cm
    type(tillage_owner_state_t), intent(in) :: committed_owner
    real(real64), intent(in) :: event_density(:),consolidation_density(:),rate_per_mm(:)
    real(real64), intent(in) :: prior_density(:),prior_theta(:),prior_head_cm(:),thickness_cm(:)
    real(real64), intent(in) :: prior_pond_cm,silt_fraction(:),clay_fraction(:),matching_slope(:)
    type(tillage_vg_parameters_t), intent(in) :: prior_vg(:)
    integer, intent(in) :: n_model,redistribution_mode
    type(tillage_compatibility_t), intent(in) :: compatibility
    type(tillage_event_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status
    type(tillage_owner_state_t) :: proposed_owner
    type(tillage_event_candidate_t) :: proposed
    real(real64), allocatable :: new_retention(:)
    real(real64) :: se
    integer :: owner_status,event_index,n,i,transform_status,bind_status

    candidate = tillage_event_candidate_t()
    candidate%owner = committed_owner
    status = TILLAGE_TRANSACTION_INVALID
    if (incompatible(compatibility)) return
    n = size(prior_density)
    if (n < 1 .or. size(event_density) /= n .or. size(consolidation_density) /= n .or. &
        size(rate_per_mm) /= n .or. size(prior_theta) /= n .or. size(prior_head_cm) /= n .or. &
        size(thickness_cm) /= n .or. size(prior_vg) /= n .or. size(silt_fraction) /= n .or. &
        size(clay_fraction) /= n .or. size(matching_slope) /= n) return
    if (committed_owner%previous_event < 1) return
    call advance_tillage_owner(days,t0,t1,accepted_rain_cm,committed_owner,proposed_owner, &
         event_index,owner_status)
    if (owner_status == TILLAGE_OWNER_SPLIT_REQUIRED) then
      status = TILLAGE_TRANSACTION_SPLIT
      return
    end if
    if (owner_status /= TILLAGE_OWNER_OK .or. event_index /= 0) return
    call consolidate_tillage_density(event_density,consolidation_density,rate_per_mm, &
         proposed_owner%accepted_net_rain_since_event_cm,proposed%density,transform_status)
    if (transform_status /= TILLAGE_OK) return
    proposed%owner = proposed_owner
    allocate(proposed%hydraulic_parameters(n),new_retention(n))
    do i=1,n
      if (.not. ieee_is_finite(prior_head_cm(i))) return
      call transform_tillage_vg(prior_vg(i),prior_density(i),proposed%density(i),n_model, &
           silt_fraction(i),clay_fraction(i),matching_slope(i), &
           proposed%hydraulic_parameters(i),transform_status)
      if (transform_status /= TILLAGE_OK) return
      if (prior_head_cm(i) >= 0.0_real64) then
        new_retention(i) = proposed%hydraulic_parameters(i)%theta_saturated
      else
        se = (1.0_real64+(proposed%hydraulic_parameters(i)%alpha*abs(prior_head_cm(i)))** &
             proposed%hydraulic_parameters(i)%n)**(-proposed%hydraulic_parameters(i)%m)
        new_retention(i) = proposed%hydraulic_parameters(i)%theta_residual+ &
             (proposed%hydraulic_parameters(i)%theta_saturated- &
              proposed%hydraulic_parameters(i)%theta_residual)*se
      end if
      if (.not. ieee_is_finite(new_retention(i))) return
    end do
    call bind_tillage_hydraulic_candidate(prior_theta,prior_pond_cm,new_retention, &
         thickness_cm,proposed%hydraulic_parameters,redistribution_mode,proposed%hydraulic,bind_status)
    if (bind_status /= TILLAGE_BIND_OK) return
    candidate = proposed
    status = TILLAGE_TRANSACTION_OK
  end subroutine

  pure logical function incompatible(compatibility)
    type(tillage_compatibility_t), intent(in) :: compatibility
    incompatible = compatibility%hysteresis_enabled .or. compatibility%solute_enabled .or. &
         compatibility%physical_oxygen_enabled .or. compatibility%macropore_enabled .or. &
         compatibility%extended_saturated_conductivity .or. &
         compatibility%vertical_discretization_enabled
  end function
end module
