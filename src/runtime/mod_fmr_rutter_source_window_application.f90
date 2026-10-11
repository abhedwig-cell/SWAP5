module mod_fmr_rutter_source_window_application
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_interception_source_window_runtime, only: interception_source_window_t
  use mod_rutter_interception_process, only: rutter_interval_input_t, rutter_interval_result_t, rutter_diagnostics_t
  use mod_rutter_source_window_processor, only: rutter_source_state_t, rutter_source_trial_t, &
       prepare_rutter_source_trial, RUTTER_WINDOW_OK
  use mod_fmr_rutter_output_application_binding, only: fmr_rutter_output_binding_diagnostics_t, &
       fmr_bind_rutter_surface_fluxes_to_dynamic_top, fmr_bind_rutter_ptra_to_root_input, FMR_RUTTER_BIND_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  implicit none
  private

  integer, parameter, public :: FMR_RUTTER_APP_OK = 0
  integer, parameter, public :: FMR_RUTTER_APP_SOURCE_REJECTED = 1
  integer, parameter, public :: FMR_RUTTER_APP_SURFACE_REJECTED = 2
  integer, parameter, public :: FMR_RUTTER_APP_ROOT_REJECTED = 3

  type, public :: fmr_rutter_source_application_diagnostics_t
    integer :: status = FMR_RUTTER_APP_OK
    integer :: source_status = RUTTER_WINDOW_OK
    type(rutter_diagnostics_t) :: rutter
    type(fmr_rutter_output_binding_diagnostics_t) :: surface
    type(fmr_rutter_output_binding_diagnostics_t) :: root
    logical :: result_produced = .false.
  end type fmr_rutter_source_application_diagnostics_t

  public :: fmr_prepare_rutter_source_window_application

contains

  ! Prepare canopy physics and both already-qualified application bindings as
  ! one candidate. The caller keeps the returned trial outside Richards
  ! scratch and accepts it only with the enclosing hydrological transaction.
  subroutine fmr_prepare_rutter_source_window_application(window, accepted_state, endpoint, forcing_template, &
      base_top_request, base_root_input, active_nodes, result, source_trial, bound_top_request, bound_root_input, &
      diagnostics)
    type(interception_source_window_t), intent(in) :: window
    type(rutter_source_state_t), intent(in) :: accepted_state
    real(real64), intent(in) :: endpoint
    type(rutter_interval_input_t), intent(in) :: forcing_template
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_top_request
    type(crop_root_uptake_input_t), intent(in) :: base_root_input
    integer, intent(in) :: active_nodes
    type(rutter_interval_result_t), intent(out) :: result
    type(rutter_source_trial_t), intent(out) :: source_trial
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_top_request
    type(crop_root_uptake_input_t), intent(out) :: bound_root_input
    type(fmr_rutter_source_application_diagnostics_t), intent(out) :: diagnostics
    type(rutter_diagnostics_t) :: process_diagnostics

    result = rutter_interval_result_t()
    source_trial = rutter_source_trial_t()
    bound_top_request = b110_dynamic_top_boundary_request_t()
    bound_root_input = crop_root_uptake_input_t()
    diagnostics = fmr_rutter_source_application_diagnostics_t()

    call prepare_rutter_source_trial(window, accepted_state, endpoint, forcing_template, result, source_trial, &
                                     process_diagnostics, diagnostics%source_status)
    diagnostics%rutter = process_diagnostics
    if (diagnostics%source_status /= RUTTER_WINDOW_OK .or. .not. process_diagnostics%result_produced) then
      diagnostics%status = FMR_RUTTER_APP_SOURCE_REJECTED
      result = rutter_interval_result_t()
      source_trial = rutter_source_trial_t()
      return
    end if

    call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base_top_request, result, process_diagnostics, &
                                                       bound_top_request, diagnostics%surface)
    if (diagnostics%surface%status /= FMR_RUTTER_BIND_OK .or. .not. diagnostics%surface%result_produced) then
      diagnostics%status = FMR_RUTTER_APP_SURFACE_REJECTED
      result = rutter_interval_result_t()
      source_trial = rutter_source_trial_t()
      bound_top_request = b110_dynamic_top_boundary_request_t()
      return
    end if

    call fmr_bind_rutter_ptra_to_root_input(base_root_input, active_nodes, result, process_diagnostics, &
                                            bound_root_input, diagnostics%root)
    if (diagnostics%root%status /= FMR_RUTTER_BIND_OK .or. .not. diagnostics%root%result_produced) then
      diagnostics%status = FMR_RUTTER_APP_ROOT_REJECTED
      result = rutter_interval_result_t()
      source_trial = rutter_source_trial_t()
      bound_top_request = b110_dynamic_top_boundary_request_t()
      bound_root_input = crop_root_uptake_input_t()
      return
    end if
    diagnostics%result_produced = .true.
  end subroutine fmr_prepare_rutter_source_window_application

end module mod_fmr_rutter_source_window_application
