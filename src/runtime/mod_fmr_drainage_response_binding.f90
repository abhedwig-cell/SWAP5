module mod_fmr_drainage_response_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, validate_process_hydraulic_view
  use mod_drainage_process, only: drainage_linear_parameters_t, drainage_control_t, drainage_transfer_t, &
       drainage_diagnostics_t, evaluate_single_level_linear_drainage, DRAINAGE_OK
  use mod_drainage_tabulated_response, only: drainage_tabulated_parameters_t, drainage_tabulated_result_t, &
       drainage_tabulated_diagnostics_t, evaluate_tabulated_drainage_response, DRAIN_TAB_OK
  use mod_drainage_hooghoudt_equivalent_depth, only: hooghoudt_equivalent_depth_prepared_t
  use mod_drainage_hooghoudt_ipos1_response, only: drainage_hooghoudt_ipos1_parameters_t, &
       drainage_hooghoudt_ipos1_result_t, drainage_hooghoudt_ipos1_diagnostics_t, &
       evaluate_drainage_hooghoudt_ipos1_response, DRAIN_IPOS1_OK
  use mod_drainage_hooghoudt_ipos23_response, only: drainage_hooghoudt_ipos2_parameters_t, &
       drainage_hooghoudt_ipos3_parameters_t, drainage_hooghoudt_ipos23_result_t, &
       drainage_hooghoudt_ipos23_diagnostics_t, evaluate_drainage_hooghoudt_ipos2_response, &
       evaluate_drainage_hooghoudt_ipos3_response, DRAIN_IPOS23_OK
  use mod_drainage_ernst_ipos45_preparation, only: ernst_ipos4_prepared_t, ernst_ipos5_prepared_t
  use mod_drainage_ernst_ipos45_response, only: drainage_ernst_response_t, drainage_ernst_diagnostics_t, &
       evaluate_drainage_ernst_ipos4_response, evaluate_drainage_ernst_ipos5_response, DRAIN_ERNST_OK
  use mod_drainage_empirical_interflow_response, only: empirical_interflow_parameters_t, &
       empirical_interflow_control_t, empirical_interflow_response_t, empirical_interflow_diagnostics_t, &
       evaluate_empirical_interflow_response, INTERFLOW_OK
  use mod_drainage_multilevel_aggregation, only: drainage_level_exchange_t, drainage_multilevel_aggregate_t, &
       drainage_multilevel_diagnostics_t, aggregate_drainage_levels, DRAINAGE_AGGREGATION_OK
  implicit none
  private

  integer, parameter, public :: FMR_DRAIN_VARIANT_LINEAR = 1
  integer, parameter, public :: FMR_DRAIN_VARIANT_TABULATED = 2
  integer, parameter, public :: FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS1 = 3
  integer, parameter, public :: FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS2 = 4
  integer, parameter, public :: FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS3 = 5
  integer, parameter, public :: FMR_DRAIN_VARIANT_ERNST_IPOS4 = 6
  integer, parameter, public :: FMR_DRAIN_VARIANT_ERNST_IPOS5 = 7
  integer, parameter, public :: FMR_DRAIN_VARIANT_EMPIRICAL_INTERFLOW = 8

  integer, parameter, public :: FMR_DRAIN_BIND_OK = 0
  integer, parameter, public :: FMR_DRAIN_BIND_INVALID_CONFIGURATION = 1
  integer, parameter, public :: FMR_DRAIN_BIND_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: FMR_DRAIN_BIND_UNSUPPORTED_VARIANT = 3
  integer, parameter, public :: FMR_DRAIN_BIND_PROCESS_REJECTED = 4
  integer, parameter, public :: FMR_DRAIN_BIND_NONFINITE_RESPONSE = 5
  integer, parameter, public :: FMR_DRAIN_BIND_AGGREGATION_REJECTED = 6
  integer, parameter, public :: FMR_DRAIN_BIND_SHAPE_MISMATCH = 7

  ! Shared immutable drainage response data.  Only the member selected by
  ! variant is physically active.  These records belong in a parameter
  ! registry, not in persistent column state.
  type, public :: fmr_drainage_response_level_parameters_t
    integer :: variant = 0
    type(drainage_linear_parameters_t) :: linear
    type(drainage_tabulated_parameters_t) :: tabulated
    type(drainage_hooghoudt_ipos1_parameters_t) :: hooghoudt_ipos1
    type(drainage_hooghoudt_ipos2_parameters_t) :: hooghoudt_ipos2
    type(drainage_hooghoudt_ipos3_parameters_t) :: hooghoudt_ipos3
    type(hooghoudt_equivalent_depth_prepared_t) :: hooghoudt_prepared
    type(ernst_ipos4_prepared_t) :: ernst_ipos4_prepared
    type(ernst_ipos5_prepared_t) :: ernst_ipos5_prepared
    type(empirical_interflow_parameters_t) :: empirical
  end type fmr_drainage_response_level_parameters_t

  ! Interval control is deliberately separate from immutable parameters.
  ! drain_head is consumed only by the linear and empirical-interflow routes.
  type, public :: fmr_drainage_response_level_control_t
    logical :: drain_head_supplied = .false.
    real(real64) :: drain_head = 0.0_real64
  end type fmr_drainage_response_level_control_t

  type, public :: fmr_drainage_response_level_diagnostics_t
    integer :: level_index = 0
    integer :: variant = 0
    integer :: binding_status = FMR_DRAIN_BIND_INVALID_CONFIGURATION
    integer :: process_status = -1
    logical :: flux_defined = .false.
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
    logical :: branch_or_nonsmooth_point = .false.
  end type fmr_drainage_response_level_diagnostics_t

  type, public :: fmr_drainage_response_diagnostics_t
    integer :: status = FMR_DRAIN_BIND_INVALID_CONFIGURATION
    logical :: evaluated = .false.
    logical :: bottom_node_lumping = .true.
    logical :: persistent_process_state = .false.
    logical :: transfer_booked_here = .false.
    logical :: aggregate_is_derived_view_only = .true.
    type(fmr_drainage_response_level_diagnostics_t), allocatable :: level(:)
    type(drainage_multilevel_aggregate_t) :: aggregate
    type(drainage_multilevel_diagnostics_t) :: aggregate_diagnostics
  end type fmr_drainage_response_diagnostics_t

  public :: evaluate_fmr_drainage_response_bottom_lumped
  public :: fmr_drainage_response_configuration_valid

