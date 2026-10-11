module mod_root_water_uptake_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: ROOT_UPTAKE_OK = 0
  integer, parameter, public :: ROOT_UPTAKE_INVALID_PARAMETERS = 1
  integer, parameter, public :: ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: ROOT_UPTAKE_INVALID_REQUEST = 3

  real(real64), parameter, public :: ROOT_UPTAKE_NEGLIGIBLE_TRANSPIRATION = 1.0e-10_real64
  real(real64), parameter :: ROOT_UPTAKE_FRACTION_TOLERANCE_SCALE = 256.0_real64

  type, public :: root_water_uptake_parameters_t
    integer :: active_nodes = 0
    real(real64) :: hlim3l = 0.0_real64
    real(real64) :: hlim3h = 0.0_real64
    real(real64) :: hlim4 = 0.0_real64
    real(real64) :: adcrl = 0.0_real64
    real(real64) :: adcrh = 0.0_real64
    logical :: empirical_oxygen_enabled = .false.
    integer :: upper_layer_bottom_node = 0
    real(real64) :: hlim1 = 0.0_real64
    real(real64) :: hlim2u = 0.0_real64
    real(real64) :: hlim2l = 0.0_real64
  end type root_water_uptake_parameters_t

  type, public :: root_water_uptake_request_t
    real(real64) :: potential_transpiration = 0.0_real64
    integer :: rooted_nodes = 0
    real(real64), allocatable :: cumulative_root_fraction(:)
  end type root_water_uptake_request_t

  type, public :: root_water_uptake_flux_result_t
    real(real64), allocatable :: root_extraction_sink(:)
    real(real64) :: actual_uptake_total = 0.0_real64
  end type root_water_uptake_flux_result_t

  type, public :: root_water_uptake_diagnostics_t
    integer :: status = ROOT_UPTAKE_OK
    logical :: evaluated = .false.
    logical :: no_roots = .false.
    logical :: negligible_transpiration = .false.
    real(real64) :: critical_pressure_head = 0.0_real64
    real(real64) :: potential_uptake_total = 0.0_real64
    real(real64) :: drought_reduction_total = 0.0_real64
    real(real64) :: oxygen_reduction_total = 0.0_real64
    real(real64), allocatable :: potential_root_sink(:)
    real(real64), allocatable :: drought_reduction(:)
    real(real64), allocatable :: drought_reduction_factor(:)
    real(real64), allocatable :: oxygen_reduction(:)
    real(real64), allocatable :: oxygen_reduction_factor(:)
    logical :: mass_is_reconciliation_only = .true.
  end type root_water_uptake_diagnostics_t

  public :: evaluate_macro_feddes_drought_uptake

