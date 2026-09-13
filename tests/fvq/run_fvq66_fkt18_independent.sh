#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fvq66-fkt18-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

CANDIDATE=623e633b1f8451bd849f590f796806f11e1ecbdf
CANDIDATE_TREE=47826cb69e04c46b8739bcf953ac26db80b5ff3e
CURRENT_CANONICAL=267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
KERNEL_BLOB=c7c5b7d3357e4e6739c8f647d6232baca45563e6
fail() { echo "FVQ66_FAIL:$*" >&2; exit 1; }

[[ "$(git show -s --format=%T "$CANDIDATE")" == "$CANDIDATE_TREE" ]] || fail 'immutable candidate tree mismatch'
[[ "$(git rev-parse "$CANDIDATE:src/transaction/mod_transaction_reference.f90")" == "$TX_BLOB" ]] || fail 'candidate transaction blob mismatch'
[[ "$(git rev-parse "$CURRENT_CANONICAL:src/transaction/mod_transaction_reference.f90")" == "$TX_BLOB" ]] || fail 'current canonical transaction blob drift'
[[ "$(git rev-parse "$CANDIDATE:src/kernel/mod_kernel_transactions.f90")" == "$KERNEL_BLOB" ]] || fail 'candidate kernel blob mismatch'
[[ "$(git rev-parse "$CURRENT_CANONICAL:src/kernel/mod_kernel_transactions.f90")" == "$KERNEL_BLOB" ]] || fail 'current canonical kernel admission surface drift'
if git diff --name-only "$CANDIDATE"...HEAD | grep -q '^src/'; then
  fail 'qualification branch modifies production source'
fi
echo "FVQ66_IMMUTABLE_CANDIDATE_TREE=PASS:$CANDIDATE_TREE"
echo "FVQ66_TRANSACTION_BLOB=PASS:$TX_BLOB"
echo "FVQ66_KERNEL_BLOB=PASS:$KERNEL_BLOB"
echo "FVQ66_CURRENT_CANONICAL_ADMISSION_SURFACE_BLOBS=PASS:$CURRENT_CANONICAL"
echo 'FVQ66_PRODUCTION_SOURCE_CHANGED_BY_VQ=NO'

cat > "$BUILD/oracle.f90" <<'F90'
module fvq66_oracle_support
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_ACTIVE_CONTRIBUTION, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_model_t, kernel_parameters_t
  implicit none
  private

  integer, parameter, public :: S_COMPLETE=0, S_INCOMPLETE=1, S_MASK=2, S_OUTSIDE=3, &
       S_NAN=4, S_INF=5, S_RECOVER=6, S_ALT_INCOMPLETE=7, S_WITHIN=8
  real(real64), parameter, public :: MASS_TOL=1.0e-8_real64

  type, extends(transaction_state_t), public :: q_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => q_clone
  end type q_state_t

  type, extends(kernel_parameters_t), public :: q_parameters_t
  end type q_parameters_t

  type, extends(canonical_forcing_t), public :: q_forcing_t
  end type q_forcing_t

  type, extends(kernel_model_t), public :: q_model_t
    integer :: scenario = S_COMPLETE
    integer :: advance_calls = 0
    integer :: calls_per_attempt = 3
  contains
    procedure :: advance => q_advance
    procedure :: storage => q_storage
    procedure :: storage_accounting_status => q_storage_accounting_status
    procedure :: temporal_error => q_temporal_error
    procedure :: prepare_interval => q_prepare_interval
    procedure :: configure_parameters => q_configure_parameters
    procedure :: execution_admitted => q_execution_admitted
  end type q_model_t

  public :: make_state, water_of

