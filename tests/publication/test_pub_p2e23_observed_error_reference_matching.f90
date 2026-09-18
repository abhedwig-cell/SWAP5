program test_pub_p2e23_observed_error_reference_matching
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
  integer, parameter :: nmat=6,nse=3,nforcing=2,ncases=nmat*nse*nforcing
  integer, parameter :: nref_levels=32
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: ref_integrated_allowance_cm=1.6e-15_real64
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: ross_balance_rate_tol=1.0e-12_real64

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

  integer :: imat,ise,iforce,case_id
  integer :: ref_high_count,ross_anchor_count,ref_config_count,ref_valid_count,ref_invalid_count
  integer :: bracketed_count,left_censored_count,upper_only_gap_count,only_n32_count,unresolved_count
  integer :: nonmonotone_case_count
  integer :: nhi_hist(nref_levels)

  ref_high_count=0
  ross_anchor_count=0
  ref_config_count=0
  ref_valid_count=0
  ref_invalid_count=0
  bracketed_count=0
  left_censored_count=0
  upper_only_gap_count=0
  only_n32_count=0
  unresolved_count=0
  nonmonotone_case_count=0
  nhi_hist=0
  case_id=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E23_THRESHOLD|SE=',se_levels(ise), &
         '|H_INF=',th_h_inf(ise),'|H_RMS=',th_h_rms(ise), &
         '|THETA_INF=',th_theta_inf(ise),'|THETA_RMS=',th_theta_rms(ise), &
         '|STORAGE=',th_storage(ise)
  end do

  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        case_id=case_id+1
        call run_case(case_id,ise,material_ids(imat),se_levels(ise),forcing_ids(iforce), &
             qtop_factor(iforce),qbot_factor(iforce))
      end do
    end do
  end do

  call require(case_id==ncases,'all 36 cases attempted')
  call require(ref_high_count==ncases,'all 36 P2E21 REF-HIGH endpoints reconstructed')
  call require(ross_anchor_count==ncases,'all 36 frozen RossFast N1 anchors reproduced')
  call require(ref_config_count==ncases*nref_levels,'all 1152 Reference matching configurations attempted')

  write(*,'(A,I0)') 'PUB_P2E23_CASE_COUNT=',case_id
  write(*,'(A,I0)') 'PUB_P2E23_REF_HIGH_COUNT=',ref_high_count
  write(*,'(A,I0)') 'PUB_P2E23_ROSS_ANCHOR_COUNT=',ross_anchor_count
  write(*,'(A,I0)') 'PUB_P2E23_REFERENCE_CONFIG_COUNT=',ref_config_count
  write(*,'(A,I0)') 'PUB_P2E23_REFERENCE_VALID_COUNT=',ref_valid_count
  write(*,'(A,I0)') 'PUB_P2E23_REFERENCE_INVALID_COUNT=',ref_invalid_count
  write(*,'(A,I0)') 'PUB_P2E23_BRACKETED_COUNT=',bracketed_count
  write(*,'(A,I0)') 'PUB_P2E23_LEFT_CENSORED_COUNT=',left_censored_count
  write(*,'(A,I0)') 'PUB_P2E23_UPPER_ONLY_ROUTE_GAP_COUNT=',upper_only_gap_count
  write(*,'(A,I0)') 'PUB_P2E23_MATCH_ONLY_AT_N32_COUNT=',only_n32_count
  write(*,'(A,I0)') 'PUB_P2E23_UNRESOLVED_COUNT=',unresolved_count
  write(*,'(A,I0)') 'PUB_P2E23_NONMONOTONE_CASE_COUNT=',nonmonotone_case_count
  do imat=1,nref_levels
    if (nhi_hist(imat)>0) then
      write(*,'(*(g0))') 'PUB_P2E23_NHI_HIST|N=',imat,'|COUNT=',nhi_hist(imat)
    end if
  end do
  write(*,'(A)') 'PUB_P2E23_TIMING_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E23_CLOSEST_RATIO_USED_FOR_SELECTION=FALSE'
  write(*,'(A)') 'PUB_P2E23_CONTROL_LEVELS_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E23_CASE_POPULATION_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E23_SCIENTIFIC_RESULT_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E23_OBSERVED_ERROR_REFERENCE_MATCHING_GATE=PASS'

