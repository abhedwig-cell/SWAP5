module mod_rossfast_d3r_kernel_model_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_model_t, kernel_parameters_t
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_model_t, rossfast_d3r_trial_kernel_t, &
       rossfast_d3r_material_t, ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM, bind_rossfast_d3r_model
  implicit none
  private

  ! F-ROSS05 transport parameters. Scientific/material admission remains owned
  ! by F-ROSS02 bind_rossfast_d3r_model; this carrier only makes that already
  ! qualified contract consumable by the generic F-KT kernel_model_t seam.
  type, extends(kernel_parameters_t), public :: rossfast_d3r_kernel_parameters_t
    type(rossfast_d3r_material_t) :: material
    real(real64) :: cell_thickness_cm(ROSSFAST_D3R_N_CELLS) = ROSSFAST_D3R_DZ_CM
    integer :: equal_internal_substeps = 8
  end type rossfast_d3r_kernel_parameters_t

  type, extends(kernel_model_t), public :: rossfast_d3r_kernel_model_adapter_t
    private
    type(rossfast_d3r_model_t) :: delegate
    class(rossfast_d3r_trial_kernel_t), pointer :: trial_kernel => null()
    logical :: configured = .false.
  contains
    procedure, public :: bind_trial_kernel => rossfast_kernel_model_bind_trial_kernel
    procedure :: configure_parameters => rossfast_kernel_model_configure_parameters
    procedure :: execution_admitted => rossfast_kernel_model_execution_admitted
    procedure :: prepare_interval => rossfast_kernel_model_prepare_interval
    procedure :: advance => rossfast_kernel_model_advance
    procedure :: storage => rossfast_kernel_model_storage
    procedure :: temporal_error => rossfast_kernel_model_temporal_error
    procedure :: storage_accounting_status => rossfast_kernel_model_storage_accounting_status
  end type rossfast_d3r_kernel_model_adapter_t

contains

  subroutine rossfast_kernel_model_bind_trial_kernel(self, kernel, valid)
    class(rossfast_d3r_kernel_model_adapter_t), intent(inout) :: self
    class(rossfast_d3r_trial_kernel_t), target, intent(in) :: kernel
    logical, intent(out) :: valid

    self%trial_kernel => kernel
    self%configured = .false.
    valid = associated(self%trial_kernel)
  end subroutine rossfast_kernel_model_bind_trial_kernel

  logical function rossfast_kernel_model_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(rossfast_d3r_kernel_model_adapter_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    type(rossfast_d3r_model_t) :: probe
    logical :: binding_valid

    admitted = .false.
    if (.not. associated(self%trial_kernel)) return

    select type (parameters)
    type is (rossfast_d3r_kernel_parameters_t)
      call bind_rossfast_d3r_model(probe, self%trial_kernel, parameters%material, &
           parameters%cell_thickness_cm, parameters%equal_internal_substeps, binding_valid)
      if (.not. binding_valid) return
    class default
      return
    end select

    ! Only numerical settings that are visible at this generic admission seam
    ! are checked here. Forcing, interval and state-local envelope admission
    ! remain authoritative in the unchanged F-ROSS02 prepare/advance methods.
    if (numerical_config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE) return
    if (numerical_config%transaction%retry_scale /= ROSSFAST_D3R_RETRY_SCALE) return
    if (numerical_config%transaction%max_retries /= ROSSFAST_D3R_MAX_FULL_INDEX) return
    if (numerical_config%transaction%mass_tolerance <= 0.0_real64 .or. &
        numerical_config%transaction%mass_tolerance > ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (numerical_config%max_committed_substeps <= 0) return

    admitted = .true.
  end function rossfast_kernel_model_execution_admitted

  subroutine rossfast_kernel_model_configure_parameters(self, parameters)
    class(rossfast_d3r_kernel_model_adapter_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    logical :: valid

    self%configured = .false.
    if (.not. associated(self%trial_kernel)) return

    select type (parameters)
    type is (rossfast_d3r_kernel_parameters_t)
      call bind_rossfast_d3r_model(self%delegate, self%trial_kernel, parameters%material, &
           parameters%cell_thickness_cm, parameters%equal_internal_substeps, valid)
      self%configured = valid
    class default
      return
    end select
  end subroutine rossfast_kernel_model_configure_parameters

  subroutine rossfast_kernel_model_prepare_interval(self, forcing, interval, config)
    class(rossfast_d3r_kernel_model_adapter_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (.not. self%configured) return
    call self%delegate%prepare_interval(forcing, interval, config)
  end subroutine rossfast_kernel_model_prepare_interval

  subroutine rossfast_kernel_model_advance(self, state, t0, t1, outcome)
    class(rossfast_d3r_kernel_model_adapter_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    outcome = trial_outcome_t()
    if (.not. self%configured) return
    call self%delegate%advance(state, t0, t1, outcome)
  end subroutine rossfast_kernel_model_advance

  real(real64) function rossfast_kernel_model_storage(self, state) result(value)
    class(rossfast_d3r_kernel_model_adapter_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (.not. self%configured) then
      value = huge(0.0_real64)
      return
    end if
    value = self%delegate%storage(state)
  end function rossfast_kernel_model_storage

  real(real64) function rossfast_kernel_model_temporal_error(self, full_state, half_state) result(value)
    class(rossfast_d3r_kernel_model_adapter_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (.not. self%configured) then
      value = huge(0.0_real64)
      return
    end if
    value = self%delegate%temporal_error(full_state, half_state)
  end function rossfast_kernel_model_temporal_error

  subroutine rossfast_kernel_model_storage_accounting_status(self, state, complete, missing_mask)
    class(rossfast_d3r_kernel_model_adapter_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = huge(0_int64)
    if (.not. self%configured) return
    call self%delegate%storage_accounting_status(state, complete, missing_mask)
  end subroutine rossfast_kernel_model_storage_accounting_status

end module mod_rossfast_d3r_kernel_model_adapter
