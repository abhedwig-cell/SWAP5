program test_ross03_d3r_table_kernel
  use, intrinsic :: iso_fortran_env, only: real32, real64
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_kernel_request_t, &
       rossfast_d3r_kernel_result_t, rossfast_d3r_material_t, &
       rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t, &
       initialize_rossfast_d3r_table_kernel, ROSSFAST_D3R_TABLE_N
  implicit none

  character(len=512) :: material_arg, table_path, fixture_path
  character(len=3) :: material_id
  type(rossfast_d3r_material_t) :: material, wrong_material
  type(rossfast_d3r_table_kernel_t) :: kernel
  type(rossfast_d3r_kernel_request_t) :: request
  type(rossfast_d3r_kernel_result_t) :: result
  real(real32), allocatable :: table(:,:)
  real(real64) :: duration, q_top, q_bottom_up, expected_raw, expected_indicator, semantic_t0
  real(real64) :: initial_heads(ROSSFAST_D3R_N_CELLS)
  real(real64) :: initial_theta(ROSSFAST_D3R_N_CELLS)
  real(real64) :: coarse_heads(ROSSFAST_D3R_N_CELLS)
  real(real64) :: coarse_theta(ROSSFAST_D3R_N_CELLS)
  real(real64) :: refined_heads(ROSSFAST_D3R_N_CELLS)
  real(real64) :: refined_theta(ROSSFAST_D3R_N_CELLS)
  real(real64) :: max_theta_error, max_head_error, max_indicator_error
  integer :: ncase, case_index, attempt, unit_table, unit_fixture, ios
  logical :: found, valid

  call get_command_argument(1, material_arg)
  call get_command_argument(2, table_path)
  call get_command_argument(3, fixture_path)
  if (len_trim(material_arg) == 0 .or. len_trim(table_path) == 0 .or. len_trim(fixture_path) == 0) then
    error stop 'usage: test_ross03 MATERIAL TABLE.txt FIXTURE.txt'
  end if
  material_id = material_arg(1:min(3,len_trim(material_arg)))

  call rossfast_d3r_material_from_id(trim(material_id), material, found)
  if (.not. found) error stop 101

  allocate(table(ROSSFAST_D3R_TABLE_N, ROSSFAST_D3R_TABLE_N))
  open(newunit=unit_table, file=trim(table_path), status='old', action='read', iostat=ios)
  if (ios /= 0) error stop 102
  read(unit_table, *, iostat=ios) table
  close(unit_table)
  if (ios /= 0) error stop 103

  call initialize_rossfast_d3r_table_kernel(kernel, material, table, valid)
  if (.not. valid) error stop 104

  block
    type(rossfast_d3r_table_kernel_t) :: bad_kernel
    real(real32), allocatable :: bad_table(:,:)
    allocate(bad_table(ROSSFAST_D3R_TABLE_N - 1, ROSSFAST_D3R_TABLE_N))
    bad_table = 0.0_real32
    call initialize_rossfast_d3r_table_kernel(bad_kernel, material, bad_table, valid)
    if (valid) error stop 105
  end block

  open(newunit=unit_fixture, file=trim(fixture_path), status='old', action='read', iostat=ios)
  if (ios /= 0) error stop 106
  read(unit_fixture, *, iostat=ios) ncase
  if (ios /= 0 .or. ncase /= 9) error stop 107

  max_theta_error = 0.0_real64
  max_head_error = 0.0_real64
  max_indicator_error = 0.0_real64

  do case_index = 1, ncase
    read(unit_fixture, *, iostat=ios) attempt, duration, q_top, q_bottom_up, expected_raw, expected_indicator
    if (ios /= 0) error stop 108
    read(unit_fixture, *, iostat=ios) initial_heads
    if (ios /= 0) error stop 109
    read(unit_fixture, *, iostat=ios) initial_theta
    if (ios /= 0) error stop 110
    read(unit_fixture, *, iostat=ios) coarse_heads
    if (ios /= 0) error stop 111
    read(unit_fixture, *, iostat=ios) coarse_theta
    if (ios /= 0) error stop 112
    read(unit_fixture, *, iostat=ios) refined_heads
    if (ios /= 0) error stop 113
    read(unit_fixture, *, iostat=ios) refined_theta
    if (ios /= 0) error stop 114

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
    if (.not. result%request_admitted) error stop 120
    if (.not. result%solver_ok) error stop 121
    if (.not. result%temporal_certificate_available) error stop 122
    if (result%linear_solves /= 24) error stop 123
    if (result%alternative_solver_calls /= 0 .or. result%internal_retries /= 0) error stop 124
    if (.not. allocated(result%candidate_state%pressure_head_cm)) error stop 125
    if (.not. allocated(result%candidate_state%water_content)) error stop 126

    max_theta_error = max(max_theta_error, maxval(abs(result%candidate_state%water_content - refined_theta)))
    max_head_error = max(max_head_error, maxval(abs(result%candidate_state%pressure_head_cm - refined_heads)))
    max_indicator_error = max(max_indicator_error, abs(result%temporal_indicator - expected_indicator))

    if (maxval(abs(result%candidate_state%water_content - refined_theta)) > 2.0e-12_real64) error stop 127
    if (maxval(abs(result%candidate_state%pressure_head_cm - refined_heads)) > 2.0e-7_real64) error stop 128
    if (abs(result%temporal_indicator - expected_indicator) > 2.0e-8_real64) error stop 129
    if (expected_raw < 0.0_real64) error stop 130

    deallocate(request%base_state%pressure_head_cm)
    deallocate(request%base_state%water_content)
  end do
  close(unit_fixture)

  request = rossfast_d3r_kernel_request_t()
  request%material = material
  request%base_state%active_nodes = ROSSFAST_D3R_N_CELLS
  allocate(request%base_state%pressure_head_cm(ROSSFAST_D3R_N_CELLS))
  allocate(request%base_state%water_content(ROSSFAST_D3R_N_CELLS))
  request%base_state%pressure_head_cm = initial_heads
  request%base_state%water_content = initial_theta
  request%forcing%top_flux_cm_per_day = q_top
  request%forcing%bottom_flux_upward_cm_per_day = q_bottom_up
  request%t0_day = 509.25_real64
  request%t1_day = request%t0_day + duration
  request%equal_internal_substeps = 4
  call kernel%solve(request, result)
  if (result%request_admitted .or. result%solver_ok) error stop 131

  request%equal_internal_substeps = 8
  request%t1_day = request%t0_day + 0.9_real64 * duration
  call kernel%solve(request, result)
  if (result%request_admitted .or. result%solver_ok) error stop 132

  if (trim(material_id) == 'B01') then
    call rossfast_d3r_material_from_id('O14', wrong_material, found)
  else
    call rossfast_d3r_material_from_id('B01', wrong_material, found)
  end if
  if (.not. found) error stop 133
  request%material = wrong_material
  request%t1_day = request%t0_day + duration
  call kernel%solve(request, result)
  if (result%request_admitted .or. result%solver_ok) error stop 134

  write(*,'(a,1x,a)') 'ROSS03_MATERIAL', trim(material_id)
  write(*,'(a,1x,es24.16)') 'ROSS03_MAX_THETA_ERROR', max_theta_error
  write(*,'(a,1x,es24.16)') 'ROSS03_MAX_HEAD_ERROR_CM', max_head_error
  write(*,'(a,1x,es24.16)') 'ROSS03_MAX_INDICATOR_ERROR', max_indicator_error
  write(*,'(a)') 'ROSS03_D3R_TABLE_KERNEL_GATE PASS'

end program test_ross03_d3r_table_kernel
