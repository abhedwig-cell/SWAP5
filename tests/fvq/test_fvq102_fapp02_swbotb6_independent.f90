program test_fvq102_fapp02_swbotb6_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_legacy_bottom_boundary_application_binding, only: &
       fmr_legacy_bottom_boundary_binding_t, fmr_resolve_legacy_bottom_boundary, &
       FMR_LEGACY_BOTTOM_BINDING_OK, FMR_LEGACY_BOTTOM_BINDING_UNSUPPORTED_MODE
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_EXPLICIT_FLUX
  implicit none

  type(fmr_legacy_bottom_boundary_binding_t) :: binding
  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  type(reference_richards_state_binding_t) :: state
  integer :: status
  integer(int64) :: top_flux_bits, top_head_bits, bottom_head_bits

  call fmr_resolve_legacy_bottom_boundary(6, binding, status)
  call require(status == FMR_LEGACY_BOTTOM_BINDING_OK, 'legacy mode 6 must resolve')
  call require(binding%available, 'resolved binding must be available')
  call require(binding%typed_bottom_mode == 2, 'mode 6 must target prescribed-qbot mode 2')
  call require(transfer(binding%typed_bottom_flux, 0_int64) == transfer(0.0_real64, 0_int64), &
               'mapped flux must be bit-exact positive zero')

  parameters%parameter_set_id = 102_int64
  parameters%active_nodes = 2
  allocate(parameters%z(2), parameters%dz(2), parameters%node_distance(2))
  parameters%z = [-5.0_real64, -15.0_real64]
  parameters%dz = [10.0_real64, 10.0_real64]
  parameters%node_distance = [5.0_real64, 10.0_real64]

  request%parameters => parameters
  request%step_duration = 0.25_real64
  request%base_state%active_nodes = 2
  allocate(request%base_state%pressure_head(2), request%base_state%water_content(2))
  request%base_state%pressure_head = [-50.0_real64, -25.0_real64]
  request%base_state%water_content = [0.31_real64, 0.35_real64]
  request%base_state%ponding_depth = 0.015_real64
  request%base_state%groundwater_level = -80.0_real64

  ! Seed unrelated boundary values before applying the qualified semantic image.
  request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%top_flux = 0.123456789_real64
  request%boundary%top_head = 1.75_real64
  request%boundary%bottom_head = -234.5_real64
  top_flux_bits = transfer(request%boundary%top_flux, 0_int64)
  top_head_bits = transfer(request%boundary%top_head, 0_int64)
  bottom_head_bits = transfer(request%boundary%bottom_head, 0_int64)

  request%boundary%bottom_mode = binding%typed_bottom_mode
  request%boundary%bottom_flux = binding%typed_bottom_flux

  call require(transfer(request%boundary%top_flux, 0_int64) == top_flux_bits, 'top flux unchanged')
  call require(transfer(request%boundary%top_head, 0_int64) == top_head_bits, 'top head unchanged')
  call require(transfer(request%boundary%bottom_head, 0_int64) == bottom_head_bits, 'bottom head unchanged')

  call initialize_reference_state_binding(state, request)
  call require(transfer(state%qbot, 0_int64) == transfer(0.0_real64, 0_int64), &
               'state binding must materialize exact zero qbot')
  call require(transfer(state%qtop, 0_int64) == top_flux_bits, 'state binding must preserve top flux')
  call require(transfer(state%hbot, 0_int64) == bottom_head_bits, 'state binding must preserve bottom head')

  call fmr_resolve_legacy_bottom_boundary(7, binding, status)
  call require(status == FMR_LEGACY_BOTTOM_BINDING_UNSUPPORTED_MODE, 'other legacy modes remain unsupported')
  call require(.not. binding%available, 'unsupported legacy mode must fail closed')

  write(*,'(A)') 'FVQ102_EXACT_SWBOTB6_SEMANTIC_IMAGE=PASS'
  write(*,'(A)') 'FVQ102_TYPED_REQUEST_APPLICATION=PASS'
  write(*,'(A)') 'FVQ102_UNRELATED_BOUNDARY_PRESERVATION=PASS'
  write(*,'(A)') 'FVQ102_STATE_BINDING_QBOT_IDENTITY=PASS'
  write(*,'(A)') 'FVQ102_UNSUPPORTED_MODE_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ102_INDEPENDENT_ORACLE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FVQ102_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq102_fapp02_swbotb6_independent
