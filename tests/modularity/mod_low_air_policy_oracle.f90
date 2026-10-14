module mod_low_air_policy_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts
  implicit none
  private

  type, extends(canonical_state_t), public :: fci04_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fci04_clone
  end type fci04_state_t

  type, extends(canonical_forcing_t), public :: fci04_forcing_t
    real(real64) :: k = 1.0_real64
  end type fci04_forcing_t

  type, extends(canonical_physical_model_t), public :: fci04_model_t
    real(real64) :: k = 1.0_real64
    logical :: extreme_indicator = .false.
    logical :: inject_mass_defect = .false.
    real(real64) :: mass_defect = 0.0_real64
    integer :: prepare_calls = 0
  contains
    procedure :: storage_accounting_status => mass_status
    procedure :: advance => fci04_advance
    procedure :: storage => fci04_storage
    procedure :: temporal_error => fci04_temporal_error
    procedure :: prepare_interval => fci04_prepare_interval
  end type fci04_model_t

contains

  subroutine mass_status(self,state,complete,missing_mask)
    class(fci04_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    complete=.true.;missing_mask=0_int64
  end subroutine

  subroutine fci04_clone(self, copy)
    class(fci04_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fci04_state_t :: copy)
    select type(copy)
    type is(fci04_state_t)
      copy%water = self%water
    end select
  end subroutine fci04_clone

  subroutine fci04_prepare_interval(self, forcing, interval, config)
    class(fci04_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    self%prepare_calls = self%prepare_calls + 1
    select type(forcing)
    type is(fci04_forcing_t)
      self%k = forcing%k
    class default
      error stop 'FCI04 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FCI04 prepare got invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FCI04 prepare got invalid config'
  end subroutine fci04_prepare_interval

  subroutine fci04_advance(self, state, t0, t1, outcome)
    class(fci04_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water

    outcome = trial_outcome_t()
    dt = t1 - t0
    select type(state)
    type is(fci04_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - self%k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + self%mass_defect
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = 0_int64
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FCI04 unexpected state type'
    end select
  end subroutine fci04_advance

  function fci04_storage(self, state) result(value)
    class(fci04_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(state)
    type is(fci04_state_t)
      value = state%water
    class default
      error stop 'FCI04 unexpected state type'
    end select
  end function fci04_storage

  function fci04_temporal_error(self, full_state, half_state) result(value)
    class(fci04_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(full_state)
    type is(fci04_state_t)
      full_water = full_state%water
    class default
      error stop 'FCI04 unexpected full state type'
    end select
    select type(half_state)
    type is(fci04_state_t)
      half_water = half_state%water
    class default
      error stop 'FCI04 unexpected half state type'
    end select
    value = abs(half_water - full_water)
    if (self%extreme_indicator) then
      value = huge(0.0_real64)
      if (abs(half_water-full_water) < 0.01_real64) value = tiny(0.0_real64) / 1.e10_real64
    end if
  end function fci04_temporal_error

end module mod_low_air_policy_oracle

