module mod_fmr_rossfast_solver_selection_binding
  use mod_fmr_soil_water_application_host, only: fmr_soil_water_application_selection_t, &
       fmr_resolve_soil_water_application_model, FMR_SOIL_WATER_MODEL_REFERENCE, &
       FMR_APPLICATION_HOST_OK, FMR_APPLICATION_ROUTE_REFERENCE, &
       FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  implicit none
  private

  character(len=*), parameter, public :: FMR_ROSSFAST_SOLVER_MODEL_KEY = 'ROSSFAST_D3R'

  integer, parameter, public :: FMR_ROSSFAST_BIND_OK = 0
  integer, parameter, public :: FMR_ROSSFAST_BIND_SELECTION_FAILED = 1
  integer, parameter, public :: FMR_ROSSFAST_BIND_CONFIGURATION_MISSING = 2
  integer, parameter, public :: FMR_ROSSFAST_BIND_INITIALIZATION_FAILED = 3
  integer, parameter, public :: FMR_ROSSFAST_BIND_INTERNAL_ERROR = 4

  character(len=32), parameter :: REGISTERED_MODEL_KEYS(1) = &
       [character(len=32) :: FMR_ROSSFAST_SOLVER_MODEL_KEY]

  type, public :: fmr_rossfast_solver_selection_binding_t
    private
    type(rossfast_d3r_soil_water_solver_t) :: solver
    type(rossfast_d3r_soil_water_workspace_t) :: workspace
    logical :: selection_valid = .true.
    logical :: rossfast_selected = .false.
    logical :: explicit_selection = .false.
    character(len=32) :: model_key = FMR_SOIL_WATER_MODEL_REFERENCE
  contains
    procedure, public :: configure => fmr_rossfast_binding_configure
    procedure, public :: execution_ready => fmr_rossfast_binding_execution_ready
    procedure, public :: uses_rossfast => fmr_rossfast_binding_uses_rossfast
    procedure, public :: uses_reference => fmr_rossfast_binding_uses_reference
    procedure, public :: selection_is_explicit => fmr_rossfast_binding_selection_is_explicit
    procedure, public :: selected_model_key => fmr_rossfast_binding_selected_model_key
    procedure, public :: solve => fmr_rossfast_binding_solve
    procedure, public :: temporal_certificate_snapshot => fmr_rossfast_binding_temporal_certificate_snapshot
  end type fmr_rossfast_solver_selection_binding_t

contains

  subroutine fmr_rossfast_binding_configure(self, requested_model_key, ok, status, asset_root, material_id)
    class(fmr_rossfast_solver_selection_binding_t), intent(inout) :: self
    character(len=*), intent(in) :: requested_model_key
    logical, intent(out) :: ok
    integer, intent(out) :: status
    character(len=*), intent(in), optional :: asset_root, material_id
    type(fmr_soil_water_application_selection_t) :: selection
    logical :: initialized
    integer :: host_status, provider_status

    ok = .false.
    status = FMR_ROSSFAST_BIND_SELECTION_FAILED
    self%selection_valid = .false.
    self%rossfast_selected = .false.
    self%explicit_selection = .false.
    self%model_key = ''

    call fmr_resolve_soil_water_application_model(requested_model_key, REGISTERED_MODEL_KEYS, selection, host_status)
    if (host_status /= FMR_APPLICATION_HOST_OK) return

    self%explicit_selection = selection%explicit_selection
    self%model_key = selection%model_key

    select case (selection%route)
    case (FMR_APPLICATION_ROUTE_REFERENCE)
      if (selection%registered_index /= 0 .or. trim(selection%model_key) /= FMR_SOIL_WATER_MODEL_REFERENCE) then
        status = FMR_ROSSFAST_BIND_INTERNAL_ERROR
        return
      end if
      self%selection_valid = .true.
      status = FMR_ROSSFAST_BIND_OK
      ok = .true.

    case (FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE)
      if (selection%registered_index /= 1 .or. trim(selection%model_key) /= FMR_ROSSFAST_SOLVER_MODEL_KEY) then
        status = FMR_ROSSFAST_BIND_INTERNAL_ERROR
        return
      end if
      ! Once an explicit RossFast request is recognized, retain that identity
      ! even if configuration fails.  Callers can therefore fail closed instead
      ! of accidentally falling back to Reference execution.
      self%rossfast_selected = .true.
      if (.not. present(asset_root) .or. .not. present(material_id)) then
        status = FMR_ROSSFAST_BIND_CONFIGURATION_MISSING
        return
      end if
      if (len_trim(asset_root) == 0 .or. len_trim(material_id) == 0) then
        status = FMR_ROSSFAST_BIND_CONFIGURATION_MISSING
        return
      end if
      call self%solver%initialize(trim(asset_root), trim(material_id), initialized, provider_status)
      if (.not. initialized) then
        status = FMR_ROSSFAST_BIND_INITIALIZATION_FAILED
        return
      end if
      self%selection_valid = .true.
      status = FMR_ROSSFAST_BIND_OK
      ok = .true.

    case default
      status = FMR_ROSSFAST_BIND_INTERNAL_ERROR
    end select
  end subroutine fmr_rossfast_binding_configure

  logical function fmr_rossfast_binding_execution_ready(self) result(ready)
    class(fmr_rossfast_solver_selection_binding_t), intent(in) :: self
    ready = self%selection_valid
  end function fmr_rossfast_binding_execution_ready

  logical function fmr_rossfast_binding_uses_rossfast(self) result(selected)
    class(fmr_rossfast_solver_selection_binding_t), intent(in) :: self
    selected = self%rossfast_selected
  end function fmr_rossfast_binding_uses_rossfast

  logical function fmr_rossfast_binding_uses_reference(self) result(selected)
    class(fmr_rossfast_solver_selection_binding_t), intent(in) :: self
    selected = self%selection_valid .and. .not. self%rossfast_selected
  end function fmr_rossfast_binding_uses_reference

  logical function fmr_rossfast_binding_selection_is_explicit(self) result(explicit)
    class(fmr_rossfast_solver_selection_binding_t), intent(in) :: self
    explicit = self%explicit_selection
  end function fmr_rossfast_binding_selection_is_explicit

  function fmr_rossfast_binding_selected_model_key(self) result(model_key)
    class(fmr_rossfast_solver_selection_binding_t), intent(in) :: self
    character(len=32) :: model_key
    model_key = self%model_key
  end function fmr_rossfast_binding_selected_model_key

  subroutine fmr_rossfast_binding_solve(self, request, result)
    class(fmr_rossfast_solver_selection_binding_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(out) :: result

    result = soil_water_solve_result_t()
    if (.not. self%selection_valid .or. .not. self%rossfast_selected) return
    call self%solver%solve(request, self%workspace, result)
  end subroutine fmr_rossfast_binding_solve

  subroutine fmr_rossfast_binding_temporal_certificate_snapshot(self, available, indicator)
    class(fmr_rossfast_solver_selection_binding_t), intent(in) :: self
    logical, intent(out) :: available
    real(kind=kind(0.0d0)), intent(out) :: indicator

    available = .false.
    indicator = huge(0.0d0)
    if (.not. self%selection_valid .or. .not. self%rossfast_selected) return
    call self%solver%temporal_certificate_snapshot(available, indicator)
  end subroutine fmr_rossfast_binding_temporal_certificate_snapshot

end module mod_fmr_rossfast_solver_selection_binding
