program test_pub_p2e22_equal_error_reference_migration
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=6,nse=3,nforcing=2,nlevels=6,ntarget=3,nsolver=2
  integer, parameter :: n_all_cases=nmat*nse*nforcing,n_perf_cases=36
  integer, parameter :: nseg_levels(nlevels)=[1,2,4,8,16,32]
  real(real64), parameter :: target_alpha(ntarget)=[1.0_real64,0.5_real64,0.25_real64]
  character(len=12), parameter :: target_label(ntarget)=[character(len=12) :: &
       'A1_ADMISSION','A2_HALF     ','A3_QUARTER  ']
  character(len=8), parameter :: solver_label(nsolver)=[character(len=8) :: 'REF_PROD','ROSS    ']
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: ref_high_integrated_allowance_cm=1.6e-15_real64
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: prod_balance_rate_tol=1.0e-12_real64

  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: 'B01','B12','O01','O05','O14','O18']
  character(len=7), parameter :: forcing_ids(nforcing)=[character(len=7) :: 'DRYING ','NOMINAL']
  real(real64), parameter :: se_levels(nse)=[0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: qtop_factor(nforcing)=[-0.005_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(nforcing)=[-0.019_real64,-0.004_real64]

  real(real64), parameter :: th_h_inf(nse)=[ &
       0.009310899886486368_real64,0.05684414280500505_real64,0.7386357920248865_real64]
  real(real64), parameter :: th_h_rms(nse)=[ &
       0.004264337561059986_real64,0.02309047189054667_real64,0.19122530959872563_real64]
  real(real64), parameter :: th_theta_inf(nse)=[ &
       0.000017908123244203544_real64,0.00024393588764148877_real64,0.0012274135237608785_real64]
  real(real64), parameter :: th_theta_rms(nse)=[ &
       0.000006578609068585418_real64,0.00008095278187597767_real64,0.00035749599085978164_real64]
  real(real64), parameter :: th_storage(nse)=[ &
       2.1316282072803006e-14_real64,2.8421709430404007e-14_real64,2.8421709430404007e-14_real64]

  integer :: imat,ise,iforce,case_id,perf_case_id
  integer :: config_count,ref_high_count,paired_count(ntarget)
  integer :: solver_selected_count(nsolver,ntarget),solver_unresolved_count(nsolver,ntarget)
  integer :: production_valid_count(nsolver),production_invalid_count(nsolver)
  integer :: overlap_selection_changed_count,overlap_selection_unchanged_count,new_case_selection_count

  config_count=0
  ref_high_count=0
  paired_count=0
  solver_selected_count=0
  solver_unresolved_count=0
  production_valid_count=0
  production_invalid_count=0
  overlap_selection_changed_count=0
  overlap_selection_unchanged_count=0
  new_case_selection_count=0
  case_id=0
  perf_case_id=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E22_THRESHOLD|SE=',se_levels(ise), &
         '|H_INF=',th_h_inf(ise),'|H_RMS=',th_h_rms(ise), &
         '|THETA_INF=',th_theta_inf(ise),'|THETA_RMS=',th_theta_rms(ise), &
         '|STORAGE=',th_storage(ise)
  end do
  do iforce=1,ntarget
    write(*,'(*(g0))') 'PUB_P2E22_TARGET|LABEL=',trim(target_label(iforce)), &
         '|ALPHA=',target_alpha(iforce),'|STORAGE_SCALED=FALSE'
  end do

  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        case_id=case_id+1
        perf_case_id=perf_case_id+1
        call run_performance_case(perf_case_id,case_id,ise,material_ids(imat),se_levels(ise),forcing_ids(iforce), &
             qtop_factor(iforce),qbot_factor(iforce))
      end do
    end do
  end do

  call require(case_id==n_all_cases,'all 36 source cases traversed')
  call require(perf_case_id==n_perf_cases,'exact 36 final REF-HIGH cases retained')
  call require(ref_high_count==n_perf_cases,'P2E21 REF-HIGH reconstructed for all 36 cases')
  call require(config_count==n_perf_cases*nsolver*nlevels,'exact 432 production configurations attempted')

  write(*,'(A,I0)') 'PUB_P2E22_PERFORMANCE_CASE_COUNT=',perf_case_id
  write(*,'(A,I0)') 'PUB_P2E22_PRODUCTION_CONFIG_COUNT=',config_count
  write(*,'(A,I0)') 'PUB_P2E22_REF_HIGH_RECONSTRUCTION_COUNT=',ref_high_count
  do imat=1,nsolver
    write(*,'(*(g0))') 'PUB_P2E22_SOLVER_SUMMARY|SOLVER=',trim(solver_label(imat)), &
         '|VALID_CONFIGS=',production_valid_count(imat),'|INVALID_CONFIGS=',production_invalid_count(imat)
    do iforce=1,ntarget
      write(*,'(*(g0))') 'PUB_P2E22_TARGET_SUMMARY|SOLVER=',trim(solver_label(imat)), &
           '|TARGET=',trim(target_label(iforce)),'|SELECTED=',solver_selected_count(imat,iforce), &
           '|UNRESOLVED=',solver_unresolved_count(imat,iforce)
    end do
  end do
  do iforce=1,ntarget
    write(*,'(*(g0))') 'PUB_P2E22_PAIRED_SUMMARY|TARGET=',trim(target_label(iforce)), &
         '|PAIRED=',paired_count(iforce),'|UNPAIRED=',n_perf_cases-paired_count(iforce)
  end do
  write(*,'(A,I0)') 'PUB_P2E22_OVERLAP_SELECTION_CHANGED_COUNT=',overlap_selection_changed_count
  write(*,'(A,I0)') 'PUB_P2E22_OVERLAP_SELECTION_UNCHANGED_COUNT=',overlap_selection_unchanged_count
  write(*,'(A,I0)') 'PUB_P2E22_NEW_CASE_SELECTION_RECORD_COUNT=',new_case_selection_count
  write(*,'(A)') 'PUB_P2E22_TIMING_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E22_STORAGE_TARGET_SCALED=FALSE'
  write(*,'(A)') 'PUB_P2E22_ACCURACY_TARGETS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E22_CASE_POPULATION_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E22_SCIENTIFIC_RESULT_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E22_EQUAL_ERROR_REFERENCE_MIGRATION_GATE=PASS'

contains

  subroutine run_performance_case(perf_id,p2e20_id,ise,material_id,se,forcing_id,top_factor,bottom_factor)
    integer,intent(in) :: perf_id,p2e20_id,ise
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),initial_heads(n),initial_theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: ref_h(n),ref_theta(n),ref_storage,ref_max_mass
    real(real64) :: prod_h(n),prod_theta(n),prod_storage,max_mass
    real(real64) :: h0,k0,top_flux,bottom_flux
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,err_norm,storage_fraction
    real(real64) :: cumulative_top,cumulative_bottom
    integer :: isolver,ilevel,itarget,nseg,first_fail
    integer :: selected_nseg(nsolver,ntarget)
    real(real64) :: selected_error(nsolver,ntarget),selected_storage_fraction(nsolver,ntarget)
    integer :: selected_outer_calls(nsolver,ntarget),selected_nli(nsolver,ntarget)
    integer :: selected_jac(nsolver,ntarget),selected_lin(nsolver,ntarget),selected_back(nsolver,ntarget)
    integer :: selected_retries(nsolver,ntarget),selected_alt(nsolver,ntarget)
    integer :: outer_calls,nli,jac,lin,back,retries,alt
    logical :: found,ref_valid,config_valid,meets(ntarget)

    selected_nseg=0
    selected_error=huge(0.0_real64)
    selected_storage_fraction=huge(0.0_real64)
    selected_outer_calls=0; selected_nli=0; selected_jac=0; selected_lin=0
    selected_back=0; selected_retries=0; selected_alt=0

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'material authority available')
    h0=head_from_effective_saturation(se,material)
    call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM, &
         'initial head inside common domain')

    call initialize_parameter_contract(parameters,cofgen,material,p2e20_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
    initial_heads=h0
    call constitutive%evaluate(initial_heads,initial_theta,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(initial_theta)) .and. all(ieee_is_finite(conductivity)) .and. &
         all(conductivity>0.0_real64),'initial constitutive state valid')
    k0=conductivity(1)
    top_flux=top_factor*k0
    bottom_flux=bottom_factor*k0
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    call run_ref_high(parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
         initial_heads,initial_theta,top_flux,bottom_flux,ref_valid,ref_h,ref_theta,ref_storage,ref_max_mass)
    call require(ref_valid,'P2E20-qualified REF-HIGH reconstruction remains valid')
    ref_high_count=ref_high_count+1
    write(*,'(*(g0))') 'PUB_P2E22_REF_HIGH|PERF_CASE=',perf_id,'|P2E21_CASE=',p2e20_id, &
         '|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id),'|STORAGE=',ref_storage, &
         '|MAX_MASS_CM=',ref_max_mass

    do isolver=1,nsolver
      do ilevel=1,nlevels
        nseg=nseg_levels(ilevel)
        call run_production_configuration(isolver,nseg,parameters,hydraulic_parameters,constitutive,source_sink, &
             top_boundary,material,material_id,initial_heads,initial_theta,top_flux,bottom_flux, &
             config_valid,first_fail,prod_h,prod_theta,prod_storage,max_mass,cumulative_top,cumulative_bottom, &
             outer_calls,nli,jac,lin,back,retries,alt)
        config_count=config_count+1
        if (config_valid) then
          production_valid_count(isolver)=production_valid_count(isolver)+1
          call endpoint_error(ise,parameters,prod_h,prod_theta,prod_storage,ref_h,ref_theta,ref_storage, &
               dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,err_norm,storage_fraction)
          do itarget=1,ntarget
            meets(itarget)=dh_inf<=target_alpha(itarget)*th_h_inf(ise) .and. &
                 dh_rms<=target_alpha(itarget)*th_h_rms(ise) .and. &
                 dtheta_inf<=target_alpha(itarget)*th_theta_inf(ise) .and. &
                 dtheta_rms<=target_alpha(itarget)*th_theta_rms(ise) .and. &
                 dstorage<=th_storage(ise)
            if (meets(itarget) .and. selected_nseg(isolver,itarget)==0) then
              selected_nseg(isolver,itarget)=nseg
              selected_error(isolver,itarget)=err_norm
              selected_storage_fraction(isolver,itarget)=storage_fraction
              selected_outer_calls(isolver,itarget)=outer_calls
              selected_nli(isolver,itarget)=nli
              selected_jac(isolver,itarget)=jac
              selected_lin(isolver,itarget)=lin
              selected_back(isolver,itarget)=back
              selected_retries(isolver,itarget)=retries
              selected_alt(isolver,itarget)=alt
            end if
          end do
        else
          production_invalid_count(isolver)=production_invalid_count(isolver)+1
          dh_inf=0.0_real64; dh_rms=0.0_real64
          dtheta_inf=0.0_real64; dtheta_rms=0.0_real64; dstorage=0.0_real64
          err_norm=huge(0.0_real64); storage_fraction=huge(0.0_real64)
          meets=.false.
        end if

        write(*,'(*(g0))') 'PUB_P2E22_CONFIG|PERF_CASE=',perf_id,'|P2E21_CASE=',p2e20_id, &
             '|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id),'|SOLVER=',trim(solver_label(isolver)), &
             '|NSEG=',nseg,'|DT=',horizon_day/real(nseg,real64),'|VALID=',config_valid,'|FIRST_FAIL=',first_fail, &
             '|D_H_INF=',dh_inf,'|D_H_RMS=',dh_rms,'|D_THETA_INF=',dtheta_inf,'|D_THETA_RMS=',dtheta_rms, &
             '|D_STORAGE=',dstorage,'|ERROR_NORM_HEAD_THETA=',err_norm,'|STORAGE_FRACTION=',storage_fraction, &
             '|MEET_A1=',meets(1),'|MEET_A2=',meets(2),'|MEET_A3=',meets(3), &
             '|OUTER_CALLS=',outer_calls,'|NLI=',nli,'|JAC=',jac,'|LIN=',lin,'|BACKTRACK=',back, &
             '|INTERNAL_RETRIES=',retries,'|ALT_CALLS=',alt,'|MAX_MASS_CM=',max_mass, &
             '|TOP_TRANSFER=',cumulative_top,'|BOTTOM_TRANSFER=',cumulative_bottom
      end do
    end do

    do itarget=1,ntarget
      do isolver=1,nsolver
        if (selected_nseg(isolver,itarget)>0) then
          solver_selected_count(isolver,itarget)=solver_selected_count(isolver,itarget)+1
          write(*,'(*(g0))') 'PUB_P2E22_SELECTION|PERF_CASE=',perf_id,'|P2E21_CASE=',p2e20_id, &
               '|SOLVER=',trim(solver_label(isolver)),'|TARGET=',trim(target_label(itarget)), &
               '|NSEG=',selected_nseg(isolver,itarget),'|ERROR_NORM_HEAD_THETA=',selected_error(isolver,itarget), &
               '|STORAGE_FRACTION=',selected_storage_fraction(isolver,itarget), &
               '|OUTER_CALLS=',selected_outer_calls(isolver,itarget),'|NLI=',selected_nli(isolver,itarget), &
               '|JAC=',selected_jac(isolver,itarget),'|LIN=',selected_lin(isolver,itarget), &
               '|BACKTRACK=',selected_back(isolver,itarget),'|INTERNAL_RETRIES=',selected_retries(isolver,itarget), &
               '|ALT_CALLS=',selected_alt(isolver,itarget)
        else
          solver_unresolved_count(isolver,itarget)=solver_unresolved_count(isolver,itarget)+1
          write(*,'(*(g0))') 'PUB_P2E22_SELECTION|PERF_CASE=',perf_id,'|P2E21_CASE=',p2e20_id, &
               '|SOLVER=',trim(solver_label(isolver)),'|TARGET=',trim(target_label(itarget)),'|NSEG=0|UNRESOLVED=T'
        end if
      end do
      if (selected_nseg(1,itarget)>0 .and. selected_nseg(2,itarget)>0) paired_count(itarget)=paired_count(itarget)+1
      call record_migration_comparison(p2e20_id,itarget,selected_nseg(:,itarget))
    end do
  end subroutine run_performance_case

  subroutine run_ref_high(parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
       initial_heads,initial_theta,top_flux,bottom_flux,valid,final_h,final_theta,final_storage,max_mass)
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    real(real64),intent(out) :: final_h(n),final_theta(n),final_storage,max_mass
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: dt,comp_rate_tol,total_rate_tol,total_bound,current_h(n),current_theta(n),ponding
    integer :: i

    dt=horizon_day/32.0_real64
    comp_rate_tol=ref_high_integrated_allowance_cm/dt
    current_h=initial_heads; current_theta=initial_theta; ponding=0.0_real64; max_mass=0.0_real64
    valid=.false.
    do i=1,32
      total_bound=representation_total_integrated_bound(current_theta,material,parameters%dz)
      total_rate_tol=total_bound/dt
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,current_theta,current_h,ponding, &
           top_flux,bottom_flux,dt,comp_rate_tol,total_rate_tol)
      call solver%solve(request,workspace,result)
      if (.not.representation_bound_check(workspace,material)) return
      if (.not.reference_result_valid(result,request,material)) return
      max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
      current_h=result%candidate_state%pressure_head
      current_theta=result%candidate_state%water_content
      ponding=result%candidate_state%ponding_depth
    end do
    final_h=current_h; final_theta=current_theta
    final_storage=sum(parameters%dz*current_theta)+ponding
    valid=.true.
  end subroutine run_ref_high

  subroutine run_production_configuration(isolver,nseg,parameters,hydraulic_parameters,constitutive,source_sink, &
       top_boundary,material,material_id,initial_heads,initial_theta,top_flux,bottom_flux, &
       valid,first_fail,final_h,final_theta,final_storage,max_mass,cumulative_top,cumulative_bottom, &
       outer_calls,nli,jac,lin,back,retries,alt)
    integer,intent(in) :: isolver,nseg
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    character(len=*),intent(in) :: material_id
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    integer,intent(out) :: first_fail,outer_calls,nli,jac,lin,back,retries,alt
    real(real64),intent(out) :: final_h(n),final_theta(n),final_storage,max_mass,cumulative_top,cumulative_bottom

    type(reference_richards_legacy_solver_t) :: ref_solver
    type(reference_richards_legacy_workspace_t) :: ref_workspace
    type(rossfast_d3r_soil_water_solver_t) :: ross_solver
    type(rossfast_d3r_soil_water_workspace_t) :: ross_workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: dt,current_h(n),current_theta(n),ponding
    integer :: i,provider_status
    logical :: step_valid,initialized

    valid=.false.; first_fail=0
    final_h=0.0_real64; final_theta=0.0_real64; final_storage=0.0_real64
    max_mass=0.0_real64; cumulative_top=0.0_real64; cumulative_bottom=0.0_real64
    outer_calls=0; nli=0; jac=0; lin=0; back=0; retries=0; alt=0
    dt=horizon_day/real(nseg,real64)
    current_h=initial_heads; current_theta=initial_theta; ponding=0.0_real64

    initialized=.true.
    if (isolver==2) then
      call ross_solver%initialize('assets/rossfast/d3r',material_id,initialized,provider_status)
      if (.not.initialized) then
        first_fail=1
        return
      end if
    end if

    do i=1,nseg
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,current_theta,current_h,ponding, &
           top_flux,bottom_flux,dt,prod_balance_rate_tol,prod_balance_rate_tol)
      if (isolver==1) then
        call ref_solver%solve(request,ref_workspace,result)
        step_valid=reference_result_valid(result,request,material)
      else
        call ross_solver%solve(request,ross_workspace,result)
        step_valid=ross_result_valid(result,request,material)
      end if
      outer_calls=outer_calls+1
      nli=nli+max(0,result%diagnostics%nonlinear_iterations)
      jac=jac+max(0,result%diagnostics%jacobian_builds)
      lin=lin+max(0,result%diagnostics%linear_solves)
      back=back+max(0,result%diagnostics%backtracking_attempts)
      retries=retries+max(0,result%diagnostics%internal_retries)
      alt=alt+max(0,result%diagnostics%alternative_solver_calls)
      if (.not.step_valid) then
        first_fail=i
        return
      end if
      max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
      cumulative_top=cumulative_top+dt*result%top_flux
      cumulative_bottom=cumulative_bottom+dt*result%bottom_flux
      current_h=result%candidate_state%pressure_head
      current_theta=result%candidate_state%water_content
      ponding=result%candidate_state%ponding_depth
    end do

    if (.not.transfer_identity(cumulative_top,horizon_day*top_flux)) return
    if (.not.transfer_identity(cumulative_bottom,horizon_day*bottom_flux)) return
    final_h=current_h; final_theta=current_theta
    final_storage=sum(parameters%dz*current_theta)+ponding
    valid=.true.
  end subroutine run_production_configuration

  subroutine endpoint_error(ise,parameters,h,theta,storage,ref_h,ref_theta,ref_storage, &
       dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,err_norm,storage_fraction)
    integer,intent(in) :: ise
    type(soil_water_parameter_set_t),intent(in) :: parameters
    real(real64),intent(in) :: h(n),theta(n),storage,ref_h(n),ref_theta(n),ref_storage
    real(real64),intent(out) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,err_norm,storage_fraction
    if (parameters%active_nodes/=n) error stop 'P2E22 parameter cardinality'
    dh_inf=maxval(abs(h-ref_h))
    dh_rms=sqrt(sum((h-ref_h)**2)/real(n,real64))
    dtheta_inf=maxval(abs(theta-ref_theta))
    dtheta_rms=sqrt(sum((theta-ref_theta)**2)/real(n,real64))
    dstorage=abs(storage-ref_storage)
    err_norm=max(dh_inf/th_h_inf(ise),dh_rms/th_h_rms(ise), &
         dtheta_inf/th_theta_inf(ise),dtheta_rms/th_theta_rms(ise))
    storage_fraction=dstorage/th_storage(ise)
  end subroutine endpoint_error

  logical function reference_result_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>hard_mass_tol_cm) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_result_valid

  logical function ross_result_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='rossfast-d3r') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>hard_mass_tol_cm) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function ross_result_valid

  logical function state_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (size(result%candidate_state%pressure_head)/=n .or. size(result%candidate_state%water_content)/=n) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. &
        any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. &
        any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. &
        any(result%candidate_state%water_content>=material%theta_s)) return
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    ok=.true.
  end function state_valid

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,case_id)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: case_id
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=926000+case_id
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m; cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day; cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,heads,ponding, &
       qtop,qbot,dt,comp_balance_rate_tol,total_balance_rate_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),ponding,qtop,qbot,dt,comp_balance_rate_tol,total_balance_rate_tol
    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=heads
    req%base_state%water_content=theta
    req%base_state%ponding_depth=ponding
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop
    req%boundary%top_head=heads(1)
    req%boundary%bottom_flux=qbot
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=comp_balance_rate_tol
    req%numerical%total_balance_tolerance=total_balance_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  subroutine record_migration_comparison(case_id,itarget,selected)
    integer,intent(in) :: case_id,itarget
    integer,intent(in) :: selected(nsolver)
    integer :: expected_ref,expected_ross
    logical :: changed

    if (case_id==1 .or. case_id==2 .or. case_id==36) then
      new_case_selection_count=new_case_selection_count+1
      write(*,'(*(g0))') 'PUB_P2E22_MIGRATION|P2E21_CASE=',case_id,'|TARGET=',trim(target_label(itarget)), &
           '|ROLE=NEW_REF_HIGH_CASE|REF_NSEG=',selected(1),'|ROSS_NSEG=',selected(2)
      return
    end if

    expected_ref=1
    if (case_id==4 .or. case_id==18) expected_ref=2
    expected_ross=1
    changed=(selected(1)/=expected_ref .or. selected(2)/=expected_ross)
    if (changed) then
      overlap_selection_changed_count=overlap_selection_changed_count+1
    else
      overlap_selection_unchanged_count=overlap_selection_unchanged_count+1
    end if
    write(*,'(*(g0))') 'PUB_P2E22_MIGRATION|P2E21_CASE=',case_id,'|TARGET=',trim(target_label(itarget)), &
         '|ROLE=OVERLAP|REF_PREV_NSEG=',expected_ref,'|REF_NEW_NSEG=',selected(1), &
         '|ROSS_PREV_NSEG=',expected_ross,'|ROSS_NEW_NSEG=',selected(2),'|CHANGED=',changed
  end subroutine record_migration_comparison

  pure real(real64) function representation_total_integrated_bound(theta_base,material,dz) result(bound_cm)
    real(real64),intent(in) :: theta_base(n),dz(n)
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: spacing_bound
    spacing_bound=0.5_real64*sum((spacing(material%theta_s)+spacing(theta_base))*dz)
    bound_cm=max(ref_high_integrated_allowance_cm,spacing_bound)
  end function representation_total_integrated_bound

  logical function representation_bound_check(workspace,material) result(ok)
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (.not.allocated(workspace%richards%provider_theta)) return
    if (size(workspace%richards%provider_theta)/=n) return
    if (any(.not.ieee_is_finite(workspace%richards%provider_theta))) return
    if (any(workspace%richards%provider_theta<=0.0_real64)) return
    if (any(spacing(workspace%richards%provider_theta)>spacing(material%theta_s))) return
    ok=.true.
  end function representation_bound_check

  pure logical function transfer_identity(a,b)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    transfer_identity=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function transfer_identity

  pure logical function same_real(a,b)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    same_real=abs(a-b)<=32.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'PUB_P2E22_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e22_equal_error_reference_migration
