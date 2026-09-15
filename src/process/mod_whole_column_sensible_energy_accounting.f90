module mod_whole_column_sensible_energy_accounting
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_linear_mixture_sensible_storage, only: &
       LMSS_OK, linear_mixture_sensible_storage_parameters_t, linear_mixture_sensible_storage_change_t, &
       initialize_linear_mixture_sensible_storage_parameters, evaluate_sensible_storage, &
       evaluate_sensible_storage_change
  use mod_energy_conservation_types, only: &
       ENERGY_CONSERVATION_OK, ENERGY_EXTERNAL_COMPONENT, energy_transfer_t, energy_storage_snapshot_t, &
       energy_balance_t, make_energy_transfer, make_energy_storage_snapshot, project_energy_balance
  implicit none
  private

  integer, parameter, public :: WCSA_OK = 0
  integer, parameter, public :: WCSA_INVALID_ARGUMENT = 1
  integer, parameter, public :: WCSA_STORAGE_FAILURE = 2
  integer, parameter, public :: WCSA_INCOMPLETE_BOUNDARY = 3
  integer, parameter, public :: WCSA_BALANCE_FAILURE = 4
  integer, parameter, public :: WCSA_NUMERIC_FAILURE = 5
  integer, parameter, public :: WCSA_REFERENCE_MISMATCH = 6

  type, public :: whole_column_sensible_boundary_t
    logical :: top_conductive_available = .false.
    real(real64) :: top_conductive_into_j_m2 = 0.0_real64
    logical :: top_advective_available = .false.
    real(real64) :: top_advective_into_j_m2 = 0.0_real64
    logical :: bottom_conductive_available = .false.
    real(real64) :: bottom_conductive_outward_j_m2 = 0.0_real64
    logical :: bottom_advective_available = .false.
    real(real64) :: bottom_advective_outward_j_m2 = 0.0_real64
    logical :: mass_carried_reference_available = .false.
    real(real64) :: mass_carried_reference_temperature_c = 0.0_real64
  contains
    procedure, public :: complete => whole_column_boundary_complete
  end type whole_column_sensible_boundary_t

  type, public :: whole_column_sensible_energy_result_t
    integer :: status = WCSA_INVALID_ARGUMENT
    integer :: node_count = 0
    logical :: storage_complete = .false.
    logical :: sensible_boundary_complete = .false.
    logical :: sensible_scope_complete = .false.
    logical :: full_energy_balance_complete = .false.
    real(real64) :: initial_storage_j_m2 = 0.0_real64
    real(real64) :: final_storage_j_m2 = 0.0_real64
    real(real64) :: exact_storage_change_j_m2 = 0.0_real64
    real(real64) :: temperature_change_component_j_m2 = 0.0_real64
    real(real64) :: composition_change_component_j_m2 = 0.0_real64
    real(real64) :: storage_decomposition_residual_j_m2 = 0.0_real64
    type(energy_balance_t) :: projected_balance
  end type whole_column_sensible_energy_result_t

  public :: evaluate_whole_column_sensible_energy

