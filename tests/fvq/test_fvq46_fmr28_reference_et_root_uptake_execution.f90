program test_fvq46_fmr28_reference_et_root_uptake_execution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_reference_et_ptra_root_input_binding, only: fmr_ptra_root_input_binding_diagnostics_t, &
       fmr_bind_reference_et_ptra_to_root_input, FMR_PTRA_ROOT_INPUT_BINDING_OK
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t, &
       fmr_evaluate_shared_crop_root_uptake, FMR_CROP_ROOT_ADAPTER_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_reference_et_root_uptake_composition, only: fmr_reference_et_root_uptake_diagnostics_t, &
       fmr_evaluate_reference_et_root_uptake, FMR_REFERENCE_ET_ROOT_UPTAKE_OK, &
       FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED, FMR_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_REJECTED
  implicit none

  real(real64), parameter :: ptra_values(4) = [0.0_real64, 0.03_real64, 0.17_real64, 0.61_real64]
  real(real64), parameter :: stale_values(3) = [-2.0_real64, 0.0_real64, 7.5_real64]
  real(real64), parameter :: heads(4,4) = reshape([ &
       -20000.0_real64, -17000.0_real64, -9000.0_real64, -3000.0_real64, &
       -17000.0_real64,  -8000.0_real64,  -600.0_real64,  -100.0_real64, &
        -1200.0_real64,   -800.0_real64,  -400.0_real64,  -100.0_real64, &
         -200.0_real64,   -150.0_real64,  -100.0_real64,   -50.0_real64], [4,4])

  type(root_water_uptake_parameters_t) :: parameters
  integer :: ih, ir, ip, is, cases

  call configure_parameters(parameters)
  cases = 0
  do ih = 1, 4
    call run_hydraulic_profile(ih, heads(:,ih), cases)
  end do
  call require(cases == 192, 'held-out active case count')
  write(*,'(A,I0)') 'FVQ46_HELD_OUT_ACTIVE_CASES=', cases
  write(*,'(A)') 'FVQ46_EXPLICIT_CHAIN_ORACLE=PASS'
  write(*,'(A)') 'FVQ46_STALE_PTRA_INDEPENDENCE=PASS'

  call run_rejection_attacks()
  call run_inactive_attack()
  call run_aba_attack()

  write(*,'(A)') 'FVQ46_FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_ORACLE PASS'