contains

  subroutine run_case(case_id,ise,material_id,se,forcing_id,top_factor,bottom_factor)
    integer,intent(in) :: case_id,ise
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
    real(real64) :: ref_h(n),ref_theta(n),ref_storage,ref_high_mass
    real(real64) :: ross_h(n),ross_theta(n),ross_storage,ross_mass,ross_top_transfer,ross_bottom_transfer
    real(real64) :: match_h(n),match_theta(n),match_storage,match_mass,match_top_transfer,match_bottom_transfer
    real(real64) :: h0,k0,top_flux,bottom_flux
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,ross_error,ross_storage_fraction
    real(real64) :: ref_error,ref_storage_fraction,ratio_hi,ratio_lo
    real(real64) :: prev_valid_error
    integer :: nseg,n_hi,n_lo,first_fail
    integer :: ross_outer,ross_nli,ross_jac,ross_lin,ross_back,ross_retries,ross_alt
    integer :: ref_outer,ref_nli,ref_jac,ref_lin,ref_back,ref_retries,ref_alt
    integer :: hi_outer,hi_nli,hi_jac,hi_lin,hi_back,hi_retries,hi_alt
    integer :: lo_outer,lo_nli,lo_jac,lo_lin,lo_back,lo_retries,lo_alt
    logical :: found,ref_high_valid,ross_valid,ref_valid,storage_ok,crossing
    logical :: have_prev_valid,nonmonotone
    character(len=32) :: classification

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'material authority available')
    h0=head_from_effective_saturation(se,material)
    call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM, &
         'initial head inside common domain')

    call initialize_parameter_contract(parameters,cofgen,material,case_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
    initial_heads=h0
    call constitutive%evaluate(initial_heads,initial_theta,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(initial_theta)) .and. all(ieee_is_finite(conductivity)) .and. &
         all(conductivity>0.0_real64),'initial constitutive state valid')
    k0=conductivity(1)
    top_flux=top_factor*k0
    bottom_flux=bottom_factor*k0
    drainage=0.0_real64
    irrigation=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    call run_reference_configuration(32,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
         initial_heads,initial_theta,top_flux,bottom_flux,ref_high_valid,first_fail,ref_h,ref_theta,ref_storage, &
         ref_high_mass,match_top_transfer,match_bottom_transfer,ref_outer,ref_nli,ref_jac,ref_lin,ref_back,ref_retries,ref_alt)
    call require(ref_high_valid,'P2E21 REF-HIGH N32 reconstruction remains valid')
    ref_high_count=ref_high_count+1
    write(*,'(*(g0))') 'PUB_P2E23_REF_HIGH|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|STORAGE=',ref_storage,'|MAX_MASS_CM=',ref_high_mass,'|OUTER_CALLS=',ref_outer,'|NLI=',ref_nli, &
         '|JAC=',ref_jac,'|LIN=',ref_lin,'|BACKTRACK=',ref_back,'|INTERNAL_RETRIES=',ref_retries

    call run_ross_anchor(material_id,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
         initial_heads,initial_theta,top_flux,bottom_flux,ross_valid,first_fail,ross_h,ross_theta,ross_storage,ross_mass, &
         ross_top_transfer,ross_bottom_transfer,ross_outer,ross_nli,ross_jac,ross_lin,ross_back,ross_retries,ross_alt)
    call require(ross_valid,'P2E22 frozen RossFast N1 anchor remains valid')
    call endpoint_error(ise,parameters,ross_h,ross_theta,ross_storage,ref_h,ref_theta,ref_storage, &
         dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,ross_error,ross_storage_fraction)
    call require(ross_storage_fraction<=1.0_real64,'P2E22 RossFast N1 storage gate remains valid')
    ross_anchor_count=ross_anchor_count+1
    write(*,'(*(g0))') 'PUB_P2E23_ROSS|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|E=',ross_error,'|STORAGE_FRACTION=',ross_storage_fraction,'|D_H_INF=',dh_inf,'|D_H_RMS=',dh_rms, &
         '|D_THETA_INF=',dtheta_inf,'|D_THETA_RMS=',dtheta_rms,'|D_STORAGE=',dstorage, &
         '|OUTER_CALLS=',ross_outer,'|NLI=',ross_nli,'|JAC=',ross_jac,'|LIN=',ross_lin, &
         '|BACKTRACK=',ross_back,'|INTERNAL_RETRIES=',ross_retries,'|ALT_CALLS=',ross_alt,'|MAX_MASS_CM=',ross_mass

    n_hi=0
    n_lo=0
    ratio_hi=huge(0.0_real64)
    ratio_lo=0.0_real64
    hi_outer=0;hi_nli=0;hi_jac=0;hi_lin=0;hi_back=0;hi_retries=0;hi_alt=0
    lo_outer=0;lo_nli=0;lo_jac=0;lo_lin=0;lo_back=0;lo_retries=0;lo_alt=0
    have_prev_valid=.false.
    prev_valid_error=0.0_real64
    nonmonotone=.false.

    do nseg=1,nref_levels
      call run_reference_configuration(nseg,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
           initial_heads,initial_theta,top_flux,bottom_flux,ref_valid,first_fail,match_h,match_theta,match_storage, &
           match_mass,match_top_transfer,match_bottom_transfer,ref_outer,ref_nli,ref_jac,ref_lin,ref_back,ref_retries,ref_alt)
      ref_config_count=ref_config_count+1
      if (ref_valid) then
        ref_valid_count=ref_valid_count+1
        call endpoint_error(ise,parameters,match_h,match_theta,match_storage,ref_h,ref_theta,ref_storage, &
             dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,ref_error,ref_storage_fraction)
        storage_ok=ref_storage_fraction<=1.0_real64
        crossing=storage_ok .and. ref_error<=ross_error

        if (have_prev_valid) then
          if (ref_error > prev_valid_error + 64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(ref_error),abs(prev_valid_error))) then
            nonmonotone=.true.
          end if
        end if
        if (storage_ok) then
          have_prev_valid=.true.
          prev_valid_error=ref_error
        end if

        if (n_hi==0) then
          if (crossing) then
            n_hi=nseg
            ratio_hi=safe_ratio(ref_error,ross_error)
            hi_outer=ref_outer;hi_nli=ref_nli;hi_jac=ref_jac;hi_lin=ref_lin
            hi_back=ref_back;hi_retries=ref_retries;hi_alt=ref_alt
          else if (storage_ok .and. ref_error>ross_error) then
            n_lo=nseg
            ratio_lo=safe_ratio(ref_error,ross_error)
            lo_outer=ref_outer;lo_nli=ref_nli;lo_jac=ref_jac;lo_lin=ref_lin
            lo_back=ref_back;lo_retries=ref_retries;lo_alt=ref_alt
          end if
        end if
      else
        ref_invalid_count=ref_invalid_count+1
        dh_inf=0.0_real64;dh_rms=0.0_real64;dtheta_inf=0.0_real64;dtheta_rms=0.0_real64
        dstorage=0.0_real64;ref_error=huge(0.0_real64);ref_storage_fraction=huge(0.0_real64)
        storage_ok=.false.;crossing=.false.
      end if

      write(*,'(*(g0))') 'PUB_P2E23_REF_CONFIG|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
           '|N=',nseg,'|DT=',horizon_day/real(nseg,real64),'|VALID=',ref_valid,'|FIRST_FAIL=',first_fail, &
           '|E=',ref_error,'|STORAGE_FRACTION=',ref_storage_fraction,'|STORAGE_OK=',storage_ok,'|CROSSING=',crossing, &
           '|D_H_INF=',dh_inf,'|D_H_RMS=',dh_rms,'|D_THETA_INF=',dtheta_inf,'|D_THETA_RMS=',dtheta_rms, &
           '|D_STORAGE=',dstorage,'|OUTER_CALLS=',ref_outer,'|NLI=',ref_nli,'|JAC=',ref_jac,'|LIN=',ref_lin, &
           '|BACKTRACK=',ref_back,'|INTERNAL_RETRIES=',ref_retries,'|ALT_CALLS=',ref_alt,'|MAX_MASS_CM=',match_mass
    end do

    if (nonmonotone) nonmonotone_case_count=nonmonotone_case_count+1

    classification='UNRESOLVED'
    if (n_hi==0) then
      unresolved_count=unresolved_count+1
    else
      nhi_hist(n_hi)=nhi_hist(n_hi)+1
      if (n_hi==1) then
        classification='LEFT_CENSORED_AT_N1'
        left_censored_count=left_censored_count+1
      else if (n_hi==32) then
        classification='MATCH_ONLY_AT_REF_HIGH_N32'
        only_n32_count=only_n32_count+1
      else if (n_lo>0) then
        classification='BRACKETED'
        bracketed_count=bracketed_count+1
      else
        classification='UPPER_ONLY_ROUTE_GAP'
        upper_only_gap_count=upper_only_gap_count+1
      end if
    end if

    write(*,'(*(g0))') 'PUB_P2E23_MATCH|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|CLASS=',trim(classification),'|ROSS_E=',ross_error,'|N_LO=',n_lo,'|N_HI=',n_hi, &
         '|LO_OVER_ROSS=',ratio_lo,'|HI_OVER_ROSS=',ratio_hi,'|NONMONOTONE=',nonmonotone, &
         '|ROSS_OUTER=',ross_outer,'|ROSS_NLI=',ross_nli,'|ROSS_JAC=',ross_jac,'|ROSS_LIN=',ross_lin, &
         '|ROSS_BACKTRACK=',ross_back,'|ROSS_RETRIES=',ross_retries,'|ROSS_ALT=',ross_alt, &
         '|LO_OUTER=',lo_outer,'|LO_NLI=',lo_nli,'|LO_JAC=',lo_jac,'|LO_LIN=',lo_lin,'|LO_BACKTRACK=',lo_back, &
         '|LO_RETRIES=',lo_retries,'|LO_ALT=',lo_alt, &
         '|HI_OUTER=',hi_outer,'|HI_NLI=',hi_nli,'|HI_JAC=',hi_jac,'|HI_LIN=',hi_lin,'|HI_BACKTRACK=',hi_back, &
         '|HI_RETRIES=',hi_retries,'|HI_ALT=',hi_alt
  end subroutine run_case

  subroutine run_reference_configuration(nseg,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
       initial_heads,initial_theta,top_flux,bottom_flux,valid,first_fail,final_h,final_theta,final_storage,max_mass, &
       cumulative_top,cumulative_bottom,outer_calls,nli,jac,lin,back,retries,alt)
    integer,intent(in) :: nseg
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    integer,intent(out) :: first_fail,outer_calls,nli,jac,lin,back,retries,alt
    real(real64),intent(out) :: final_h(n),final_theta(n),final_storage,max_mass,cumulative_top,cumulative_bottom

    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: current_h(n),current_theta(n),ponding,dt,comp_rate,total_bound,total_rate
    integer :: i
    logical :: step_valid

    valid=.false.;first_fail=0
    final_h=0.0_real64;final_theta=0.0_real64;final_storage=0.0_real64
    max_mass=0.0_real64;cumulative_top=0.0_real64;cumulative_bottom=0.0_real64
    outer_calls=0;nli=0;jac=0;lin=0;back=0;retries=0;alt=0
    current_h=initial_heads;current_theta=initial_theta;ponding=0.0_real64
    dt=horizon_day/real(nseg,real64)
    comp_rate=ref_integrated_allowance_cm/dt

    do i=1,nseg
      total_bound=representation_total_integrated_bound(current_theta,material,parameters%dz)
      total_rate=total_bound/dt
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,current_theta,current_h,ponding, &
           top_flux,bottom_flux,dt,comp_rate,total_rate)
      call solver%solve(request,workspace,result)

      outer_calls=outer_calls+1
      nli=nli+max(0,result%diagnostics%nonlinear_iterations)
      jac=jac+max(0,result%diagnostics%jacobian_builds)
      lin=lin+max(0,result%diagnostics%linear_solves)
      back=back+max(0,result%diagnostics%backtracking_attempts)
      retries=retries+max(0,result%diagnostics%internal_retries)
      alt=alt+max(0,result%diagnostics%alternative_solver_calls)

      step_valid=representation_bound_check(workspace,material)
      if (step_valid) step_valid=reference_result_valid(result,request,material)
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
    final_h=current_h
    final_theta=current_theta
    final_storage=sum(parameters%dz*current_theta)+ponding
    valid=.true.
  end subroutine run_reference_configuration

  subroutine run_ross_anchor(material_id,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary,material, &
       initial_heads,initial_theta,top_flux,bottom_flux,valid,first_fail,final_h,final_theta,final_storage,max_mass, &
       cumulative_top,cumulative_bottom,outer_calls,nli,jac,lin,back,retries,alt)
    character(len=*),intent(in) :: material_id
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    integer,intent(out) :: first_fail,outer_calls,nli,jac,lin,back,retries,alt
    real(real64),intent(out) :: final_h(n),final_theta(n),final_storage,max_mass,cumulative_top,cumulative_bottom

    type(rossfast_d3r_soil_water_solver_t) :: solver
    type(rossfast_d3r_soil_water_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    integer :: provider_status
    logical :: initialized

    valid=.false.;first_fail=0
    final_h=0.0_real64;final_theta=0.0_real64;final_storage=0.0_real64
    max_mass=0.0_real64;cumulative_top=0.0_real64;cumulative_bottom=0.0_real64
    outer_calls=0;nli=0;jac=0;lin=0;back=0;retries=0;alt=0

    call solver%initialize('assets/rossfast/d3r',material_id,initialized,provider_status)
    if (.not.initialized) then
      first_fail=1
      return
    end if

    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,initial_theta,initial_heads,0.0_real64, &
         top_flux,bottom_flux,horizon_day,ross_balance_rate_tol,ross_balance_rate_tol)
    call solver%solve(request,workspace,result)

    outer_calls=1
    nli=max(0,result%diagnostics%nonlinear_iterations)
    jac=max(0,result%diagnostics%jacobian_builds)
    lin=max(0,result%diagnostics%linear_solves)
    back=max(0,result%diagnostics%backtracking_attempts)
    retries=max(0,result%diagnostics%internal_retries)
    alt=max(0,result%diagnostics%alternative_solver_calls)

    if (.not.ross_result_valid(result,request,material)) then
      first_fail=1
      return
    end if
    max_mass=abs(result%integrated_mass_balance_residual_cm)
    cumulative_top=horizon_day*result%top_flux
    cumulative_bottom=horizon_day*result%bottom_flux
    if (.not.transfer_identity(cumulative_top,horizon_day*top_flux)) return
    if (.not.transfer_identity(cumulative_bottom,horizon_day*bottom_flux)) return
    final_h=result%candidate_state%pressure_head
    final_theta=result%candidate_state%water_content
    final_storage=sum(parameters%dz*final_theta)+result%candidate_state%ponding_depth
    valid=.true.
  end subroutine run_ross_anchor

  subroutine endpoint_error(ise,parameters,h,theta,storage,ref_h,ref_theta,ref_storage, &
       dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,err_norm,storage_fraction)
    integer,intent(in) :: ise
    type(soil_water_parameter_set_t),intent(in) :: parameters
    real(real64),intent(in) :: h(n),theta(n),storage,ref_h(n),ref_theta(n),ref_storage
    real(real64),intent(out) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage,err_norm,storage_fraction
    if (parameters%active_nodes/=n) error stop 'P2E23 parameter cardinality'
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
    parameter_set%parameter_set_id=927000+case_id
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r
      cofgen_out(2,i)=mat%theta_s
      cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm
      cofgen_out(5,i)=mat%lambda
      cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm
      cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64
      cofgen_out(23,i)=1.0e-12_real64
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

  pure real(real64) function representation_total_integrated_bound(theta_base,material,dz) result(bound_cm)
    real(real64),intent(in) :: theta_base(n),dz(n)
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: spacing_bound
    spacing_bound=0.5_real64*sum((spacing(material%theta_s)+spacing(theta_base))*dz)
    bound_cm=max(ref_integrated_allowance_cm,spacing_bound)
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

  pure real(real64) function safe_ratio(a,b) result(r)
    real(real64),intent(in) :: a,b
    if (b>0.0_real64) then
      r=a/b
    else if (a==0.0_real64) then
      r=1.0_real64
    else
      r=huge(1.0_real64)
    end if
  end function safe_ratio

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
      write(*,'(A,1X,A)') 'PUB_P2E23_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e23_observed_error_reference_matching