contains
  subroutine q_clone(self, copy)
    class(q_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(q_state_t :: copy)
    select type (copy)
    type is (q_state_t)
      copy = self
    class default
      error stop 'FVQ66 clone failure'
    end select
  end subroutine q_clone

  subroutine make_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(q_state_t :: state)
    select type (state)
    type is (q_state_t)
      state%water = water
    class default
      error stop 'FVQ66 state allocation failure'
    end select
  end subroutine make_state

  real(real64) function water_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    select type (state)
    type is (q_state_t)
      value = state%water
    class default
      error stop 'FVQ66 state inspection failure'
    end select
  end function water_of

  subroutine q_advance(self, state, t0, t1, outcome)
    class(q_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt
    integer :: attempt

    self%advance_calls = self%advance_calls + 1
    attempt = (self%advance_calls - 1) / max(1, self%calls_per_attempt) + 1
    dt = t1 - t0
    select type (state)
    type is (q_state_t)
      state%water = state%water + dt
    class default
      error stop 'FVQ66 advance state type failure'
    end select

    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64

    select case (self%scenario)
    case (S_INCOMPLETE)
      outcome%mass_accounting_complete = .false.
    case (S_MASK)
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    case (S_OUTSIDE)
      outcome%mass_in = outcome%mass_in + 1.0e-5_real64
    case (S_NAN)
      outcome%mass_in = ieee_value(0.0_real64, ieee_quiet_nan)
    case (S_INF)
      outcome%mass_out = ieee_value(0.0_real64, ieee_positive_inf)
    case (S_RECOVER)
      if (attempt == 1) outcome%mass_accounting_complete = .false.
    case (S_ALT_INCOMPLETE)
      outcome%mass_accounting_complete = .false.
      outcome%alternative_solver_calls = 1
    case (S_WITHIN)
      outcome%mass_in = outcome%mass_in + 1.0e-10_real64
    case default
      continue
    end select
  end subroutine q_advance

  real(real64) function q_storage(self, state) result(value)
    class(q_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%advance_calls < 0) error stop 'FVQ66 impossible call counter'
    select type (state)
    type is (q_state_t)
      value = state%water
    class default
      error stop 'FVQ66 storage type failure'
    end select
  end function q_storage

  subroutine q_storage_accounting_status(self, state, complete, missing_mask)
    class(q_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%advance_calls < 0 .or. .not. same_type_as(state,state)) error stop 'FVQ66 status failure'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine q_storage_accounting_status

  real(real64) function q_temporal_error(self, full_state, half_state) result(value)
    class(q_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%advance_calls < 0 .or. .not. same_type_as(full_state,half_state)) error stop 'FVQ66 temporal type failure'
    value = 0.0_real64
  end function q_temporal_error

  subroutine q_prepare_interval(self, forcing, interval, config)
    class(q_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(forcing,forcing) .or. interval%t1 <= interval%t0) error stop 'FVQ66 prepare failure'
    if (config%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE) then
      self%calls_per_attempt = 1
    else
      self%calls_per_attempt = 3
    end if
  end subroutine q_prepare_interval

  subroutine q_configure_parameters(self, parameters)
    class(q_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(parameters,parameters)) error stop 'FVQ66 parameter failure'
    if (self%advance_calls < 0) error stop 'FVQ66 model failure'
  end subroutine q_configure_parameters

  logical function q_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(q_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    admitted = same_type_as(parameters,parameters) .and. self%advance_calls >= 0 .and. &
         numerical_config%max_committed_substeps > 0
  end function q_execution_admitted
end module fvq66_oracle_support

program test_fvq66_fkt18_independent
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_ROUTE_NONE, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_INVALID_CANDIDATE
  use fvq66_oracle_support
  implicit none

  call rejection_case(S_INCOMPLETE, .false., 'external-incomplete-zero-residual')
  call rejection_case(S_MASK, .false., 'external-nonzero-mask')
  call rejection_case(S_OUTSIDE, .false., 'external-residual-outside')
  call rejection_case(S_NAN, .false., 'external-NaN')
  call rejection_case(S_INF, .false., 'external-Inf')
  call acceptance_case(S_COMPLETE, .false., 'external-complete-zero')
  call acceptance_case(S_WITHIN, .false., 'external-complete-within-tolerance')
  call retry_recovery_case(.false., 'external-retry-origin')

  call rejection_case(S_INCOMPLETE, .true., 'certificate-incomplete-zero-residual')
  call rejection_case(S_MASK, .true., 'certificate-nonzero-mask')
  call rejection_case(S_OUTSIDE, .true., 'certificate-residual-outside')
  call rejection_case(S_NAN, .true., 'certificate-NaN')
  call rejection_case(S_INF, .true., 'certificate-Inf')
  call rejection_case(S_ALT_INCOMPLETE, .true., 'certificate-alternative-solver-incomplete')
  call acceptance_case(S_COMPLETE, .true., 'certificate-complete-zero')
  call acceptance_case(S_WITHIN, .true., 'certificate-complete-within-tolerance')
  call retry_recovery_case(.true., 'certificate-retry-origin')

  call kernel_end_to_end_incomplete_candidate_block()

  print '(a)', 'FVQ66_FKT18_INDEPENDENT_ATTACK_MATRIX=PASS'

contains
  subroutine require(ok, message)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: message
    if (.not. ok) then
      write(*,'(a)') 'FVQ66_ASSERT_FAIL:'//trim(message)
      error stop 1
    end if
  end subroutine require

  function policy_for(cert, retries) result(policy)
    logical, intent(in) :: cert
    integer, intent(in) :: retries
    type(transaction_policy_t) :: policy
    policy%temporal_tolerance = 1.0e-12_real64
    policy%mass_tolerance = MASS_TOL
    policy%retry_scale = 0.5_real64
    policy%max_retries = retries
    if (cert) then
      policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    else
      policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    end if
  end function policy_for

  subroutine rejection_case(scenario, cert, label)
    integer, intent(in) :: scenario
    logical, intent(in) :: cert
    character(len=*), intent(in) :: label
    class(transaction_state_t), allocatable :: committed
    type(q_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial=16.0_real64

    call make_state(committed, initial)
    model%scenario = scenario
    if (cert) model%calls_per_attempt = 1
    policy = policy_for(cert, 2)
    call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, label//': accepted')
    call require(result%attempts == 3 .and. result%retries == 2, label//': retry accounting')
    call require(result%rollbacks == 3 .and. result%mass_rejections == 3, label//': rejection accounting')
    call require(result%commits == 0 .and. result%accepted_route == TX_ROUTE_NONE, label//': commit reachable')
    call require(water_of(committed) == initial, label//': committed physical state mutated')
    call require(result%accepted_t1 == 0.0_real64, label//': accepted time advanced')
    if (scenario == S_INCOMPLETE) then
      if (cert) then
        call require(abs(result%accepted_mass_residual) > huge(0.0_real64)/2.0_real64, label//': unexpected accepted residual publication')
      else
        call require(abs(result%full_mass_residual) <= 1.0e-14_real64 .and. &
             abs(result%half_mass_residual) <= 1.0e-14_real64, label//': incomplete witness not zero residual')
      end if
    end if
    if (scenario == S_ALT_INCOMPLETE) call require(result%alternative_solver_calls == 3, label//': alternative route not exercised')
    print '(a)', 'FVQ66_REJECT=PASS:'//trim(label)
  end subroutine rejection_case

  subroutine acceptance_case(scenario, cert, label)
    integer, intent(in) :: scenario
    logical, intent(in) :: cert
    character(len=*), intent(in) :: label
    class(transaction_state_t), allocatable :: committed
    type(q_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(committed, 4.0_real64)
    model%scenario = scenario
    if (cert) model%calls_per_attempt = 1
    policy = policy_for(cert, 0)
    call execute_reference_interval(model, committed, 1.0_real64, 3.0_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, label//': rejected')
    call require(result%commits == 1 .and. result%mass_rejections == 0, label//': commit/rejection accounting')
    call require(result%accepted_mass_complete, label//': accepted incomplete')
    call require(result%accepted_missing_contribution_mask == TX_MASS_MISSING_NONE, label//': accepted mask')
    call require(abs(result%accepted_mass_residual) <= MASS_TOL, label//': accepted residual outside tolerance')
    call require(abs(water_of(committed)-6.0_real64) <= 1.0e-13_real64, label//': final state')
    if (scenario == S_WITHIN) call require(abs(result%accepted_mass_residual) > 0.0_real64, label//': nonzero within-tolerance witness absent')
    print '(a)', 'FVQ66_ACCEPT=PASS:'//trim(label)
  end subroutine acceptance_case

  subroutine retry_recovery_case(cert, label)
    logical, intent(in) :: cert
    character(len=*), intent(in) :: label
    class(transaction_state_t), allocatable :: committed
    type(q_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    real(real64), parameter :: initial=11.0_real64

    call make_state(committed, initial)
    model%scenario = S_RECOVER
    if (cert) model%calls_per_attempt = 1
    policy = policy_for(cert, 2)
    call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, label//': recovery not accepted')
    call require(result%attempts == 2 .and. result%retries == 1 .and. result%rollbacks == 1, label//': retry counts')
    call require(result%mass_rejections == 1 .and. result%commits == 1, label//': mass/commit counts')
    call require(result%accepted_dt == 1.0_real64, label//': reduced dt')
    call require(water_of(committed) == initial + 1.0_real64, label//': rejected trial physically accumulated')
    call require(result%accepted_mass_complete, label//': recovery accepted incomplete')
    print '(a)', 'FVQ66_RETRY_NO_PHYSICAL_ACCUMULATION=PASS:'//trim(label)
  end subroutine retry_recovery_case

  subroutine kernel_end_to_end_incomplete_candidate_block()
    class(transaction_state_t), allocatable :: initial_state, snapshot
    type(q_parameters_t) :: parameters
    type(q_forcing_t) :: forcing
    type(q_model_t), target :: model
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    type(canonical_numerical_config_t) :: config
    logical :: initialized, available, did_commit
    integer :: commit_status
    integer(int64), parameter :: lineage=77_int64

    call make_state(initial_state, 20.0_real64)
    call committed%initialize(lineage, initial_state, initialized, 5.0_real64)
    call require(initialized, 'kernel committed initialization')
    model%scenario = S_INCOMPLETE
    model%calls_per_attempt = 1
    call executor%bind_model(model)
    config%transaction = policy_for(.true., 1)
    config%max_committed_substeps = 4
    config%progress_tolerance = 0.0_real64

    call executor%advance_interval(parameters, committed, forcing, config, 5.0_real64, 7.0_real64, &
         result, candidate, diagnostics)

    call require(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'kernel incomplete ledger status')
    call require(.not. result%completed, 'kernel incomplete ledger completed')
    call require(.not. candidate%ready(), 'kernel candidate materialized from incomplete ledger')
    call require(diagnostics%candidate_materializations == 0, 'candidate materialization counter')
    call require(diagnostics%mass_rejections == 2, 'kernel mass rejection transport')
    call require(committed%current_revision() == 0_int64, 'kernel committed revision mutated')
    call require(committed%current_time() == 5.0_real64, 'kernel committed time mutated')
    call committed%snapshot(snapshot, available)
    call require(available .and. water_of(snapshot) == 20.0_real64, 'kernel committed physical state mutated')

    call executor%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status)
    call require(.not. did_commit, 'invalid incomplete-derived candidate committed')
    call require(commit_status == KERNEL_COMMIT_STATUS_INVALID_CANDIDATE, 'invalid candidate status')
    call require(diagnostics%invalid_candidate_rejections == 1, 'invalid candidate rejection diagnostic')
    call committed%snapshot(snapshot, available)
    call require(available .and. water_of(snapshot) == 20.0_real64, 'commit rejection mutated state')
    print '(a)', 'FVQ66_KERNEL_INCOMPLETE_CANNOT_MATERIALIZE_OR_COMMIT_CANDIDATE=PASS'
  end subroutine kernel_end_to_end_incomplete_candidate_block
end program test_fvq66_fkt18_independent
F90

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_opt() {
  local opt="$1"
  local out="$BUILD/o$opt"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    src/kernel/mod_kernel_transactions.f90 \
    "$BUILD/oracle.f90" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "oracle O$opt execution"; }
  grep -Fq 'FVQ66_REJECT=PASS:external-incomplete-zero-residual' "$out/output.txt" || fail "O$opt zero-residual incomplete external"
  grep -Fq 'FVQ66_REJECT=PASS:certificate-incomplete-zero-residual' "$out/output.txt" || fail "O$opt zero-residual incomplete certificate"
  grep -Fq 'FVQ66_REJECT=PASS:external-nonzero-mask' "$out/output.txt" || fail "O$opt external mask"
  grep -Fq 'FVQ66_REJECT=PASS:certificate-nonzero-mask' "$out/output.txt" || fail "O$opt certificate mask"
  grep -Fq 'FVQ66_REJECT=PASS:external-NaN' "$out/output.txt" || fail "O$opt external NaN"
  grep -Fq 'FVQ66_REJECT=PASS:external-Inf' "$out/output.txt" || fail "O$opt external Inf"
  grep -Fq 'FVQ66_REJECT=PASS:certificate-NaN' "$out/output.txt" || fail "O$opt certificate NaN"
  grep -Fq 'FVQ66_REJECT=PASS:certificate-Inf' "$out/output.txt" || fail "O$opt certificate Inf"
  grep -Fq 'FVQ66_REJECT=PASS:certificate-alternative-solver-incomplete' "$out/output.txt" || fail "O$opt alternative solver incomplete"
  grep -Fq 'FVQ66_ACCEPT=PASS:external-complete-within-tolerance' "$out/output.txt" || fail "O$opt external positive control"
  grep -Fq 'FVQ66_ACCEPT=PASS:certificate-complete-within-tolerance' "$out/output.txt" || fail "O$opt certificate positive control"
  grep -Fq 'FVQ66_RETRY_NO_PHYSICAL_ACCUMULATION=PASS:external-retry-origin' "$out/output.txt" || fail "O$opt external retry origin"
  grep -Fq 'FVQ66_RETRY_NO_PHYSICAL_ACCUMULATION=PASS:certificate-retry-origin' "$out/output.txt" || fail "O$opt certificate retry origin"
  grep -Fq 'FVQ66_KERNEL_INCOMPLETE_CANNOT_MATERIALIZE_OR_COMMIT_CANDIDATE=PASS' "$out/output.txt" || fail "O$opt kernel candidate block"
  grep -Fq 'FVQ66_FKT18_INDEPENDENT_ATTACK_MATRIX=PASS' "$out/output.txt" || fail "O$opt final matrix"
}

run_opt 0
run_opt 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 oracle output differs'
echo 'FVQ66_GNU_FORTRAN_O0_O2_DETERMINISTIC_EQUIVALENCE=PASS'
echo 'FVQ66_FKT18_INDEPENDENT_GATE=PASS'