contains

  subroutine evaluate_macro_feddes_drought_uptake(parameters, hydraulic_view, request, fluxes, diagnostics)
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(root_water_uptake_request_t), intent(in) :: request
    type(root_water_uptake_flux_result_t), intent(out) :: fluxes
    type(root_water_uptake_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: hlim3, hlim2, alpdry, alpwet, qpotential, drought_sink, total_reduction, alpha_total
    integer :: node, n

    fluxes = root_water_uptake_flux_result_t()
    diagnostics = root_water_uptake_diagnostics_t()

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = ROOT_UPTAKE_INVALID_PARAMETERS
      return
    end if
    if (.not. valid_request_header(parameters, request)) then
      diagnostics%status = ROOT_UPTAKE_INVALID_REQUEST
      return
    end if

    n = parameters%active_nodes
    allocate(fluxes%root_extraction_sink(n))
    allocate(diagnostics%potential_root_sink(n))
    allocate(diagnostics%drought_reduction(n))
    allocate(diagnostics%drought_reduction_factor(n))
    allocate(diagnostics%oxygen_reduction(n))
    allocate(diagnostics%oxygen_reduction_factor(n))
    fluxes%root_extraction_sink = 0.0_real64
    diagnostics%potential_root_sink = 0.0_real64
    diagnostics%drought_reduction = 0.0_real64
    diagnostics%drought_reduction_factor = 1.0_real64
    diagnostics%oxygen_reduction = 0.0_real64
    diagnostics%oxygen_reduction_factor = 1.0_real64

    ! Preserve the legacy early-exit ordering. Neither route needs current
    ! hydraulic state or a root-distribution array.
    if (request%rooted_nodes == 0) then
      diagnostics%no_roots = .true.
      return
    end if
    if (request%potential_transpiration < ROOT_UPTAKE_NEGLIGIBLE_TRANSPIRATION) then
      diagnostics%negligible_transpiration = .true.
      return
    end if

    if (.not. valid_root_distribution(request)) then
      diagnostics%status = ROOT_UPTAKE_INVALID_REQUEST
      return
    end if
    if (.not. valid_hydraulic_view(parameters, hydraulic_view)) then
      diagnostics%status = ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW
      return
    end if

    hlim3 = critical_hlim3(parameters, request%potential_transpiration)
    diagnostics%critical_pressure_head = hlim3
    diagnostics%evaluated = .true.

    do node = 1, request%rooted_nodes
      qpotential = (request%cumulative_root_fraction(node+1) - &
                    request%cumulative_root_fraction(node)) * request%potential_transpiration
      alpdry = drought_reduction_factor(hydraulic_view%pressure_head(node), hlim3, parameters%hlim4)
      alpwet = 1.0_real64
      if (parameters%empirical_oxygen_enabled) then
        hlim2 = parameters%hlim2u
        if (node > parameters%upper_layer_bottom_node) hlim2 = parameters%hlim2l
        if (hydraulic_view%pressure_head(node) <= parameters%hlim1 .and. &
            hydraulic_view%pressure_head(node) > hlim2) then
          alpwet = (parameters%hlim1 - hydraulic_view%pressure_head(node)) / (parameters%hlim1 - hlim2)
        end if
        if (hydraulic_view%pressure_head(node) > parameters%hlim1) alpwet = 0.0_real64
      end if

      diagnostics%potential_root_sink(node) = qpotential
      diagnostics%drought_reduction_factor(node) = alpdry
      diagnostics%oxygen_reduction_factor(node) = alpwet
      drought_sink = qpotential * alpdry
      fluxes%root_extraction_sink(node) = drought_sink * alpwet

      ! Preserve B1.11 rootextraction stress attribution. The physical sink is
      ! the product of active factors, while the total reduction is apportioned
      ! in proportion to each stress deficit rather than by evaluation order.
      total_reduction = qpotential - fluxes%root_extraction_sink(node)
      alpha_total = (1.0_real64 - alpwet) + (1.0_real64 - alpdry)
      if (abs(total_reduction) <= tiny(1.0_real64)) then
        diagnostics%drought_reduction(node) = 0.0_real64
        diagnostics%oxygen_reduction(node) = 0.0_real64
      else if (alpha_total > 0.0_real64) then
        diagnostics%drought_reduction(node) = total_reduction * (1.0_real64 - alpdry) / alpha_total
        diagnostics%oxygen_reduction(node) = total_reduction * (1.0_real64 - alpwet) / alpha_total
      end if
    end do

    diagnostics%potential_uptake_total = sum(diagnostics%potential_root_sink)
    fluxes%actual_uptake_total = sum(fluxes%root_extraction_sink)
    diagnostics%drought_reduction_total = sum(diagnostics%drought_reduction)
    diagnostics%oxygen_reduction_total = sum(diagnostics%oxygen_reduction)
  end subroutine evaluate_macro_feddes_drought_uptake

  pure logical function valid_parameters(parameters) result(valid)
    type(root_water_uptake_parameters_t), intent(in) :: parameters

    valid = .false.
    if (parameters%active_nodes <= 0) return
    if (.not. ieee_is_finite(parameters%hlim3l)) return
    if (.not. ieee_is_finite(parameters%hlim3h)) return
    if (.not. ieee_is_finite(parameters%hlim4)) return
    if (.not. ieee_is_finite(parameters%adcrl)) return
    if (.not. ieee_is_finite(parameters%adcrh)) return
    if (parameters%adcrh <= parameters%adcrl) return
    if (parameters%hlim4 >= parameters%hlim3l .or. parameters%hlim4 >= parameters%hlim3h) return
    if (parameters%empirical_oxygen_enabled) then
      if (parameters%upper_layer_bottom_node < 0 .or. &
          parameters%upper_layer_bottom_node > parameters%active_nodes) return
      if (.not. ieee_is_finite(parameters%hlim1) .or. .not. ieee_is_finite(parameters%hlim2u) .or. &
          .not. ieee_is_finite(parameters%hlim2l)) return
      if (parameters%hlim1 <= parameters%hlim2u .or. parameters%hlim1 <= parameters%hlim2l) return
    end if
    valid = .true.
  end function valid_parameters

  pure logical function valid_request_header(parameters, request) result(valid)
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(root_water_uptake_request_t), intent(in) :: request

    valid = .false.
    if (.not. ieee_is_finite(request%potential_transpiration)) return
    if (request%potential_transpiration < 0.0_real64) return
    if (request%rooted_nodes < 0 .or. request%rooted_nodes > parameters%active_nodes) return
    valid = .true.
  end function valid_request_header

  pure logical function valid_root_distribution(request) result(valid)
    type(root_water_uptake_request_t), intent(in) :: request
    real(real64) :: tolerance
    integer :: node

    valid = .false.
    if (request%rooted_nodes <= 0) return
    if (.not. allocated(request%cumulative_root_fraction)) return
    if (size(request%cumulative_root_fraction) /= request%rooted_nodes + 1) return
    if (any(.not. ieee_is_finite(request%cumulative_root_fraction))) return

    tolerance = ROOT_UPTAKE_FRACTION_TOLERANCE_SCALE * epsilon(1.0_real64)
    if (abs(request%cumulative_root_fraction(1)) > tolerance) return
    if (abs(request%cumulative_root_fraction(request%rooted_nodes+1) - 1.0_real64) > tolerance) return
    do node = 1, request%rooted_nodes
      if (request%cumulative_root_fraction(node+1) < request%cumulative_root_fraction(node)) return
    end do
    valid = .true.
  end function valid_root_distribution

  pure logical function valid_hydraulic_view(parameters, hydraulic_view) result(valid)
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view

    valid = .false.
    if (hydraulic_view%active_nodes /= parameters%active_nodes) return
    if (.not. allocated(hydraulic_view%pressure_head)) return
    if (size(hydraulic_view%pressure_head) /= parameters%active_nodes) return
    if (any(.not. ieee_is_finite(hydraulic_view%pressure_head))) return
    valid = .true.
  end function valid_hydraulic_view

  pure real(real64) function critical_hlim3(parameters, potential_transpiration) result(hlim3)
    type(root_water_uptake_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: potential_transpiration

    if (potential_transpiration < parameters%adcrl) then
      hlim3 = parameters%hlim3l
    else if (potential_transpiration <= parameters%adcrh) then
      hlim3 = parameters%hlim3h + &
              ((parameters%adcrh - potential_transpiration) / (parameters%adcrh - parameters%adcrl)) * &
              (parameters%hlim3l - parameters%hlim3h)
    else
      hlim3 = parameters%hlim3h
    end if
  end function critical_hlim3

  pure real(real64) function drought_reduction_factor(pressure_head, hlim3, hlim4) result(alpdry)
    real(real64), intent(in) :: pressure_head, hlim3, hlim4

    alpdry = 1.0_real64
    if (pressure_head < hlim4) then
      alpdry = 0.0_real64
    else if (pressure_head <= hlim3) then
      alpdry = (hlim4 - pressure_head) / (hlim4 - hlim3)
    end if
  end function drought_reduction_factor

end module mod_root_water_uptake_process
