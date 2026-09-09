module mod_fkt12_mass_complete_test_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_fkt05_test_model, only: fkt05_model_t
  implicit none
  private

  ! F-KT12 keeps the deterministic F-KT05 state transition but upgrades the
  ! qualification fixture's accounting declaration. F-KT05 intentionally
  ! leaves mass-accounting completeness unspecified; that is insufficient for
  ! a persistence qualification whose restore seam must prove that it creates
  ! no transfer and does not reset or double-count starting storage.
  type, extends(fkt05_model_t), public :: fkt12_mass_complete_model_t
  contains
    procedure :: advance => fkt12_mass_complete_advance
    procedure :: storage_accounting_status => fkt12_storage_accounting_status
  end type fkt12_mass_complete_model_t

contains

  subroutine fkt12_mass_complete_advance(self, state, t0, t1, outcome)
    class(fkt12_mass_complete_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    call self%fkt05_model_t%advance(state, t0, t1, outcome)
    if (.not. outcome%solver_ok) return
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
  end subroutine fkt12_mass_complete_advance

  subroutine fkt12_storage_accounting_status(self, state, complete, missing_mask)
    class(fkt12_mass_complete_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    ! The inherited F-KT05 storage() function exposes the complete physical
    ! storage of this one-reservoir deterministic fixture. No optional storage
    ! owner exists in this test model.
    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) then
      error stop 'FKT12 unreachable mass-accounting fixture type'
    end if
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fkt12_storage_accounting_status

end module mod_fkt12_mass_complete_test_model
