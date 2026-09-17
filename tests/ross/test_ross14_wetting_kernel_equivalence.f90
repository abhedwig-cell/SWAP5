program test_ross14_wetting_kernel_equivalence
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_kernel_request_t, &
       rossfast_d3r_kernel_result_t, rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, ROSSFAST_TABLE_PROVIDER_OK
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  character(len=512) :: material_arg, fixture_path
  character(len=3) :: material_id
  type(rossfast_d3r_material_t) :: material
  type(rossfast_d3r_table_registry_t) :: registry
  type(rossfast_d3r_table_kernel_t) :: kernel
  type(rossfast_d3r_kernel_request_t) :: request
  type(rossfast_d3r_kernel_result_t) :: result
  real(real64) :: se, duration, q_top, q_bottom_up, expected_indicator
  real(real64) :: initial_heads(n), initial_theta(n), refined_heads(n), refined_theta(n)
  real(real64) :: max_theta_error, max_head_error, max_indicator_error
  real(real64) :: k_top, k_bottom, top_factor, bottom_factor, semantic_t0
  integer :: ncase, i, attempt, unit_fixture, ios, provider_status
  logical :: found, valid

  call get_command_argument(1, material_arg)
  call get_command_argument(2, fixture_path)
  if (len_trim(material_arg)==0 .or. len_trim(fixture_path)==0) then
    error stop 'usage: test_ross14 MATERIAL FIXTURE.txt'
  end if
  material_id=material_arg(1:min(3,len_trim(material_arg)))

  call rossfast_d3r_material_from_id(trim(material_id), material, found)
  call require(found, 'material authority available')

  call bind_rossfast_d3r_table_registry(registry, 'assets/rossfast/d3r', valid)
  call require(valid, 'production table registry bind')
  call registry%initialize_kernel(kernel, material, valid, provider_status)
  call require(valid, 'production table kernel initialization')
  call require(provider_status==ROSSFAST_TABLE_PROVIDER_OK, 'production table provider status')

  open(newunit=unit_fixture,file=trim(fixture_path),status='old',action='read',iostat=ios)
  call require(ios==0,'open research fixture')
  read(unit_fixture,*,iostat=ios) ncase
  call require(ios==0 .and. ncase==27,'exact 27 material fixture cases')

  max_theta_error=0.0_real64
  max_head_error=0.0_real64
  max_indicator_error=0.0_real64

  do i=1,ncase
    read(unit_fixture,*,iostat=ios) se, attempt, duration, q_top, q_bottom_up, expected_indicator
    call require(ios==0,'read fixture header')
    read(unit_fixture,*,iostat=ios) initial_heads
    call require(ios==0,'read initial heads')
    read(unit_fixture,*,iostat=ios) initial_theta
    call require(ios==0,'read initial theta')
    read(unit_fixture,*,iostat=ios) refined_heads
    call require(ios==0,'read refined heads')
    read(unit_fixture,*,iostat=ios) refined_theta
    call require(ios==0,'read refined theta')

    call require(se==0.65_real64 .or. se==0.85_real64 .or. se==0.98_real64, 'frozen Se level')
    call require(attempt>=0 .and. attempt<=8, 'duration attempt index')

    k_top=conductivity_from_head(initial_heads(1),material)
    k_bottom=conductivity_from_head(initial_heads(n),material)
    call require(k_top>0.0_real64 .and. k_bottom>0.0_real64, 'positive initial conductivity')
    top_factor=q_top/k_top
    bottom_factor=q_bottom_up/k_bottom
    call require(abs(top_factor+0.025_real64)<=64.0_real64*epsilon(1.0_real64), 'exact target top factor')
    call require(abs(bottom_factor-0.011_real64)<=64.0_real64*epsilon(1.0_real64), 'exact target bottom factor')

    request=rossfast_d3r_kernel_request_t()
    request%material=material
    request%base_state%active_nodes=n
    allocate(request%base_state%pressure_head_cm(n),request%base_state%water_content(n))
    request%base_state%pressure_head_cm=initial_heads
    request%base_state%water_content=initial_theta
    request%forcing%top_flux_cm_per_day=q_top
    request%forcing%bottom_flux_upward_cm_per_day=q_bottom_up
    semantic_t0=701.125_real64+10.0_real64*se+0.5_real64*real(attempt,real64)
    request%t0_day=semantic_t0
    request%t1_day=semantic_t0+duration
    request%equal_internal_substeps=8

    call kernel%solve(request,result)
    call require(result%request_admitted,'kernel request admitted')
    call require(result%solver_ok,'kernel solver ok')
    call require(result%temporal_certificate_available,'temporal certificate available')
    call require(result%linear_solves==24,'exact 24 component linear solves')
    call require(result%alternative_solver_calls==0 .and. result%internal_retries==0,'no hidden fallback or retry')
    call require(allocated(result%candidate_state%pressure_head_cm),'candidate heads allocated')
    call require(allocated(result%candidate_state%water_content),'candidate theta allocated')
    call require(all(ieee_is_finite(result%candidate_state%pressure_head_cm)),'candidate heads finite')
    call require(all(ieee_is_finite(result%candidate_state%water_content)),'candidate theta finite')

    max_theta_error=max(max_theta_error,maxval(abs(result%candidate_state%water_content-refined_theta)))
    max_head_error=max(max_head_error,maxval(abs(result%candidate_state%pressure_head_cm-refined_heads)))
    max_indicator_error=max(max_indicator_error,abs(result%temporal_indicator-expected_indicator))

    call require(maxval(abs(result%candidate_state%water_content-refined_theta))<=2.0e-12_real64, &
         'production kernel theta equivalent to pinned research')
    call require(maxval(abs(result%candidate_state%pressure_head_cm-refined_heads))<=2.0e-7_real64, &
         'production kernel head equivalent to pinned research')
    call require(abs(result%temporal_indicator-expected_indicator)<=2.0e-8_real64, &
         'production kernel temporal indicator equivalent to pinned research')

    deallocate(request%base_state%pressure_head_cm,request%base_state%water_content)
  end do
  close(unit_fixture)

  write(*,'(A,1X,A)') 'F_ROSS14_MATERIAL',trim(material_id)
  write(*,'(A,I0)') 'F_ROSS14_KERNEL_CASE_COUNT=',ncase
  write(*,'(A,ES26.17E3)') 'F_ROSS14_MAX_THETA_ERROR=',max_theta_error
  write(*,'(A,ES26.17E3)') 'F_ROSS14_MAX_HEAD_ERROR_CM=',max_head_error
  write(*,'(A,ES26.17E3)') 'F_ROSS14_MAX_INDICATOR_ERROR=',max_indicator_error
  write(*,'(A)') 'F_ROSS14_PRODUCTION_KERNEL_EQUIVALENCE=PASS'

contains

  pure real(real64) function conductivity_from_head(head_cm,mat) result(k)
    real(real64),intent(in) :: head_cm
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m,se,term
    m=1.0_real64-1.0_real64/mat%n
    se=(1.0_real64+abs(mat%alpha_per_cm*head_cm)**mat%n)**(-m)
    term=(1.0_real64-se**(1.0_real64/m))**m
    k=mat%ksatfit_cm_per_day*se**mat%lambda*(1.0_real64-term)**2
  end function conductivity_from_head

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'F_ROSS14_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ross14_wetting_kernel_equivalence
