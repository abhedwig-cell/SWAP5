program test_ross25_tiered_wetting_kernel
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_kernel_request_t, &
       rossfast_d3r_kernel_result_t, rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, ROSSFAST_TABLE_PROVIDER_OK
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  real(real64), parameter :: ref_self_tol = 1.0e-9_real64
  real(real64), parameter :: theta_span_tol = 1.0e-5_real64
  real(real64), parameter :: state_change_tol = 5.0e-3_real64

  character(len=512) :: material_arg, fixture_path
  character(len=3) :: material_id
  type(rossfast_d3r_material_t) :: material
  type(rossfast_d3r_table_registry_t) :: registry
  type(rossfast_d3r_table_kernel_t) :: kernel
  type(rossfast_d3r_kernel_request_t) :: request
  type(rossfast_d3r_kernel_result_t) :: result
  real(real64) :: se, q_top, q_bottom_up, reference_self
  real(real64) :: initial_heads(n), initial_theta(n), reference_heads(n), reference_theta(n)
  real(real64) :: max_theta_norm, max_state_change_rel, max_head_inf, max_mass_residual
  real(real64) :: theta_norm, state_change_rel, head_inf, mass_residual
  real(real64) :: span, reference_change, denom, external, storage_change
  real(real64) :: semantic_t0
  integer :: ncase, i, unit_fixture, ios, provider_status, exact_nodes
  integer :: tier_work
  character(len=2) :: tier_name
  logical :: found, valid

  call get_command_argument(1, material_arg)
  call get_command_argument(2, fixture_path)
  if (len_trim(material_arg)==0 .or. len_trim(fixture_path)==0) then
    error stop 'usage: test_ross25 MATERIAL FIXTURE.txt'
  end if
  material_id=material_arg(1:min(3,len_trim(material_arg)))

  call rossfast_d3r_material_from_id(trim(material_id),material,found)
  call require(found,'material authority available')
  call bind_rossfast_d3r_table_registry(registry,'assets/rossfast/d3r',valid)
  call require(valid,'production table registry bind')
  call registry%initialize_kernel(kernel,material,valid,provider_status)
  call require(valid,'production table kernel initialization')
  call require(provider_status==ROSSFAST_TABLE_PROVIDER_OK,'production table provider status')

  open(newunit=unit_fixture,file=trim(fixture_path),status='old',action='read',iostat=ios)
  call require(ios==0,'open reference fixture')
  read(unit_fixture,*,iostat=ios) ncase
  call require(ios==0 .and. ncase==3,'exact three Se cases')

  max_theta_norm=0.0_real64
  max_state_change_rel=0.0_real64
  max_head_inf=0.0_real64
  max_mass_residual=0.0_real64

  do i=1,ncase
    read(unit_fixture,*,iostat=ios) se,q_top,q_bottom_up,reference_self
    call require(ios==0,'read fixture header')
    read(unit_fixture,*,iostat=ios) initial_heads
    call require(ios==0,'read initial heads')
    read(unit_fixture,*,iostat=ios) initial_theta
    call require(ios==0,'read initial theta')
    read(unit_fixture,*,iostat=ios) reference_heads
    call require(ios==0,'read reference heads')
    read(unit_fixture,*,iostat=ios) reference_theta
    call require(ios==0,'read reference theta')

    call require(reference_self<=ref_self_tol,'independent reference self gate')
    call require(all(ieee_is_finite(initial_heads)) .and. all(ieee_is_finite(initial_theta)), &
         'finite initial state')
    call require(all(ieee_is_finite(reference_heads)) .and. all(ieee_is_finite(reference_theta)), &
         'finite independent reference state')

    request=rossfast_d3r_kernel_request_t()
    request%material=material
    request%base_state%active_nodes=n
    allocate(request%base_state%pressure_head_cm(n),request%base_state%water_content(n))
    request%base_state%pressure_head_cm=initial_heads
    request%base_state%water_content=initial_theta
    request%forcing%top_flux_cm_per_day=q_top
    request%forcing%bottom_flux_upward_cm_per_day=q_bottom_up
    semantic_t0=901.25_real64+10.0_real64*se
    request%t0_day=semantic_t0
    request%t1_day=semantic_t0+ROSSFAST_D3R_OUTER_HORIZON_DAY
    request%equal_internal_substeps=2

    call kernel%solve(request,result)
    call require(result%request_admitted,'direct production-kernel request admitted')
    call require(result%solver_ok,'tiered production kernel solver ok')
    call require(result%temporal_certificate_available,'tiered temporal certificate available')
    call require(ieee_is_finite(result%temporal_indicator) .and. result%temporal_indicator>=0.0_real64 .and. &
         result%temporal_indicator<=1.0_real64,'tiered temporal certificate accepted')
    call require(result%internal_retries==0 .and. result%alternative_solver_calls==0,'no hidden retry or fallback')

    tier_work=result%linear_solves
    select case(tier_work)
    case(6)
      tier_name='K2'
    case(18)
      tier_name='K4'
    case(42)
      tier_name='K8'
    case default
      call require(.false.,'tiered work count must be 6,18,42')
      tier_name='NA'
    end select

    call require(allocated(result%candidate_state%pressure_head_cm),'candidate heads allocated')
    call require(allocated(result%candidate_state%water_content),'candidate theta allocated')
    call require(all(ieee_is_finite(result%candidate_state%pressure_head_cm)),'candidate heads finite')
    call require(all(ieee_is_finite(result%candidate_state%water_content)),'candidate theta finite')

    span=material%theta_s-material%theta_r
    call require(span>0.0_real64,'positive material water-content span')
    theta_norm=maxval(abs(result%candidate_state%water_content-reference_theta))/span
    reference_change=maxval(abs(reference_theta-initial_theta))
    denom=max(reference_change,1.0e-8_real64*span)
    state_change_rel=maxval(abs(result%candidate_state%water_content-reference_theta))/denom
    head_inf=maxval(abs(result%candidate_state%pressure_head_cm-reference_heads))

    storage_change=ROSSFAST_D3R_DZ_CM*sum(result%candidate_state%water_content-initial_theta)
    external=ROSSFAST_D3R_OUTER_HORIZON_DAY*(q_top+q_bottom_up)
    mass_residual=storage_change-external
    exact_nodes=count_exact_internal_nodes(result%candidate_state%pressure_head_cm)

    call require(theta_norm<=theta_span_tol,'theta-span normalized reference error')
    call require(state_change_rel<=state_change_tol,'state-change relative reference error')
    call require(abs(mass_residual)<=ROSSFAST_D3R_HARD_MASS_TOL_CM,'integrated prescribed-flux mass gate')
    call require(exact_nodes==0,'no exact internal table-node endpoint')

    max_theta_norm=max(max_theta_norm,theta_norm)
    max_state_change_rel=max(max_state_change_rel,state_change_rel)
    max_head_inf=max(max_head_inf,head_inf)
    max_mass_residual=max(max_mass_residual,abs(mass_residual))

    write(*,'(*(g0))') 'F_ROSS25_CASE|MATERIAL=',trim(material_id),'|SE=',se,'|TIER=',trim(tier_name), &
         '|LIN=',tier_work,'|TEMP=',result%temporal_indicator,'|THETA_NORM=',theta_norm, &
         '|STATE_CHANGE_REL=',state_change_rel,'|HEAD_INF_CM=',head_inf,'|MASS=',mass_residual, &
         '|EXACT_NODES=',exact_nodes

    deallocate(request%base_state%pressure_head_cm,request%base_state%water_content)
  end do
  close(unit_fixture)

  write(*,'(A,1X,A)') 'F_ROSS25_MATERIAL',trim(material_id)
  write(*,'(A,I0)') 'F_ROSS25_CASE_COUNT=',ncase
  write(*,'(A,ES26.17E3)') 'F_ROSS25_MAX_THETA_NORM=',max_theta_norm
  write(*,'(A,ES26.17E3)') 'F_ROSS25_MAX_STATE_CHANGE_REL=',max_state_change_rel
  write(*,'(A,ES26.17E3)') 'F_ROSS25_MAX_HEAD_INF_CM=',max_head_inf
  write(*,'(A,ES26.17E3)') 'F_ROSS25_MAX_ABS_MASS_RESIDUAL_CM=',max_mass_residual
  write(*,'(A)') 'F_ROSS25_TIERED_WETTING_KERNEL=PASS'

contains

  integer function count_exact_internal_nodes(heads) result(count_nodes)
    real(real64),intent(in) :: heads(:)
    real(real64) :: x, frac
    integer :: j
    count_nodes=0
    do j=1,size(heads)
      if (heads(j)>=-1.0_real64 .or. heads(j)<=-10000.0_real64) cycle
      x=60.0_real64*log10(-heads(j))
      frac=x-real(floor(x),real64)
      if (frac==0.0_real64) count_nodes=count_nodes+1
    end do
  end function count_exact_internal_nodes

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'F_ROSS25_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ross25_tiered_wetting_kernel
