program test_pub_p2e04_reference_failure_census
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  integer, parameter :: nclass = 7, ndt = 3
  integer, parameter :: C_ACCEPTED=1, C_TOTAL_ONLY=2, C_LOCAL_BAL=3, C_HEAD=4, C_MIXED=5, C_RETRY_OTHER=6, C_FAILED=7
  integer, parameter :: S_NONE=0, S_COARSE=1, S_HALF1=2, S_HALF2=3
  character(len=18), parameter :: class_name(nclass) = [character(len=18) :: &
       'ACCEPTED', 'RETRY_TOTAL_ONLY', 'RETRY_LOCAL_BAL', 'RETRY_HEAD', 'RETRY_MIXED', 'RETRY_OTHER', 'FAILED_OR_INVALID']
  character(len=3), parameter :: material_ids(6) = [character(len=3) :: 'B01','B12','O01','O05','O14','O18']
  character(len=7), parameter :: forcing_ids(3) = [character(len=7) :: 'DRYING ','NOMINAL','WETTING']
  real(real64), parameter :: se_levels(3) = [0.65_real64,0.85_real64,0.98_real64]
  real(real64), parameter :: dt_levels(ndt) = [0.0016_real64,0.0004_real64,0.0001_real64]
  real(real64), parameter :: qtop_factor(3) = [-0.005_real64,0.010_real64,0.025_real64]
  real(real64), parameter :: qbot_factor(3) = [-0.019_real64,-0.004_real64,0.011_real64]

  integer :: counts(nclass), counts_by_dt(nclass,ndt), stage_counts(3), total_cases
  integer :: imat, ise, iforce, idt, class_id, failed_stage

  counts=0; counts_by_dt=0; stage_counts=0; total_cases=0
  do imat=1,size(material_ids)
    do ise=1,size(se_levels)
      do iforce=1,size(forcing_ids)
        do idt=1,ndt
          total_cases=total_cases+1
          call classify_case(material_ids(imat),se_levels(ise),forcing_ids(iforce),qtop_factor(iforce), &
               qbot_factor(iforce),dt_levels(idt),class_id,failed_stage)
          counts(class_id)=counts(class_id)+1
          counts_by_dt(class_id,idt)=counts_by_dt(class_id,idt)+1
          if (failed_stage>=S_COARSE .and. failed_stage<=S_HALF2) stage_counts(failed_stage)=stage_counts(failed_stage)+1
          write(*,'(A,I0,A,A,A,ES26.17E3,A,A,A,ES26.17E3,A,A,A,A)') 'PUB_P2E04_CASE=',total_cases, &
               '|M=',trim(material_ids(imat)),'|SE=',se_levels(ise),'|F=',trim(forcing_ids(iforce)), &
               '|DT=',dt_levels(idt),'|CLASS=',trim(class_name(class_id)),'|STAGE=',trim(stage_label(failed_stage))
        end do
      end do
    end do
  end do

  call require(total_cases==162,'exact P2E03 domain censused')
  write(*,'(A,I0)') 'PUB_P2E04_CASE_COUNT=',total_cases
  do class_id=1,nclass
    write(*,'(A,A,A,I0)') 'PUB_P2E04_CLASS_COUNT|CLASS=',trim(class_name(class_id)),'|COUNT=',counts(class_id)
    do idt=1,ndt
      write(*,'(A,A,A,ES26.17E3,A,I0)') 'PUB_P2E04_CLASS_DT|CLASS=',trim(class_name(class_id)), &
           '|DT=',dt_levels(idt),'|COUNT=',counts_by_dt(class_id,idt)
    end do
  end do
  write(*,'(A,I0)') 'PUB_P2E04_FAIL_STAGE_COARSE=',stage_counts(S_COARSE)
  write(*,'(A,I0)') 'PUB_P2E04_FAIL_STAGE_HALF1=',stage_counts(S_HALF1)
  write(*,'(A,I0)') 'PUB_P2E04_FAIL_STAGE_HALF2=',stage_counts(S_HALF2)
  write(*,'(A,I0)') 'PUB_P2E04_INVALID_TOTAL=',total_cases-counts(C_ACCEPTED)
  write(*,'(A)') 'PUB_P2E04_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E04_FAILURE_CENSUS=PASS'

