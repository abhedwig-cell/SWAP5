program test_pub_p2e16a_reference_boundary_threshold_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM, &
       ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=36, nse=3, naxis=2, nrho=6
  integer, parameter :: nphys=nmat*nse*naxis*nrho
  real(real64), parameter :: reference_balance_rate_tol = 1.0e-12_real64
  real(real64), parameter :: publication_integrated_mass_tol_cm = 1.0e-12_real64
  real(real64), parameter :: coarse_dt = 0.0064_real64
  real(real64), parameter :: scale_floor = 1.0e-12_real64

  character(len=3), parameter :: material_ids(nmat) = [character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09','O10','O11','O12','O13','O14','O15','O16','O17','O18']
  character(len=6), parameter :: axis_ids(naxis) = [character(len=6) :: 'TOP   ','BOTTOM']
  real(real64), parameter :: se_levels(nse) = [0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: rho_values(nrho) = [-1.05_real64,-1.0_real64,-0.95_real64, &
                                                  0.95_real64, 1.0_real64, 1.05_real64]

  real(real64), parameter :: th_h_inf(nse) = [ &
       0.009310899886486368_real64, 0.05684414280500505_real64, 0.7386357920248865_real64 ]
  real(real64), parameter :: th_h_rms(nse) = [ &
       0.004264337561059986_real64, 0.02309047189054667_real64, 0.19122530959872563_real64 ]
  real(real64), parameter :: th_theta_inf(nse) = [ &
       0.000017908123244203544_real64, 0.00024393588764148877_real64, 0.0012274135237608785_real64 ]
  real(real64), parameter :: th_theta_rms(nse) = [ &
       0.000006578609068585418_real64, 0.00008095278187597767_real64, 0.00035749599085978164_real64 ]
  real(real64), parameter :: th_storage(nse) = [ &
       2.1316282072803006e-14_real64, 2.8421709430404007e-14_real64, 2.8421709430404007e-14_real64 ]

  integer :: imat,ise,iaxis,irho,case_id
  integer :: inside_count,boundary_count,outside_count
  integer :: reference_valid_count,reference_invalid_count
  integer :: transfer_valid_count,transfer_fail_count
  integer :: transfer_inside,transfer_boundary,transfer_outside
  integer :: invalid_inside,invalid_boundary,invalid_outside
  logical :: reference_valid,transfer_valid
  character(len=32) :: failure_stage,contract_class
  real(real64) :: uh_inf,uh_rms,utheta_inf,utheta_rms,ustorage
  real(real64) :: max_ratio(5),ratio(5)

  inside_count=0; boundary_count=0; outside_count=0
  reference_valid_count=0; reference_invalid_count=0
  transfer_valid_count=0; transfer_fail_count=0
  transfer_inside=0; transfer_boundary=0; transfer_outside=0
  invalid_inside=0; invalid_boundary=0; invalid_outside=0
  max_ratio=0.0_real64
  case_id=0

  do imat=1,nmat
    do ise=1,nse
      do iaxis=1,naxis
        do irho=1,nrho
          case_id=case_id+1
          contract_class=classify_rho(rho_values(irho))
          select case(trim(contract_class))
          case('INSIDE'); inside_count=inside_count+1
          case('BOUNDARY'); boundary_count=boundary_count+1
          case('OUTSIDE'); outside_count=outside_count+1
          case default; call require(.false.,'unknown rho class')
          end select

          call run_case(case_id,ise,material_ids(imat),se_levels(ise),trim(axis_ids(iaxis)),rho_values(irho), &
               reference_valid,transfer_valid,failure_stage,uh_inf,uh_rms,utheta_inf,utheta_rms,ustorage)

          if (reference_valid) then
            reference_valid_count=reference_valid_count+1
            ratio = [uh_inf/th_h_inf(ise), uh_rms/th_h_rms(ise), utheta_inf/th_theta_inf(ise), &
                     utheta_rms/th_theta_rms(ise), ustorage/th_storage(ise)]
            max_ratio=max(max_ratio,ratio)
            if (transfer_valid) then
              transfer_valid_count=transfer_valid_count+1
              select case(trim(contract_class))
              case('INSIDE'); transfer_inside=transfer_inside+1
              case('BOUNDARY'); transfer_boundary=transfer_boundary+1
              case('OUTSIDE'); transfer_outside=transfer_outside+1
              end select
            else
              transfer_fail_count=transfer_fail_count+1
            end if
          else
            reference_invalid_count=reference_invalid_count+1
            select case(trim(contract_class))
            case('INSIDE'); invalid_inside=invalid_inside+1
            case('BOUNDARY'); invalid_boundary=invalid_boundary+1
            case('OUTSIDE'); invalid_outside=invalid_outside+1
            end select
          end if
        end do
      end do
    end do
  end do

  call require(case_id==nphys,'exact 1296 Reference-only boundary cases attempted')
  call require(inside_count==432 .and. boundary_count==432 .and. outside_count==432, &
       'exact preregistered rho class counts retained')
  call require(reference_valid_count+reference_invalid_count==nphys,'every case has Reference validity classification')
  call require(transfer_valid_count+transfer_fail_count==reference_valid_count, &
       'every Reference-valid case has threshold-transfer classification')

  write(*,'(A,I0)') 'PUB_P2E16A_PHYSICAL_CASE_COUNT=',nphys
  write(*,'(A,I0)') 'PUB_P2E16A_MATERIAL_COUNT=',nmat
  write(*,'(A,I0)') 'PUB_P2E16A_SE_LEVEL_COUNT=',nse
  write(*,'(A,I0)') 'PUB_P2E16A_BOUNDARY_AXIS_COUNT=',naxis
  write(*,'(A,I0)') 'PUB_P2E16A_RHO_LEVEL_COUNT=',nrho
  write(*,'(A,I0)') 'PUB_P2E16A_INSIDE_COUNT=',inside_count
  write(*,'(A,I0)') 'PUB_P2E16A_BOUNDARY_COUNT=',boundary_count
  write(*,'(A,I0)') 'PUB_P2E16A_OUTSIDE_COUNT=',outside_count
  write(*,'(A,I0)') 'PUB_P2E16A_REFERENCE_VALID_COUNT=',reference_valid_count
  write(*,'(A,I0)') 'PUB_P2E16A_REFERENCE_INVALID_COUNT=',reference_invalid_count
  write(*,'(A,I0)') 'PUB_P2E16A_TRANSFER_VALID_COUNT=',transfer_valid_count
  write(*,'(A,I0)') 'PUB_P2E16A_TRANSFER_FAIL_COUNT=',transfer_fail_count
  write(*,'(A,I0)') 'PUB_P2E16A_TRANSFER_VALID_INSIDE=',transfer_inside
  write(*,'(A,I0)') 'PUB_P2E16A_TRANSFER_VALID_BOUNDARY=',transfer_boundary
  write(*,'(A,I0)') 'PUB_P2E16A_TRANSFER_VALID_OUTSIDE=',transfer_outside
  write(*,'(A,I0)') 'PUB_P2E16A_REFERENCE_INVALID_INSIDE=',invalid_inside
  write(*,'(A,I0)') 'PUB_P2E16A_REFERENCE_INVALID_BOUNDARY=',invalid_boundary
  write(*,'(A,I0)') 'PUB_P2E16A_REFERENCE_INVALID_OUTSIDE=',invalid_outside
  write(*,'(*(g0))') 'PUB_P2E16A_MAX_THRESHOLD_FRACTION|D_H_INF=',max_ratio(1), &
       '|D_H_RMS=',max_ratio(2),'|D_THETA_INF=',max_ratio(3),'|D_THETA_RMS=',max_ratio(4), &
       '|D_STORAGE=',max_ratio(5)
  write(*,'(A)') 'PUB_P2E16A_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E16A_P2E14_THRESHOLDS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16A_SCIENTIFIC_FAILURE_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E16A_REFERENCE_BOUNDARY_THRESHOLD_TRANSFER_GATE=PASS'

contains

  subroutine run_case(case_id,ise,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage, &
       uh_inf_out,uh_rms_out,utheta_inf_out,utheta_rms_out,ustorage_out)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,axis_id
    real(real64),intent(in) :: se,rho
    logical,intent(out) :: reference_valid,transfer_valid
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
    real(real64) :: half_dt,h0,k_top,k_bottom,top_flux,bottom_flux
    real(real64) :: qtop_ref_internal,qbottom_ref,top_scale,bottom_scale,top_limit,bottom_limit
    real(real64) :: reconstructed_rho,coarse_storage,refined_storage
    logical :: found

    reference_valid=.false.; transfer_valid=.false.; failure_stage='INITIALIZATION'
    uh_inf_out=0.0_real64; uh_rms_out=0.0_real64
    utheta_inf_out=0.0_real64; utheta_rms_out=0.0_real64; ustorage_out=0.0_real64

    call rossfast_d3r_material_from_id(material_id,material,found)
    if (.not.found) then
      failure_stage='MATERIAL_LOOKUP'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,0.0_real64,0.0_real64)
      return
    end if

    h0=head_from_effective_saturation(se,material)
    if (.not.ieee_is_finite(h0) .or. h0<=ROSSFAST_D3R_H_MIN_CM .or. h0>=ROSSFAST_D3R_H_MAX_CM) then
      failure_stage='INITIAL_HEAD_DOMAIN'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,0.0_real64,0.0_real64)
      return
    end if

    call initialize_parameter_contract(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta0)) .or. any(.not.ieee_is_finite(conductivity)) .or. any(conductivity<=0.0_real64)) then
      failure_stage='INITIAL_CONSTITUTIVE'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,0.0_real64,0.0_real64)
      return
    end if
    if (any(theta0<=material%theta_r) .or. any(theta0>=material%theta_s)) then
      failure_stage='INITIAL_THETA_DOMAIN'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,0.0_real64,0.0_real64)
      return
    end if

    k_top=conductivity(1); k_bottom=conductivity(n)
    qtop_ref_internal=0.01_real64*k_top
    qbottom_ref=-0.004_real64*k_bottom
    top_scale=max(abs(qtop_ref_internal),abs(k_top),scale_floor)
    bottom_scale=max(abs(qbottom_ref),abs(k_bottom),scale_floor)
    top_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*top_scale
    bottom_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*bottom_scale

    select case(trim(axis_id))
    case('TOP')
      top_flux=-(qtop_ref_internal+rho*top_limit)
      bottom_flux=qbottom_ref
      reconstructed_rho=((-top_flux)-qtop_ref_internal)/top_limit
    case('BOTTOM')
      top_flux=-qtop_ref_internal
      bottom_flux=qbottom_ref+rho*bottom_limit
      reconstructed_rho=(bottom_flux-qbottom_ref)/bottom_limit
    case default
      call require(.false.,'unknown boundary axis')
    end select
    call require(ieee_is_finite(top_flux) .and. ieee_is_finite(bottom_flux),'finite constructed boundary forcing')
    call require(abs(reconstructed_rho-rho)<=1.0e-12_real64,'constructed forcing reproduces preregistered rho')

    half_dt=0.5_real64*coarse_dt
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    call initialize_request(coarse_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,coarse_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    call solver%solve(coarse_request,coarse_workspace,coarse_result)
    if (.not.reference_result_valid(coarse_result,material)) then
      failure_stage='COARSE_REFERENCE_GATE'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,top_flux,bottom_flux)
      return
    end if

    call initialize_request(half1_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(half1_request,half1_workspace,half1_result)
    if (.not.reference_result_valid(half1_result,material)) then
      failure_stage='HALF1_REFERENCE_GATE'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,top_flux,bottom_flux)
      return
    end if

    call initialize_request(half2_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
    half2_request%base_state=half1_result%candidate_state
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(half2_request,half2_workspace,half2_result)
    if (.not.reference_result_valid(half2_result,material)) then
      failure_stage='HALF2_REFERENCE_GATE'
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,top_flux,bottom_flux)
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
      call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,top_flux,bottom_flux)
      return
    end if

    reference_valid=.true.
    transfer_valid = uh_inf_out<=th_h_inf(ise) .and. uh_rms_out<=th_h_rms(ise) .and. &
         utheta_inf_out<=th_theta_inf(ise) .and. utheta_rms_out<=th_theta_rms(ise) .and. &
         ustorage_out<=th_storage(ise)
    if (transfer_valid) then
      failure_stage='NONE'
    else
      failure_stage='P2E14_THRESHOLD_TRANSFER'
    end if

    call report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,failure_stage,top_flux,bottom_flux)
    write(*,'(*(g0))') 'PUB_P2E16A_METRICS|CASE=',case_id,'|U_H_INF=',uh_inf_out,'|U_H_RMS=',uh_rms_out, &
         '|U_THETA_INF=',utheta_inf_out,'|U_THETA_RMS=',utheta_rms_out,'|U_STORAGE=',ustorage_out
    write(*,'(*(g0))') 'PUB_P2E16A_TYPED_MASS|CASE=',case_id, &
         '|COARSE_CM=',coarse_result%integrated_mass_balance_residual_cm, &
         '|HALF1_CM=',half1_result%integrated_mass_balance_residual_cm, &
         '|HALF2_CM=',half2_result%integrated_mass_balance_residual_cm
  end subroutine run_case

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
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. &
        any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. &
        any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. &
        any(result%candidate_state%water_content>=material%theta_s)) return
    ok=.true.
  end function reference_result_valid

  character(len=32) function classify_rho(rho) result(label)
    real(real64),intent(in) :: rho
    if (abs(rho)<1.0_real64) then
      label='INSIDE'
    else if (abs(rho)==1.0_real64) then
      label='BOUNDARY'
    else
      label='OUTSIDE'
    end if
  end function classify_rho

  subroutine report_trial(case_id,material_id,se,axis_id,rho,reference_valid,transfer_valid,stage,qtop,qbot)
    integer,intent(in) :: case_id
    character(len=*),intent(in) :: material_id,axis_id,stage
    real(real64),intent(in) :: se,rho,qtop,qbot
    logical,intent(in) :: reference_valid,transfer_valid
    write(*,'(*(g0))') 'PUB_P2E16A_TRIAL|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|AXIS=',trim(axis_id),'|RHO=',rho,'|CLASS=',trim(classify_rho(rho)), &
         '|QTOP=',qtop,'|QBOT=',qbot,'|REFERENCE_VALID=',reference_valid, &
         '|TRANSFER_VALID=',transfer_valid,'|STAGE=',trim(stage)
  end subroutine report_trial

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
    parameter_set%parameter_set_id=921601; parameter_set%active_nodes=n
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
      write(*,'(A,1X,A)') 'PUB_P2E16A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e16a_reference_boundary_threshold_transfer