contains

  subroutine run_hydraulic_profile(profile_id, pressure, case_counter)
    integer, intent(in) :: profile_id
    real(real64), intent(in) :: pressure(4)
    integer, intent(inout) :: case_counter
    type(fmr_b110_physical_state_t) :: physical
    type(kernel_committed_state_t) :: committed
    type(crop_root_uptake_input_t) :: base_input, manual_bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(root_water_uptake_flux_result_t) :: got_flux, oracle_flux
    type(root_water_uptake_diagnostics_t) :: got_proc, oracle_proc
    type(fmr_ptra_root_input_binding_diagnostics_t) :: got_ptra, oracle_ptra
    type(fmr_crop_root_uptake_adapter_diagnostics_t) :: got_adapter, oracle_adapter
    type(fmr_root_uptake_binding_diagnostics_t) :: got_binding, oracle_binding
    type(fmr_reference_et_root_uptake_diagnostics_t) :: got_diag
    class(transaction_state_t), allocatable :: before_state, after_state
    integer(int64) :: revision_before
    integer :: root_case, ptra_case, stale_case
    logical :: ok

    call configure_physical_state(physical, pressure)
    call fmr_new_b110_committed_state(committed, 4600_int64 + int(profile_id,int64), physical, &
                                      8000.125_real64 + real(profile_id,real64)*0.03125_real64, ok)
    call require(ok, 'profile committed init')
    revision_before = committed%current_revision()
    call committed%snapshot(before_state, ok)
    call require(ok, 'profile snapshot before')

    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.

    do root_case = 1, 4
      do ptra_case = 1, 4
        et_result = reference_et_demand_result_t()
        et_result%potential_transpiration_cm_per_day = ptra_values(ptra_case)
        do stale_case = 1, 3
          call configure_root_input(base_input, root_case, stale_values(stale_case))

          call fmr_bind_reference_et_ptra_to_root_input(base_input, parameters%active_nodes, et_result, et_diag, &
                                                        manual_bound, oracle_ptra)
          call require(oracle_ptra%status == FMR_PTRA_ROOT_INPUT_BINDING_OK .and. oracle_ptra%result_produced, &
                       'oracle ptra bind')
          call fmr_evaluate_shared_crop_root_uptake(committed, parameters, manual_bound, oracle_flux, oracle_proc, &
                                                     oracle_binding, oracle_adapter)
          call require(oracle_adapter%status == FMR_CROP_ROOT_ADAPTER_OK, 'oracle execution')

          call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_input, et_result, et_diag, &
               got_flux, got_proc, got_ptra, got_adapter, got_binding, got_diag)
          call require(got_diag%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. got_diag%result_produced, &
                       'candidate execution status')
          call require(got_ptra%incoming_ptra_ignored, 'candidate stale marker')
          call require(got_diag%ptra_binding_called .and. got_diag%ptra_bound .and. got_diag%root_execution_called, &
                       'candidate stage diagnostics')
          call require(all_bits_identical(got_flux%root_extraction_sink, oracle_flux%root_extraction_sink), &
                       'node sink oracle identity')
          call require(same_bits(got_flux%actual_uptake_total, oracle_flux%actual_uptake_total), &
                       'total uptake oracle identity')
          call require(all_bits_identical(got_proc%potential_root_sink, oracle_proc%potential_root_sink), &
                       'potential sink diagnostics identity')
          call require(all_bits_identical(got_proc%drought_reduction, oracle_proc%drought_reduction), &
                       'drought diagnostics identity')
          call require(got_adapter%status == oracle_adapter%status, 'adapter status identity')
          call require(got_binding%status == oracle_binding%status, 'binding status identity')
          case_counter = case_counter + 1
        end do
      end do
    end do

    call committed%snapshot(after_state, ok)
    call require(ok, 'profile snapshot after')
    call require(committed%current_revision() == revision_before, 'profile revision unchanged')
    call require(physical_snapshot_identical(before_state, after_state), 'profile physical snapshot unchanged')
  end subroutine run_hydraulic_profile

  subroutine run_rejection_attacks()
    type(fmr_b110_physical_state_t) :: physical
    type(kernel_committed_state_t) :: committed, unavailable
    type(crop_root_uptake_input_t) :: input
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(root_water_uptake_flux_result_t) :: flux
    type(root_water_uptake_diagnostics_t) :: proc
    type(fmr_ptra_root_input_binding_diagnostics_t) :: ptra_diag
    type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapter_diag
    type(fmr_root_uptake_binding_diagnostics_t) :: binding_diag
    type(fmr_reference_et_root_uptake_diagnostics_t) :: diag
    logical :: ok

    call configure_physical_state(physical, heads(:,2))
    call fmr_new_b110_committed_state(committed, 4690_int64, physical, 9000.375_real64, ok)
    call require(ok, 'attack committed init')
    call configure_root_input(input, 3, 4.0_real64)
    et_result%potential_transpiration_cm_per_day = 0.17_real64

    et_diag%status = 99
    et_diag%result_produced = .false.
    call fmr_evaluate_reference_et_root_uptake(committed, parameters, input, et_result, et_diag, flux, proc, &
         ptra_diag, adapter_diag, binding_diag, diag)
    call require(diag%status == FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED, 'ET reject status')
    call require(.not. diag%root_execution_called .and. .not. diag%result_produced, 'ET reject stage containment')
    call require(.not. allocated(flux%root_extraction_sink), 'ET reject default flux')
    write(*,'(A)') 'FVQ46_UPSTREAM_ET_REJECTION_CONTAINED=PASS'

    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.
    input%cumulative_root_fraction(4) = 0.92_real64
    call fmr_evaluate_reference_et_root_uptake(committed, parameters, input, et_result, et_diag, flux, proc, &
         ptra_diag, adapter_diag, binding_diag, diag)
    call require(diag%status == FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED, 'geometry reject status')
    call require(.not. diag%root_execution_called .and. .not. diag%result_produced, 'geometry reject containment')
    call require(.not. allocated(flux%root_extraction_sink), 'geometry reject default flux')
    write(*,'(A)') 'FVQ46_INVALID_ROOT_GEOMETRY_CONTAINED=PASS'

    call configure_root_input(input, 2, -7.0_real64)
    call fmr_evaluate_reference_et_root_uptake(unavailable, parameters, input, et_result, et_diag, flux, proc, &
         ptra_diag, adapter_diag, binding_diag, diag)
    call require(diag%status == FMR_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_REJECTED, 'unavailable committed status')
    call require(diag%root_execution_called .and. .not. diag%result_produced, 'unavailable committed execution fail closed')
    call require(.not. allocated(flux%root_extraction_sink), 'unavailable committed default flux')
    write(*,'(A)') 'FVQ46_ACTIVE_UNAVAILABLE_COMMITTED_FAIL_CLOSED=PASS'
  end subroutine run_rejection_attacks

  subroutine run_inactive_attack()
    type(kernel_committed_state_t) :: unavailable
    type(crop_root_uptake_input_t) :: input
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(root_water_uptake_flux_result_t) :: flux
    type(root_water_uptake_diagnostics_t) :: proc
    type(fmr_ptra_root_input_binding_diagnostics_t) :: ptra_diag
    type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapter_diag
    type(fmr_root_uptake_binding_diagnostics_t) :: binding_diag
    type(fmr_reference_et_root_uptake_diagnostics_t) :: diag

    input = crop_root_uptake_input_t()
    et_result = reference_et_demand_result_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.
    call fmr_evaluate_reference_et_root_uptake(unavailable, parameters, input, et_result, et_diag, flux, proc, &
         ptra_diag, adapter_diag, binding_diag, diag)
    call require(diag%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. diag%result_produced, 'inactive status')
    call require(binding_diag%inactive_crop_zero_route .and. .not. binding_diag%hydraulic_view_built, &
                 'inactive no hydraulic dependency')
    call require(allocated(flux%root_extraction_sink) .and. all_zero_bits(flux%root_extraction_sink), 'inactive zero flux')
    write(*,'(A)') 'FVQ46_INACTIVE_DEPENDENCY_FREE_ZERO_ROUTE=PASS'
  end subroutine run_inactive_attack

  subroutine run_aba_attack()
    type(fmr_b110_physical_state_t) :: physical
    type(kernel_committed_state_t) :: committed
    type(crop_root_uptake_input_t) :: input
    type(reference_et_demand_result_t) :: et_a, et_b
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(root_water_uptake_flux_result_t) :: a1, b, a2
    type(root_water_uptake_diagnostics_t) :: p1, pb, p2
    type(fmr_ptra_root_input_binding_diagnostics_t) :: q1, qb, q2
    type(fmr_crop_root_uptake_adapter_diagnostics_t) :: a_diag1, a_diagb, a_diag2
    type(fmr_root_uptake_binding_diagnostics_t) :: b_diag1, b_diagb, b_diag2
    type(fmr_reference_et_root_uptake_diagnostics_t) :: d1, db, d2
    integer(int64) :: rev
    logical :: ok

    call configure_physical_state(physical, heads(:,3))
    call fmr_new_b110_committed_state(committed, 4699_int64, physical, 10000.0625_real64, ok)
    call require(ok, 'ABA committed init')
    rev = committed%current_revision()
    call configure_root_input(input, 4, 123.0_real64)
    et_a%potential_transpiration_cm_per_day = 0.03_real64
    et_b%potential_transpiration_cm_per_day = 0.61_real64
    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.

    call fmr_evaluate_reference_et_root_uptake(committed, parameters, input, et_a, et_diag, a1, p1, q1, a_diag1, b_diag1, d1)
    call fmr_evaluate_reference_et_root_uptake(committed, parameters, input, et_b, et_diag, b, pb, qb, a_diagb, b_diagb, db)
    call fmr_evaluate_reference_et_root_uptake(committed, parameters, input, et_a, et_diag, a2, p2, q2, a_diag2, b_diag2, d2)
    call require(d1%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. db%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. &
                 d2%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK, 'ABA status')
    call require(all_bits_identical(a1%root_extraction_sink, a2%root_extraction_sink), 'ABA sink identity')
    call require(same_bits(a1%actual_uptake_total, a2%actual_uptake_total), 'ABA total identity')
    call require(.not. all_bits_identical(a1%root_extraction_sink, b%root_extraction_sink), 'ABA middle differs')
    call require(committed%current_revision() == rev, 'ABA revision unchanged')
    write(*,'(A)') 'FVQ46_STATELESS_A_B_A_IDENTITY=PASS'
  end subroutine run_aba_attack

  subroutine configure_parameters(p)
    type(root_water_uptake_parameters_t), intent(out) :: p
    p%active_nodes = 4
    p%hlim3l = -800.0_real64
    p%hlim3h = -400.0_real64
    p%hlim4 = -16000.0_real64
    p%adcrl = 0.10_real64
    p%adcrh = 0.50_real64
  end subroutine configure_parameters

  subroutine configure_physical_state(s, pressure)
    type(fmr_b110_physical_state_t), intent(out) :: s
    real(real64), intent(in) :: pressure(4)
    s%active_nodes = 4
    allocate(s%pressure_head(4), s%water_content(4))
    s%pressure_head = pressure
    s%water_content = [0.09_real64, 0.16_real64, 0.24_real64, 0.31_real64]
    s%ponding_depth = 0.0_real64
    s%groundwater_level = -2.25_real64
  end subroutine configure_physical_state

  subroutine configure_root_input(x, root_case, stale_ptra)
    type(crop_root_uptake_input_t), intent(out) :: x
    integer, intent(in) :: root_case
    real(real64), intent(in) :: stale_ptra
    x = crop_root_uptake_input_t()
    x%crop_emerged = .true.
    x%potential_transpiration = stale_ptra
    allocate(x%cumulative_root_fraction(4))
    select case (root_case)
    case (1)
      x%rooted_nodes = 1
      x%cumulative_root_fraction = [0.0_real64, 1.0_real64, 1.0_real64, 1.0_real64]
    case (2)
      x%rooted_nodes = 2
      x%cumulative_root_fraction = [0.0_real64, 0.35_real64, 1.0_real64, 1.0_real64]
    case (3)
      x%rooted_nodes = 3
      x%cumulative_root_fraction = [0.0_real64, 0.10_real64, 0.55_real64, 1.0_real64]
    case (4)
      x%rooted_nodes = 3
      x%cumulative_root_fraction = [0.0_real64, 0.60_real64, 0.85_real64, 1.0_real64]
    case default
      error stop 2
    end select
  end subroutine configure_root_input

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  logical function all_bits_identical(a, b) result(equal)
    real(real64), intent(in) :: a(:), b(:)
    integer :: k
    equal = size(a) == size(b)
    if (.not. equal) return
    do k = 1, size(a)
      if (.not. same_bits(a(k), b(k))) then
        equal = .false.
        return
      end if
    end do
  end function all_bits_identical

  logical function all_zero_bits(a) result(equal)
    real(real64), intent(in) :: a(:)
    integer :: k
    equal = .true.
    do k = 1, size(a)
      if (.not. same_bits(a(k), 0.0_real64)) then
        equal = .false.
        return
      end if
    end do
  end function all_zero_bits

  logical function physical_snapshot_identical(a, b) result(equal)
    class(transaction_state_t), intent(in) :: a, b
    integer :: k
    equal = .false.
    select type (pa => a)
    type is (fmr_b110_physical_state_t)
      select type (pb => b)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        do k = 1, pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k), pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k), pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth, pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level, pb%groundwater_level)) return
        equal = .true.
      end select
    end select
  end function physical_snapshot_identical

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ46_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq46_fmr28_reference_et_root_uptake_execution