contains

  pure logical function whole_column_boundary_complete(self) result(complete)
    class(whole_column_sensible_boundary_t), intent(in) :: self
    complete = self%top_conductive_available .and. self%top_advective_available .and. &
         self%bottom_conductive_available .and. self%bottom_advective_available .and. &
         self%mass_carried_reference_available
  end function whole_column_boundary_complete

  subroutine evaluate_whole_column_sensible_energy(component_id, dz_cm, theta_sat, &
       solid_heat_capacity_j_cm3_k, theta_start, theta_end, temperature_start_c, temperature_end_c, &
       liquid_heat_capacity_j_cm3_k, gas_heat_capacity_j_cm3_k, reference_temperature_c, &
       boundary, result, status)
    integer(int64), intent(in) :: component_id
    real(real64), intent(in) :: dz_cm(:), theta_sat(:), solid_heat_capacity_j_cm3_k(:)
    real(real64), intent(in) :: theta_start(:), theta_end(:), temperature_start_c(:), temperature_end_c(:)
    real(real64), intent(in) :: liquid_heat_capacity_j_cm3_k, gas_heat_capacity_j_cm3_k
    real(real64), intent(in) :: reference_temperature_c
    type(whole_column_sensible_boundary_t), intent(in) :: boundary
    type(whole_column_sensible_energy_result_t), intent(out) :: result
    integer, intent(out) :: status

    type(linear_mixture_sensible_storage_parameters_t) :: parameters
    type(linear_mixture_sensible_storage_change_t) :: change
    type(energy_storage_snapshot_t) :: initial_snapshot, final_snapshot
    type(energy_transfer_t) :: transfers(4)
    integer(int64) :: component_ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    real(real64) :: node_initial, node_final
    integer :: i, n, local_status

    result = whole_column_sensible_energy_result_t()
    status = WCSA_INVALID_ARGUMENT

    n = size(dz_cm)
    if (component_id <= ENERGY_EXTERNAL_COMPONENT .or. n <= 0) return
    if (size(theta_sat) /= n .or. size(solid_heat_capacity_j_cm3_k) /= n .or. &
        size(theta_start) /= n .or. size(theta_end) /= n .or. &
        size(temperature_start_c) /= n .or. size(temperature_end_c) /= n) return
    if (.not. ieee_is_finite(liquid_heat_capacity_j_cm3_k) .or. &
        .not. ieee_is_finite(gas_heat_capacity_j_cm3_k) .or. &
        .not. ieee_is_finite(reference_temperature_c)) return
    if (.not. boundary_values_finite(boundary)) return

    result%node_count = n
    do i = 1, n
      call initialize_linear_mixture_sensible_storage_parameters(theta_sat(i), &
           solid_heat_capacity_j_cm3_k(i), liquid_heat_capacity_j_cm3_k, gas_heat_capacity_j_cm3_k, &
           reference_temperature_c, parameters, local_status)
      if (local_status /= LMSS_OK) then
        status = WCSA_STORAGE_FAILURE
        result%status = status
        return
      end if

      call evaluate_sensible_storage(dz_cm(i), theta_start(i), temperature_start_c(i), &
           parameters, node_initial, local_status)
      if (local_status /= LMSS_OK) then
        status = WCSA_STORAGE_FAILURE
        result%status = status
        return
      end if
      call evaluate_sensible_storage(dz_cm(i), theta_end(i), temperature_end_c(i), &
           parameters, node_final, local_status)
      if (local_status /= LMSS_OK) then
        status = WCSA_STORAGE_FAILURE
        result%status = status
        return
      end if
      call evaluate_sensible_storage_change(dz_cm(i), theta_start(i), theta_end(i), &
           temperature_start_c(i), temperature_end_c(i), parameters, change, local_status)
      if (local_status /= LMSS_OK) then
        status = WCSA_STORAGE_FAILURE
        result%status = status
        return
      end if

      result%initial_storage_j_m2 = result%initial_storage_j_m2 + node_initial
      result%final_storage_j_m2 = result%final_storage_j_m2 + node_final
      result%exact_storage_change_j_m2 = result%exact_storage_change_j_m2 + change%exact_change_j_m2
      result%temperature_change_component_j_m2 = result%temperature_change_component_j_m2 + &
           change%temperature_change_component_j_m2
      result%composition_change_component_j_m2 = result%composition_change_component_j_m2 + &
           change%composition_change_component_j_m2
      result%storage_decomposition_residual_j_m2 = result%storage_decomposition_residual_j_m2 + &
           change%decomposition_residual_j_m2

      if (.not. storage_result_finite(result)) then
        status = WCSA_NUMERIC_FAILURE
        result%status = status
        return
      end if
    end do

    result%storage_complete = .true.
    result%sensible_boundary_complete = boundary%complete()
    if (.not. result%sensible_boundary_complete) then
      status = WCSA_INCOMPLETE_BOUNDARY
      result%status = status
      return
    end if
    if (.not. nearly_same(boundary%mass_carried_reference_temperature_c, reference_temperature_c)) then
      status = WCSA_REFERENCE_MISMATCH
      result%status = status
      return
    end if

    component_ids(1) = component_id
    initial_energy(1) = result%initial_storage_j_m2
    final_energy(1) = result%final_storage_j_m2
    initial_snapshot = make_energy_storage_snapshot(component_ids, initial_energy, local_status)
    if (local_status /= ENERGY_CONSERVATION_OK) then
      status = WCSA_BALANCE_FAILURE
      result%status = status
      return
    end if
    final_snapshot = make_energy_storage_snapshot(component_ids, final_energy, local_status)
    if (local_status /= ENERGY_CONSERVATION_OK) then
      status = WCSA_BALANCE_FAILURE
      result%status = status
      return
    end if

    call make_oriented_transfer(boundary%top_conductive_into_j_m2, .true., component_id, transfers(1), local_status)
    if (local_status /= ENERGY_CONSERVATION_OK) then
      status = WCSA_BALANCE_FAILURE; result%status = status; return
    end if
    call make_oriented_transfer(boundary%top_advective_into_j_m2, .true., component_id, transfers(2), local_status)
    if (local_status /= ENERGY_CONSERVATION_OK) then
      status = WCSA_BALANCE_FAILURE; result%status = status; return
    end if
    call make_oriented_transfer(boundary%bottom_conductive_outward_j_m2, .false., component_id, transfers(3), local_status)
    if (local_status /= ENERGY_CONSERVATION_OK) then
      status = WCSA_BALANCE_FAILURE; result%status = status; return
    end if
    call make_oriented_transfer(boundary%bottom_advective_outward_j_m2, .false., component_id, transfers(4), local_status)
    if (local_status /= ENERGY_CONSERVATION_OK) then
      status = WCSA_BALANCE_FAILURE; result%status = status; return
    end if

    call project_energy_balance(initial_snapshot, final_snapshot, transfers, component_ids, &
         result%projected_balance, local_status)
    if (local_status /= ENERGY_CONSERVATION_OK .or. .not. result%projected_balance%available) then
      status = WCSA_BALANCE_FAILURE
      result%status = status
      return
    end if

    if (.not. nearly_same(result%exact_storage_change_j_m2, result%projected_balance%delta_storage_j_m2)) then
      status = WCSA_BALANCE_FAILURE
      result%status = status
      return
    end if

    result%sensible_scope_complete = .true.
    ! Deliberate hard nonclaim: latent heat, radiation, freeze/thaw and vapor
    ! energy are outside this bounded sensible-energy accounting capability.
    result%full_energy_balance_complete = .false.
    status = WCSA_OK
    result%status = status
  end subroutine evaluate_whole_column_sensible_energy

  subroutine make_oriented_transfer(oriented_energy_j_m2, positive_means_into, component_id, transfer, status)
    real(real64), intent(in) :: oriented_energy_j_m2
    logical, intent(in) :: positive_means_into
    integer(int64), intent(in) :: component_id
    type(energy_transfer_t), intent(out) :: transfer
    integer, intent(out) :: status
    integer(int64) :: source_id, target_id
    real(real64) :: amount

    if (positive_means_into .eqv. (oriented_energy_j_m2 >= 0.0_real64)) then
      source_id = ENERGY_EXTERNAL_COMPONENT
      target_id = component_id
    else
      source_id = component_id
      target_id = ENERGY_EXTERNAL_COMPONENT
    end if
    amount = abs(oriented_energy_j_m2)
    transfer = make_energy_transfer(source_id, target_id, amount, status)
  end subroutine make_oriented_transfer

  pure logical function boundary_values_finite(boundary) result(valid)
    type(whole_column_sensible_boundary_t), intent(in) :: boundary
    valid = ieee_is_finite(boundary%top_conductive_into_j_m2) .and. &
         ieee_is_finite(boundary%top_advective_into_j_m2) .and. &
         ieee_is_finite(boundary%bottom_conductive_outward_j_m2) .and. &
         ieee_is_finite(boundary%bottom_advective_outward_j_m2) .and. &
         ieee_is_finite(boundary%mass_carried_reference_temperature_c)
  end function boundary_values_finite

  pure logical function storage_result_finite(result) result(valid)
    type(whole_column_sensible_energy_result_t), intent(in) :: result
    valid = ieee_is_finite(result%initial_storage_j_m2) .and. &
         ieee_is_finite(result%final_storage_j_m2) .and. &
         ieee_is_finite(result%exact_storage_change_j_m2) .and. &
         ieee_is_finite(result%temperature_change_component_j_m2) .and. &
         ieee_is_finite(result%composition_change_component_j_m2) .and. &
         ieee_is_finite(result%storage_decomposition_residual_j_m2)
  end function storage_result_finite

  pure logical function nearly_same(a, b) result(equal)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    equal = abs(a - b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function nearly_same

end module mod_whole_column_sensible_energy_accounting