contains

  logical function fmr_drainage_response_configuration_valid(parameters, controls, active_nodes) result(valid)
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    type(fmr_drainage_response_level_control_t), intent(in) :: controls(:)
    integer, intent(in) :: active_nodes
    integer :: i

    valid = active_nodes > 0 .and. size(parameters) > 0 .and. size(controls) == size(parameters)
    if (.not. valid) return
    do i = 1, size(parameters)
      select case (parameters(i)%variant)
      case (FMR_DRAIN_VARIANT_LINEAR, FMR_DRAIN_VARIANT_EMPIRICAL_INTERFLOW)
        valid = controls(i)%drain_head_supplied .and. ieee_is_finite(controls(i)%drain_head)
      case (FMR_DRAIN_VARIANT_TABULATED, FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS1, &
            FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS2, FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS3, &
            FMR_DRAIN_VARIANT_ERNST_IPOS4, FMR_DRAIN_VARIANT_ERNST_IPOS5)
        valid = .not. controls(i)%drain_head_supplied
      case default
        valid = .false.
      end select
      if (.not. valid) return
    end do
  end function fmr_drainage_response_configuration_valid

  subroutine evaluate_fmr_drainage_response_bottom_lumped(parameters, controls, hydraulic_view, qdra, diagnostics)
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    type(fmr_drainage_response_level_control_t), intent(in) :: controls(:)
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(out) :: qdra(:,:)
    type(fmr_drainage_response_diagnostics_t), intent(out) :: diagnostics

    type(drainage_level_exchange_t), allocatable :: exchanges(:)
    logical :: view_ok
    integer :: i, n, status

    diagnostics = fmr_drainage_response_diagnostics_t()
    qdra = 0.0_real64
    n = size(qdra,2)
    if (.not. fmr_drainage_response_configuration_valid(parameters, controls, n)) then
      diagnostics%status = FMR_DRAIN_BIND_INVALID_CONFIGURATION
      return
    end if
    if (size(qdra,1) /= size(parameters)) then
      diagnostics%status = FMR_DRAIN_BIND_SHAPE_MISMATCH
      return
    end if
    call validate_process_hydraulic_view(hydraulic_view, view_ok)
    if (.not. view_ok .or. hydraulic_view%active_nodes /= n) then
      diagnostics%status = FMR_DRAIN_BIND_INVALID_HYDRAULIC_VIEW
      return
    end if

    allocate(exchanges(size(parameters)), diagnostics%level(size(parameters)))
    do i = 1, size(parameters)
      call evaluate_one_level(i, parameters(i), controls(i), hydraulic_view, exchanges(i), diagnostics%level(i), status)
      if (status /= FMR_DRAIN_BIND_OK) then
        diagnostics%status = status
        qdra = 0.0_real64
        return
      end if
    end do

    call aggregate_drainage_levels(exchanges, diagnostics%aggregate, diagnostics%aggregate_diagnostics)
    if (diagnostics%aggregate_diagnostics%status /= DRAINAGE_AGGREGATION_OK) then
      diagnostics%status = FMR_DRAIN_BIND_AGGREGATION_REJECTED
      qdra = 0.0_real64
      return
    end if

    ! Frozen SWDIVD=0 B1.10 semantics: each level-integrated transfer is
    ! represented exactly once at the bottom compartment.  The aggregate is a
    ! diagnostic/derived view and is never booked as a second transfer.
    do i = 1, size(parameters)
      qdra(i,n) = exchanges(i)%signed_soil_to_drain_rate
    end do
    diagnostics%status = FMR_DRAIN_BIND_OK
    diagnostics%evaluated = .true.
  end subroutine evaluate_fmr_drainage_response_bottom_lumped

  subroutine evaluate_one_level(level_index, parameters, control, hydraulic_view, exchange, diagnostic, status)
    integer, intent(in) :: level_index
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters
    type(fmr_drainage_response_level_control_t), intent(in) :: control
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_level_exchange_t), intent(out) :: exchange
    type(fmr_drainage_response_level_diagnostics_t), intent(out) :: diagnostic
    integer, intent(out) :: status

    type(drainage_control_t) :: linear_control
    type(drainage_transfer_t) :: linear_result
    type(drainage_diagnostics_t) :: linear_diag
    type(drainage_tabulated_result_t) :: table_result
    type(drainage_tabulated_diagnostics_t) :: table_diag
    type(drainage_hooghoudt_ipos1_result_t) :: ipos1_result
    type(drainage_hooghoudt_ipos1_diagnostics_t) :: ipos1_diag
    type(drainage_hooghoudt_ipos23_result_t) :: ipos23_result
    type(drainage_hooghoudt_ipos23_diagnostics_t) :: ipos23_diag
    type(drainage_ernst_response_t) :: ernst_result
    type(drainage_ernst_diagnostics_t) :: ernst_diag
    type(empirical_interflow_control_t) :: empirical_control
    type(empirical_interflow_response_t) :: empirical_result
    type(empirical_interflow_diagnostics_t) :: empirical_diag

    exchange = drainage_level_exchange_t()
    diagnostic = fmr_drainage_response_level_diagnostics_t()
    diagnostic%level_index = level_index
    diagnostic%variant = parameters%variant
    status = FMR_DRAIN_BIND_PROCESS_REJECTED

    select case (parameters%variant)
    case (FMR_DRAIN_VARIANT_LINEAR)
      linear_control%drain_head = control%drain_head
      call evaluate_single_level_linear_drainage(parameters%linear, hydraulic_view, linear_control, linear_result, linear_diag)
      diagnostic%process_status = linear_diag%status
      if (linear_diag%status /= DRAINAGE_OK) return
      call bind_result(linear_result%soil_to_drain_rate, linear_result%derivative_defined, &
           linear_result%dq_dgroundwater_level, linear_diag%activation_kink)

    case (FMR_DRAIN_VARIANT_TABULATED)
      call evaluate_tabulated_drainage_response(parameters%tabulated, hydraulic_view, table_result, table_diag)
      diagnostic%process_status = table_diag%status
      if (table_diag%status /= DRAIN_TAB_OK) return
      call bind_result(table_result%signed_soil_to_drain_rate, table_result%derivative_defined, &
           table_result%dq_dgroundwater_level, table_diag%at_table_knot)

    case (FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS1)
      call evaluate_drainage_hooghoudt_ipos1_response(parameters%hooghoudt_ipos1, hydraulic_view, ipos1_result, ipos1_diag)
      diagnostic%process_status = ipos1_diag%status
      if (ipos1_diag%status /= DRAIN_IPOS1_OK) return
      call bind_result(ipos1_result%signed_soil_to_drain_rate, ipos1_result%derivative_defined, &
           ipos1_result%dq_dgroundwater_level, ipos1_diag%at_exact_compatibility_cutoff)

    case (FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS2)
      call evaluate_drainage_hooghoudt_ipos2_response(parameters%hooghoudt_ipos2, parameters%hooghoudt_prepared, &
           hydraulic_view, ipos23_result, ipos23_diag)
      diagnostic%process_status = ipos23_diag%status
      if (ipos23_diag%status /= DRAIN_IPOS23_OK) return
      call bind_result(ipos23_result%signed_soil_to_drain_rate, ipos23_result%derivative_defined, &
           ipos23_result%dq_dgroundwater_level, ipos23_diag%at_exact_compatibility_cutoff)

    case (FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS3)
      call evaluate_drainage_hooghoudt_ipos3_response(parameters%hooghoudt_ipos3, parameters%hooghoudt_prepared, &
           hydraulic_view, ipos23_result, ipos23_diag)
      diagnostic%process_status = ipos23_diag%status
      if (ipos23_diag%status /= DRAIN_IPOS23_OK) return
      call bind_result(ipos23_result%signed_soil_to_drain_rate, ipos23_result%derivative_defined, &
           ipos23_result%dq_dgroundwater_level, ipos23_diag%at_exact_compatibility_cutoff)

    case (FMR_DRAIN_VARIANT_ERNST_IPOS4)
      call evaluate_drainage_ernst_ipos4_response(parameters%ernst_ipos4_prepared, hydraulic_view, ernst_result, ernst_diag)
      diagnostic%process_status = ernst_diag%status
      if (ernst_diag%status /= DRAIN_ERNST_OK) return
      call bind_result(ernst_result%signed_soil_to_drain_rate, ernst_result%derivative_defined, &
           ernst_result%dq_dgroundwater_level, ernst_diag%at_exact_compatibility_cutoff .or. ernst_diag%at_ipos4_interface_kink)

    case (FMR_DRAIN_VARIANT_ERNST_IPOS5)
      call evaluate_drainage_ernst_ipos5_response(parameters%ernst_ipos5_prepared, hydraulic_view, ernst_result, ernst_diag)
      diagnostic%process_status = ernst_diag%status
      if (ernst_diag%status /= DRAIN_ERNST_OK) return
      call bind_result(ernst_result%signed_soil_to_drain_rate, ernst_result%derivative_defined, &
           ernst_result%dq_dgroundwater_level, ernst_diag%at_exact_compatibility_cutoff)

    case (FMR_DRAIN_VARIANT_EMPIRICAL_INTERFLOW)
      empirical_control%drain_head = control%drain_head
      call evaluate_empirical_interflow_response(parameters%empirical, empirical_control, hydraulic_view, &
           empirical_result, empirical_diag)
      diagnostic%process_status = empirical_diag%status
      if (empirical_diag%status /= INTERFLOW_OK) return
      call bind_result(empirical_result%signed_soil_to_drain_rate, empirical_result%derivative_defined, &
           empirical_result%dq_dgroundwater_level, empirical_diag%at_activation .or. &
           empirical_diag%singular_activation_tangent)

    case default
      diagnostic%binding_status = FMR_DRAIN_BIND_UNSUPPORTED_VARIANT
      status = FMR_DRAIN_BIND_UNSUPPORTED_VARIANT
      return
    end select

    if (.not. exchange%flux_defined .or. .not. ieee_is_finite(exchange%signed_soil_to_drain_rate)) then
      diagnostic%binding_status = FMR_DRAIN_BIND_NONFINITE_RESPONSE
      status = FMR_DRAIN_BIND_NONFINITE_RESPONSE
      exchange = drainage_level_exchange_t()
      return
    end if
    diagnostic%binding_status = FMR_DRAIN_BIND_OK
    status = FMR_DRAIN_BIND_OK

  contains

    subroutine bind_result(flux, derivative_defined, derivative, branch_boundary)
      real(real64), intent(in) :: flux, derivative
      logical, intent(in) :: derivative_defined, branch_boundary
      exchange%level_index = level_index
      exchange%flux_defined = ieee_is_finite(flux)
      exchange%signed_soil_to_drain_rate = flux
      exchange%derivative_defined = derivative_defined .and. ieee_is_finite(derivative)
      if (exchange%derivative_defined) exchange%dq_dgroundwater_level = derivative
      exchange%branch_boundary = branch_boundary
      exchange%singular_tangent = .not. exchange%derivative_defined .and. branch_boundary
      diagnostic%flux_defined = exchange%flux_defined
      diagnostic%signed_soil_to_drain_rate = flux
      diagnostic%derivative_defined = exchange%derivative_defined
      diagnostic%dq_dgroundwater_level = exchange%dq_dgroundwater_level
      diagnostic%branch_or_nonsmooth_point = branch_boundary
    end subroutine bind_result

  end subroutine evaluate_one_level

end module mod_fmr_drainage_response_binding
