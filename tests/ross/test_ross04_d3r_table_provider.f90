program test_ross04_d3r_table_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_kernel_request_t, &
       rossfast_d3r_kernel_result_t, rossfast_d3r_material_t, &
       rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, rossfast_d3r_table_asset_relative_path, &
       ROSSFAST_TABLE_PROVIDER_OK, ROSSFAST_TABLE_PROVIDER_OPEN, &
       ROSSFAST_TABLE_PROVIDER_HEADER, ROSSFAST_TABLE_PROVIDER_MATERIAL
  implicit none

  character(len=512) :: material_arg, asset_root, fixture_path, mismatch_root
  character(len=3) :: material_id
  character(len=:), allocatable :: relative_path, positive_asset_path
  type(rossfast_d3r_material_t) :: material, drifted_material
  type(rossfast_d3r_table_registry_t) :: registry, bad_registry
  type(rossfast_d3r_table_kernel_t) :: kernel, unused_kernel
  type(rossfast_d3r_kernel_request_t) :: request
  type(rossfast_d3r_kernel_result_t) :: result
  real(real64) :: duration, q_top, q_bottom_up, expected_raw, expected_indicator, semantic_t0
  real(real64) :: initial_heads(ROSSFAST_D3R_N_CELLS)
  real(real64) :: initial_theta(ROSSFAST_D3R_N_CELLS)
  real(real64) :: coarse_heads(ROSSFAST_D3R_N_CELLS)
  real(real64) :: coarse_theta(ROSSFAST_D3R_N_CELLS)
  real(real64) :: refined_heads(ROSSFAST_D3R_N_CELLS)
  real(real64) :: refined_theta(ROSSFAST_D3R_N_CELLS)
  real(real64) :: max_theta_error, max_head_error, max_indicator_error
  integer :: ncase, case_index, attempt, unit_fixture, delete_unit, ios, status
  logical :: found, valid

  call get_command_argument(1, material_arg)
  call get_command_argument(2, asset_root)
  call get_command_argument(3, fixture_path)
  call get_command_argument(4, mismatch_root)
  if (len_trim(material_arg) == 0 .or. len_trim(asset_root) == 0 .or. &
      len_trim(fixture_path) == 0 .or. len_trim(mismatch_root) == 0) then
    error stop 'usage: test_ross04 MATERIAL ASSET_ROOT FIXTURE.txt MISMATCH_ROOT'
  end if
  material_id = material_arg(1:min(3,len_trim(material_arg)))

  call rossfast_d3r_material_from_id(trim(material_id), material, found)
  if (.not. found) error stop 101

  call bind_rossfast_d3r_table_registry(registry, '', valid)
  if (valid) error stop 102
  call bind_rossfast_d3r_table_registry(registry, trim(asset_root), valid)
  if (.not. valid) error stop 103

  call registry%initialize_kernel(kernel, material, valid, status)
  if (.not. valid .or. status /= ROSSFAST_TABLE_PROVIDER_OK) error stop 104

  call rossfast_d3r_table_asset_relative_path(trim(material_id), relative_path, found)
  if (.not. found) error stop 105
  positive_asset_path = trim(asset_root) // '/' // relative_path
  open(newunit=delete_unit, file=positive_asset_path, status='old', action='read', iostat=ios)
  if (ios /= 0) error stop 106
  close(delete_unit, status='delete', iostat=ios)
  if (ios /= 0) error stop 107

  ! The kernel must own its immutable copy after initialization. All solves below
  ! run after the registry asset has deliberately been removed from this temp root.
  open(newunit=unit_fixture, file=trim(fixture_path), status='old', action='read', iostat=ios)
  if (ios /= 0) error stop 108
  read(unit_fixture, *, iostat=ios) ncase
  if (ios /= 0 .or. ncase /= 9) error stop 109

  max_theta_error = 0.0_real64
  max_head_error = 0.0_real64
  max_indicator_error = 0.0_real64

  do case_index = 1, ncase
    read(unit_fixture, *, iostat=ios) attempt, duration, q_top, q_bottom_up, expected_raw, expected_indicator
    if (ios /= 0) error stop 110
    read(unit_fixture, *, iostat=ios) initial_heads
    if (ios /= 0) error stop 111
    read(unit_fixture, *, iostat=ios) initial_theta
    if (ios /= 0) error stop 112
    read(unit_fixture, *, iostat=ios) coarse_heads
    if (ios /= 0) error stop 113
    read(unit_fixture, *, iostat=ios) coarse_theta
    if (ios /= 0) error stop 114
    read(unit_fixture, *, iostat=ios) refined_heads
    if (ios /= 0) error stop 115
    read(unit_fixture, *, iostat=ios) refined_theta
    if (ios /= 0) error stop 116

    request = rossfast_d3r_kernel_request_t()
    request%material = material
    request%base_state%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(request%base_state%pressure_head_cm(ROSSFAST_D3R_N_CELLS))
    allocate(request%base_state%water_content(ROSSFAST_D3R_N_CELLS))
    request%base_state%pressure_head_cm = initial_heads
    request%base_state%water_content = initial_theta
    request%forcing%top_flux_cm_per_day = q_top
    request%forcing%bottom_flux_upward_cm_per_day = q_bottom_up
    semantic_t0 = 317.125_real64 + 0.75_real64 * real(attempt, real64)
    request%t0_day = semantic_t0
    request%t1_day = semantic_t0 + duration
    request%equal_internal_substeps = 8

    call kernel%solve(request, result)
    if (.not. result%request_admitted .or. .not. result%solver_ok) error stop 120
    if (.not. result%temporal_certificate_available) error stop 121
    if (result%linear_solves /= 24) error stop 122
    max_theta_error = max(max_theta_error, maxval(abs(result%candidate_state%water_content - refined_theta)))
    max_head_error = max(max_head_error, maxval(abs(result%candidate_state%pressure_head_cm - refined_heads)))
    max_indicator_error = max(max_indicator_error, abs(result%temporal_indicator - expected_indicator))
    if (maxval(abs(result%candidate_state%water_content - refined_theta)) > 2.0e-12_real64) error stop 123
    if (maxval(abs(result%candidate_state%pressure_head_cm - refined_heads)) > 2.0e-7_real64) error stop 124
    if (abs(result%temporal_indicator - expected_indicator) > 2.0e-8_real64) error stop 125
    if (expected_raw < 0.0_real64) error stop 126
    deallocate(request%base_state%pressure_head_cm)
    deallocate(request%base_state%water_content)
  end do
  close(unit_fixture)

  ! A nonempty but nonexistent registry root binds as configuration, then fails
  ! closed at exact asset resolution rather than falling back to generation.
  call bind_rossfast_d3r_table_registry(bad_registry, trim(asset_root)//'/does-not-exist', valid)
  if (.not. valid) error stop 130
  call bad_registry%initialize_kernel(unused_kernel, material, valid, status)
  if (valid .or. status /= ROSSFAST_TABLE_PROVIDER_OPEN) error stop 131

  ! A file with the requested filename but another material header is rejected.
  call bind_rossfast_d3r_table_registry(bad_registry, trim(mismatch_root), valid)
  if (.not. valid) error stop 132
  call bad_registry%initialize_kernel(unused_kernel, material, valid, status)
  if (valid .or. status /= ROSSFAST_TABLE_PROVIDER_HEADER) error stop 133

  ! Drifted material parameters do not get to reuse a qualified table by ID only.
  drifted_material = material
  drifted_material%theta_s = drifted_material%theta_s + 1.0e-12_real64
  call registry%initialize_kernel(unused_kernel, drifted_material, valid, status)
  if (valid .or. status /= ROSSFAST_TABLE_PROVIDER_MATERIAL) error stop 134

  call rossfast_d3r_table_asset_relative_path('XXX', relative_path, found)
  if (found) error stop 135

  write(*,'(a,1x,a)') 'ROSS04_MATERIAL', trim(material_id)
  write(*,'(a,1x,es24.16)') 'ROSS04_MAX_THETA_ERROR', max_theta_error
  write(*,'(a,1x,es24.16)') 'ROSS04_MAX_HEAD_ERROR_CM', max_head_error
  write(*,'(a,1x,es24.16)') 'ROSS04_MAX_INDICATOR_ERROR', max_indicator_error
  write(*,'(a)') 'ROSS04_TABLE_PROVIDER_GATE PASS'

end program test_ross04_d3r_table_provider
