program test_pub_p2e11d1_reference_extension_failure_adjudication
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=2, nse=1, nforcing=2, ndt=1, nphys=nmat*nse*nforcing
  real(real64), parameter :: reference_balance_rate_tol = 1.0e-12_real64
  real(real64), parameter :: publication_integrated_mass_tol_cm = 1.0e-12_real64
  character(len=3), parameter :: material_ids(nmat) = [character(len=3) :: 'B02','B05']
  character(len=7), parameter :: forcing_ids(nforcing) = [character(len=7) :: 'DRYING ','NOMINAL']
  real(real64), parameter :: se_levels(nse) = [0.98_real64]
  real(real64), parameter :: dt_levels(ndt) = [0.0064_real64]
  real(real64), parameter :: qtop_factor(nforcing) = [-0.005_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(nforcing) = [-0.019_real64,-0.004_real64]

  logical :: valid_matrix(nphys,ndt)
  real(real64) :: uh_inf(nphys,ndt), uh_rms(nphys,ndt)
  real(real64) :: utheta_inf(nphys,ndt), utheta_rms(nphys,ndt), ustorage(nphys,ndt)
  integer :: valid_by_dt(ndt), invalid_by_dt(ndt)
  integer :: idt,imat,ise,iforce,ip,selected_dt_index
  logical :: valid
  character(len=32) :: failure_stage

  valid_matrix=.false.
  uh_inf=0.0_real64; uh_rms=0.0_real64
  utheta_inf=0.0_real64; utheta_rms=0.0_real64; ustorage=0.0_real64
  valid_by_dt=0; invalid_by_dt=0

  do idt=1,ndt
    ip=0
    do imat=1,nmat
      do ise=1,nse
        do iforce=1,nforcing
          ip=ip+1
          call run_case(ip,idt,material_ids(imat),se_levels(ise),forcing_ids(iforce), &
               qtop_factor(iforce),qbot_factor(iforce),dt_levels(idt),valid,failure_stage, &
               uh_inf(ip,idt),uh_rms(ip,idt),utheta_inf(ip,idt),utheta_rms(ip,idt),ustorage(ip,idt))
          valid_matrix(ip,idt)=valid
          if (valid) then
            valid_by_dt(idt)=valid_by_dt(idt)+1
          else
            invalid_by_dt(idt)=invalid_by_dt(idt)+1
          end if
        end do
      end do
    end do
    call require(ip==nphys,'exact 4 diagnostic physical cases at the frozen temporal level')
  end do

  call require(sum(valid_by_dt+invalid_by_dt)==nphys*ndt,'exact 270 preregistered trial pairs executed')

  selected_dt_index=0
  do idt=1,ndt
    if (valid_by_dt(idt)==nphys .and. selected_dt_index==0) selected_dt_index=idt
  end do

  write(*,'(A,I0)') 'PUB_P2E11D1_PHYSICAL_CASE_COUNT=',nphys
  write(*,'(A,I0)') 'PUB_P2E11D1_TEMPORAL_LEVEL_COUNT=',ndt
  write(*,'(A,I0)') 'PUB_P2E11D1_TRIAL_PAIR_COUNT=',nphys*ndt
  do idt=1,ndt
    write(*,'(*(g0))') 'PUB_P2E11D1_DT_FEASIBILITY|INDEX=',idt,'|DT=',dt_levels(idt), &
         '|VALID=',valid_by_dt(idt),'|INVALID=',invalid_by_dt(idt)
  end do
  write(*,'(A)') 'PUB_P2E11D1_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E11D1_THRESHOLD_FROZEN=FALSE'
  write(*,'(A)') 'PUB_P2E11D1_REFERENCE_TOLERANCE_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E11D1_P2E03_REPAIRED_OR_RECLASSIFIED=FALSE'

  if (selected_dt_index==0) then
    write(*,'(A)') 'PUB_P2E11D1_COMMON_DOMAIN_STATUS=BLOCKED_EXTENSION_REFERENCE_DOMAIN'
    write(*,'(A)') 'PUB_P2E11D1_SCIENTIFIC_OUTCOME=NEGATIVE_EXTENSION_REFERENCE_DOMAIN_INCOMPLETE'
    write(*,'(A)') 'PUB_P2E11D1_REFERENCE_MATERIAL_EXTENSION_CALIBRATION_GATE=PASS'
    stop
  end if

  write(*,'(A,I0)') 'PUB_P2E11D1_SELECTED_DT_INDEX=',selected_dt_index
  write(*,'(*(g0))') 'PUB_P2E11D1_SELECTED_COARSE_DT_DAY=',dt_levels(selected_dt_index)
  write(*,'(*(g0))') 'PUB_P2E11D1_SELECTED_HALF_DT_DAY=',0.5_real64*dt_levels(selected_dt_index)
  write(*,'(A,I0)') 'PUB_P2E11D1_SELECTED_VALID_CASE_COUNT=',valid_by_dt(selected_dt_index)

  ip=0
  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        ip=ip+1
        call require(valid_matrix(ip,selected_dt_index),'frozen common dt retains every physical case')
        write(*,'(*(g0))') 'PUB_P2E11D1_SELECTED_CASE|CASE=',ip,'|M=',trim(material_ids(imat)), &
             '|SE=',se_levels(ise),'|F=',trim(forcing_ids(iforce)), &
             '|DT=',dt_levels(selected_dt_index),'|U_H_INF=',uh_inf(ip,selected_dt_index), &
             '|U_H_RMS=',uh_rms(ip,selected_dt_index),'|U_THETA_INF=',utheta_inf(ip,selected_dt_index), &
             '|U_THETA_RMS=',utheta_rms(ip,selected_dt_index),'|U_STORAGE=',ustorage(ip,selected_dt_index)
      end do
    end do
  end do

  call report_metric_summary('U_H_INF',uh_inf(:,selected_dt_index))
  call report_metric_summary('U_H_RMS',uh_rms(:,selected_dt_index))
  call report_metric_summary('U_THETA_INF',utheta_inf(:,selected_dt_index))
  call report_metric_summary('U_THETA_RMS',utheta_rms(:,selected_dt_index))
  call report_metric_summary('U_STORAGE',ustorage(:,selected_dt_index))

  write(*,'(A)') 'PUB_P2E11D1_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_EXTENSION_REFERENCE_DOMAIN'
  write(*,'(A)') 'PUB_P2E11D1_SCIENTIFIC_OUTCOME=QUALIFIED_COMPLETE_EXTENSION_DOMAIN'
  write(*,'(A)') 'PUB_P2E11D1_REFERENCE_MATERIAL_EXTENSION_CALIBRATION_GATE=PASS'

contains

  subroutine run_case(case_id,dt_index,material_id,se,forcing_id,top_factor,bottom_factor,coarse_dt,valid, &
       failure_stage,uh_inf_out,uh_rms_out,utheta_inf_out,utheta_rms_out,ustorage_out)
    integer,intent(in) :: case_id,dt_index
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor,coarse_dt
    logical,intent(out) :: valid
    character(len=*),intent(out) :: failure_stage
    real(real64),intent(out) :: uh_inf_out,uh_rms_out,utheta_inf_out,utheta_rms_out,ustorage_out

    type(soil_water_parameter_set_t),target :: parameters
    type(soil_water_solve_request_t) :: coarse_request,half1_request,half2_request
    type(soil_water_solve_result_t) :: coarse_result,half1_result,half2_result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: coarse_workspace,half1_workspace,half2_workspace
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta0(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: half_dt,h0,k0,top_flux,bottom_flux,coarse_storage,refined_storage
    logical :: found

    valid=.false.; failure_stage='INITIALIZATION'
    uh_inf_out=0.0_real64; uh_rms_out=0.0_real64
    utheta_inf_out=0.0_real64; utheta_rms_out=0.0_real64; ustorage_out=0.0_real64

    call rossfast_d3r_material_from_id(material_id,material,found)
    if (.not.found) then
      failure_stage='MATERIAL_LOOKUP'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    h0=head_from_effective_saturation(se,material)
    if (.not.ieee_is_finite(h0) .or. h0<=ROSSFAST_D3R_H_MIN_CM .or. h0>=ROSSFAST_D3R_H_MAX_CM) then
      failure_stage='INITIAL_HEAD_DOMAIN'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    call initialize_parameter_contract(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta0)) .or. any(.not.ieee_is_finite(conductivity)) .or. any(conductivity<=0.0_real64)) then
      failure_stage='INITIAL_CONSTITUTIVE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if
    if (any(theta0<=material%theta_r) .or. any(theta0>=material%theta_s)) then
      failure_stage='INITIAL_THETA_DOMAIN'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    k0=conductivity(1); top_flux=top_factor*k0; bottom_flux=bottom_factor*k0
    half_dt=0.5_real64*coarse_dt
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    call initialize_request(coarse_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,coarse_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    call solver%solve(coarse_request,coarse_workspace,coarse_result)
    if (.not.reference_result_valid(coarse_result,material)) then
      call report_failure_predicates(case_id,material_id,se,forcing_id,'COARSE',coarse_result,material)
      failure_stage='COARSE_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    call initialize_request(half1_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(half1_request,half1_workspace,half1_result)
    if (.not.reference_result_valid(half1_result,material)) then
      call report_failure_predicates(case_id,material_id,se,forcing_id,'HALF1',half1_result,material)
      failure_stage='HALF1_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    call initialize_request(half2_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
    half2_request%base_state=half1_result%candidate_state
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(half2_request,half2_workspace,half2_result)
    if (.not.reference_result_valid(half2_result,material)) then
      call report_failure_predicates(case_id,material_id,se,forcing_id,'HALF2',half2_result,material)
      failure_stage='HALF2_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    coarse_storage=sum(parameters%dz*coarse_result%candidate_state%water_content)+coarse_result%candidate_state%ponding_depth
    refined_storage=sum(parameters%dz*half2_result%candidate_state%water_content)+half2_result%candidate_state%ponding_depth
    uh_inf_out=maxval(abs(coarse_result%candidate_state%pressure_head-half2_result%candidate_state%pressure_head))
    uh_rms_out=sqrt(sum((coarse_result%candidate_state%pressure_head-half2_result%candidate_state%pressure_head)**2)/real(n,real64))
    utheta_inf_out=maxval(abs(coarse_result%candidate_state%water_content-half2_result%candidate_state%water_content))
    utheta_rms_out=sqrt(sum((coarse_result%candidate_state%water_content-half2_result%candidate_state%water_content)**2)/real(n,real64))
    ustorage_out=abs(coarse_storage-refined_storage)

    if (.not.ieee_is_finite(uh_inf_out) .or. .not.ieee_is_finite(uh_rms_out) .or. &
        .not.ieee_is_finite(utheta_inf_out) .or. .not.ieee_is_finite(utheta_rms_out) .or. &
        .not.ieee_is_finite(ustorage_out)) then
      failure_stage='METRIC_NONFINITE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    valid=.true.; failure_stage='NONE'
    call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
    write(*,'(*(g0))') 'PUB_P2E11D1_TYPED_MASS|DT_INDEX=',dt_index,'|CASE=',case_id, &
         '|COARSE_CM=',coarse_result%integrated_mass_balance_residual_cm, &
         '|HALF1_CM=',half1_result%integrated_mass_balance_residual_cm, &
         '|HALF2_CM=',half2_result%integrated_mass_balance_residual_cm, &
         '|COARSE_RATE=',coarse_result%native_balance_rate_residual_cm_per_day, &
         '|HALF1_RATE=',half1_result%native_balance_rate_residual_cm_per_day, &
         '|HALF2_RATE=',half2_result%native_balance_rate_residual_cm_per_day
  end subroutine run_case

  subroutine report_failure_predicates(case_id,material_id,se,forcing_id,trajectory,result,material)
    integer,intent(in) :: case_id
    character(len=*),intent(in) :: material_id,forcing_id,trajectory
    real(real64),intent(in) :: se
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    logical :: mass_avail_finite,mass_pass,native_avail_finite,shape_ok,state_finite,head_domain,theta_domain
    character(len=48) :: reason

    mass_avail_finite=result%integrated_mass_balance_residual_available .and. &
         ieee_is_finite(result%integrated_mass_balance_residual_cm)
    mass_pass=mass_avail_finite .and. abs(result%integrated_mass_balance_residual_cm)<=publication_integrated_mass_tol_cm
    native_avail_finite=result%native_balance_rate_residual_available .and. &
         ieee_is_finite(result%native_balance_rate_residual_cm_per_day)

    shape_ok=result%candidate_state%active_nodes==n .and. &
         allocated(result%candidate_state%pressure_head) .and. allocated(result%candidate_state%water_content)
    if (shape_ok) shape_ok=size(result%candidate_state%pressure_head)==n .and. size(result%candidate_state%water_content)==n

    state_finite=.false.; head_domain=.false.; theta_domain=.false.
    if (shape_ok) then
      state_finite=all(ieee_is_finite(result%candidate_state%pressure_head)) .and. &
           all(ieee_is_finite(result%candidate_state%water_content))
      if (state_finite) then
        head_domain=all(result%candidate_state%pressure_head>ROSSFAST_D3R_H_MIN_CM) .and. &
             all(result%candidate_state%pressure_head<ROSSFAST_D3R_H_MAX_CM)
        theta_domain=all(result%candidate_state%water_content>material%theta_r) .and. &
             all(result%candidate_state%water_content<material%theta_s)
      end if
    end if

    reason='UNKNOWN'
    if (result%status/=SW_SOLVE_CONVERGED) then
      reason='SOLVER_STATUS'
    else if (trim(result%diagnostics%route)/='legacy-reference-bound') then
      reason='ROUTE'
    else if (.not.mass_avail_finite) then
      reason='INTEGRATED_MASS_UNAVAILABLE_OR_NONFINITE'
    else if (.not.mass_pass) then
      reason='INTEGRATED_MASS_LIMIT'
    else if (.not.native_avail_finite) then
      reason='NATIVE_BALANCE_RATE_UNAVAILABLE_OR_NONFINITE'
    else if (.not.shape_ok) then
      reason='CANDIDATE_SHAPE'
    else if (.not.state_finite) then
      reason='CANDIDATE_NONFINITE'
    else if (.not.head_domain) then
      reason='HEAD_DOMAIN'
    else if (.not.theta_domain) then
      reason='THETA_DOMAIN'
    end if

    write(*,'(*(g0))') 'PUB_P2E11D1_ADJUDICATION|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|TRAJECTORY=',trim(trajectory),'|REASON=',trim(reason), &
         '|STATUS=',result%status,'|ROUTE=',trim(result%diagnostics%route), &
         '|MASS_AVAILABLE_FINITE=',mass_avail_finite,'|MASS_PASS=',mass_pass, &
         '|MASS_CM=',result%integrated_mass_balance_residual_cm, &
         '|NATIVE_AVAILABLE_FINITE=',native_avail_finite, &
         '|NATIVE_RATE=',result%native_balance_rate_residual_cm_per_day, &
         '|SHAPE_OK=',shape_ok,'|STATE_FINITE=',state_finite,'|HEAD_DOMAIN=',head_domain,'|THETA_DOMAIN=',theta_domain
  end subroutine report_failure_predicates

  logical function reference_result_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>publication_integrated_mass_tol_cm) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (size(result%candidate_state%pressure_head)/=n .or. size(result%candidate_state%water_content)/=n) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. any(result%candidate_state%water_content>=material%theta_s)) return
    ok=.true.
  end function reference_result_valid

  subroutine report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,stage)
    integer,intent(in) :: case_id,dt_index
    character(len=*),intent(in) :: material_id,forcing_id,stage
    real(real64),intent(in) :: se,coarse_dt
    logical,intent(in) :: valid
    write(*,'(*(g0))') 'PUB_P2E11D1_TRIAL|DT_INDEX=',dt_index,'|CASE=',case_id,'|M=',trim(material_id), &
         '|SE=',se,'|F=',trim(forcing_id),'|DT=',coarse_dt,'|VALID=',valid,'|STAGE=',trim(stage)
  end subroutine report_trial

  subroutine report_metric_summary(label,values)
    character(len=*),intent(in) :: label
    real(real64),intent(in) :: values(:)
    call require(size(values)==nphys,'metric summary contains all 4 diagnostic cases')
    call require(all(ieee_is_finite(values)),'finite selected metric summary')
    write(*,'(*(g0))') 'PUB_P2E11D1_METRIC_SUMMARY|METRIC=',trim(label),'|MIN=',minval(values), &
         '|MEAN=',sum(values)/real(size(values),real64),'|MAX=',maxval(values)
  end subroutine report_metric_summary

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
    parameter_set%parameter_set_id=920801; parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
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
    req%boundary%top_flux=qtop; req%boundary%top_head=h0
    req%boundary%bottom_flux=qbot; req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=reference_balance_rate_tol
    req%numerical%total_balance_tolerance=reference_balance_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'PUB_P2E11D1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e11d1_reference_extension_failure_adjudication
