module mod_b1_10_temporal_characterization
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  implicit none
  private

  type, public :: b1_10_temporal_characterization_t
    logical :: compatible = .false.
    logical :: water_scope_complete = .false.
    logical :: optional_process_state_present = .false.
    logical :: process_scope_complete = .false.
    integer :: allocation_mismatches = 0
    real(real64) :: max_abs_h_cm = 0.0_real64
    real(real64) :: max_abs_theta = 0.0_real64
    real(real64) :: max_abs_hm1_cm = 0.0_real64
    real(real64) :: max_abs_thetm1 = 0.0_real64
    real(real64) :: abs_pond_cm = 0.0_real64
    real(real64) :: abs_pondm1_cm = 0.0_real64
    real(real64) :: abs_gwl_cm = 0.0_real64
    real(real64) :: abs_gwlm1_cm = 0.0_real64
    real(real64) :: abs_volact_cm = 0.0_real64
    real(real64) :: abs_ldwet = 0.0_real64
    real(real64) :: abs_spev = 0.0_real64
    real(real64) :: abs_saev = 0.0_real64
  end type b1_10_temporal_characterization_t

  public :: characterize_b1_10_temporal_difference

contains

  subroutine characterize_b1_10_temporal_difference(full_state, half_state, delta)
    type(b1_10_process_state_t), intent(in) :: full_state, half_state
    type(b1_10_temporal_characterization_t), intent(out) :: delta
    logical :: water_shapes_ok

    delta = b1_10_temporal_characterization_t()

    if (.not. allocated(full_state%h) .or. .not. allocated(half_state%h) .or. &
        .not. allocated(full_state%theta) .or. .not. allocated(half_state%theta) .or. &
        .not. allocated(full_state%hm1) .or. .not. allocated(half_state%hm1) .or. &
        .not. allocated(full_state%thetm1) .or. .not. allocated(half_state%thetm1)) return

    water_shapes_ok = size(full_state%h) == size(half_state%h) .and. &
                      size(full_state%theta) == size(half_state%theta) .and. &
                      size(full_state%hm1) == size(half_state%hm1) .and. &
                      size(full_state%thetm1) == size(half_state%thetm1)
    if (.not. water_shapes_ok) return

    delta%water_scope_complete = .true.
    delta%max_abs_h_cm = maxval(abs(full_state%h - half_state%h))
    delta%max_abs_theta = maxval(abs(full_state%theta - half_state%theta))
    delta%max_abs_hm1_cm = maxval(abs(full_state%hm1 - half_state%hm1))
    delta%max_abs_thetm1 = maxval(abs(full_state%thetm1 - half_state%thetm1))
    delta%abs_pond_cm = abs(full_state%pond - half_state%pond)
    delta%abs_pondm1_cm = abs(full_state%pondm1 - half_state%pondm1)
    delta%abs_gwl_cm = abs(full_state%gwl - half_state%gwl)
    delta%abs_gwlm1_cm = abs(full_state%gwlm1 - half_state%gwlm1)
    delta%abs_volact_cm = abs(full_state%volact - half_state%volact)
    delta%abs_ldwet = abs(full_state%ldwet - half_state%ldwet)
    delta%abs_spev = abs(full_state%spev - half_state%spev)
    delta%abs_saev = abs(full_state%saev - half_state%saev)

    call count_allocation_mismatch(allocated(full_state%thermal), allocated(half_state%thermal), delta)
    call count_allocation_mismatch(allocated(full_state%solute), allocated(half_state%solute), delta)
    call count_allocation_mismatch(allocated(full_state%irrigation), allocated(half_state%irrigation), delta)
    call count_allocation_mismatch(allocated(full_state%crop), allocated(half_state%crop), delta)
    call count_allocation_mismatch(allocated(full_state%wofost), allocated(half_state%wofost), delta)

    delta%optional_process_state_present = allocated(full_state%thermal) .or. allocated(half_state%thermal) .or. &
                                           allocated(full_state%solute) .or. allocated(half_state%solute) .or. &
                                           allocated(full_state%irrigation) .or. allocated(half_state%irrigation) .or. &
                                           allocated(full_state%crop) .or. allocated(half_state%crop) .or. &
                                           allocated(full_state%wofost) .or. allocated(half_state%wofost)
    delta%compatible = delta%water_scope_complete .and. delta%allocation_mismatches == 0
    delta%process_scope_complete = delta%compatible .and. .not. delta%optional_process_state_present
  end subroutine characterize_b1_10_temporal_difference

  subroutine count_allocation_mismatch(full_allocated, half_allocated, delta)
    logical, intent(in) :: full_allocated, half_allocated
    type(b1_10_temporal_characterization_t), intent(inout) :: delta
    if (full_allocated .neqv. half_allocated) delta%allocation_mismatches = delta%allocation_mismatches + 1
  end subroutine count_allocation_mismatch

end module mod_b1_10_temporal_characterization