contains

  subroutine classify_case(material_id,se,forcing_id,top_factor,bottom_factor,coarse_dt,class_id,failed_stage)
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor,coarse_dt
    integer,intent(out) :: class_id,failed_stage
    type(soil_water_parameter_set_t),target :: parameters
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta0(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: h0,k0,half_dt
    logical :: found

    class_id=C_FAILED; failed_stage=S_COARSE
    call rossfast_d3r_material_from_id(material_id,material,found)
    if (.not.found) return
    h0=head_from_effective_saturation(se,material)
    if (.not.ieee_is_finite(h0) .or. h0<=ROSSFAST_D3R_H_MIN_CM .or. h0>=ROSSFAST_D3R_H_MAX_CM) return
    call initialize_parameter_contract(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta0)) .or. any(.not.ieee_is_finite(conductivity)) .or. any(conductivity<=0.0_real64)) return
    k0=conductivity(1)
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0, &
         top_factor*k0,bottom_factor*k0,coarse_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    call solver%solve(request,workspace,result)
    call classify_result(result,workspace,material,class_id)
    if (class_id/=C_ACCEPTED) then; failed_stage=S_COARSE; return; end if

    half_dt=0.5_real64*coarse_dt
    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0, &
         top_factor*k0,bottom_factor*k0,half_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(request,workspace,result)
    call classify_result(result,workspace,material,class_id)
    if (class_id/=C_ACCEPTED) then; failed_stage=S_HALF1; return; end if

    request%base_state=result%candidate_state
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(request,workspace,result)
    call classify_result(result,workspace,material,class_id)
    if (class_id/=C_ACCEPTED) then; failed_stage=S_HALF2; return; end if
    failed_stage=S_NONE
  end subroutine classify_case

  subroutine classify_result(result,workspace,material,class_id)
    type(soil_water_solve_result_t),intent(in) :: result
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    type(rossfast_d3r_material_t),intent(in) :: material
    integer,intent(out) :: class_id
    integer :: bal,head
    real(real64) :: rsum,rmax

    class_id=C_FAILED
    if (result%status==SW_SOLVE_CONVERGED) then
      if (trim(result%diagnostics%route)/='legacy-reference-bound') return
      if (.not.ieee_is_finite(result%unrounded_mass_balance_residual)) return
      if (abs(result%unrounded_mass_balance_residual)>ROSSFAST_D3R_HARD_MASS_TOL_CM) return
      if (.not.endpoint_valid(result,material)) return
      class_id=C_ACCEPTED
      return
    end if
    if (result%status/=SW_SOLVE_RETRY_ADVISED) return
    if (.not.allocated(workspace%richards%residual)) then; class_id=C_RETRY_OTHER; return; end if
    rsum=sum(workspace%richards%residual)
    rmax=maxval(abs(workspace%richards%residual))
    bal=count(workspace%richards%nonconverged_balance)
    head=count(workspace%richards%nonconverged_head)
    if (bal>0 .and. head>0) then
      class_id=C_MIXED
    else if (bal>0) then
      class_id=C_LOCAL_BAL
    else if (head>0) then
      class_id=C_HEAD
    else if (ieee_is_finite(rsum) .and. ieee_is_finite(rmax) .and. &
             rmax<=ROSSFAST_D3R_HARD_MASS_TOL_CM .and. abs(rsum)>ROSSFAST_D3R_HARD_MASS_TOL_CM) then
      class_id=C_TOTAL_ONLY
    else
      class_id=C_RETRY_OTHER
    end if
  end subroutine classify_result

  logical function endpoint_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (size(result%candidate_state%pressure_head)/=n .or. size(result%candidate_state%water_content)/=n) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. any(result%candidate_state%water_content>=material%theta_s)) return
    ok=.true.
  end function endpoint_valid

  pure function stage_label(stage) result(label)
    integer,intent(in) :: stage
    character(len=6) :: label
    select case(stage)
    case(S_NONE); label='NONE  '
    case(S_COARSE); label='COARSE'
    case(S_HALF1); label='HALF1 '
    case(S_HALF2); label='HALF2 '
    case default; label='OTHER '
    end select
  end function stage_label

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=920401; parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n; parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64); end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM; parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n; cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm; cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64; cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,h0,qtop,qbot,dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),h0,qtop,qbot,dt
    req%parameters=>parameter_set; req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=h0; req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=h0; req%boundary%bottom_flux=qbot; req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.; req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1; req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64; req%numerical%total_balance_tolerance=1.0e-12_real64
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64; req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider; req%evaluation%source_sink=>source_provider; req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then; write(*,'(A,1X,A)') 'PUB_P2E04_FAIL',trim(label); error stop 1; end if
  end subroutine require
end program test_pub_p2e04_reference_failure_census
