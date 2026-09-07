module mod_b1_10_mass_seam
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_mass_accounting_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
  use MOD_swap_base, only: swcrop, swsnow, swmacro
  implicit none
  private

  type, public :: b1_10_mass_seam_capabilities_t
    logical :: qualified_profile_storage = .true.
    logical :: unrounded_trial_flux_input = .false.
    logical :: generic_interval_mass = .false.
  end type b1_10_mass_seam_capabilities_t

  public :: b1_10_qualified_profile_storage
  public :: b1_10_build_mass_accounting

contains

  subroutine b1_10_qualified_profile_storage(state, storage, complete)
    type(b1_10_process_state_t), intent(in) :: state
    real(real64), intent(out) :: storage
    logical, intent(out) :: complete

    storage = 0.0_real64
    complete = .false.
    if (swsnow /= 0 .or. swmacro /= 0) return
    if (swcrop == 1 .and. .not. allocated(state%crop)) return
    if (swcrop /= 1 .and. allocated(state%crop)) return

    storage = state%volact + state%pond
    if (allocated(state%crop)) storage = storage + state%crop%sicact
    complete = .true.
  end subroutine b1_10_qualified_profile_storage

  subroutine b1_10_build_mass_accounting(start_state, end_state, trial_mass, accounting)
    type(b1_10_process_state_t), intent(in) :: start_state, end_state
    type(b1_10_trial_mass_t), intent(in) :: trial_mass
    type(canonical_mass_accounting_t), intent(out) :: accounting
    logical :: start_complete, end_complete

    accounting = canonical_mass_accounting_t()
    call b1_10_qualified_profile_storage(start_state, accounting%storage_start, start_complete)
    call b1_10_qualified_profile_storage(end_state, accounting%storage_end, end_complete)
    accounting%total_in = trial_mass%total_in
    accounting%total_out = trial_mass%total_out
    accounting%complete = start_complete .and. end_complete .and. trial_mass%active .and. trial_mass%complete
    if (.not. accounting%complete) return
    accounting%residual = accounting%storage_end - accounting%storage_start - &
                          (trial_mass%total_in - trial_mass%total_out)
  end subroutine b1_10_build_mass_accounting

end module mod_b1_10_mass_seam
