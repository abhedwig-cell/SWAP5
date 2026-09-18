program test_pub_p2e18_ref_high_construction
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

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=6, nse=3, nforcing=2, nlevels=6, ncases=nmat*nse*nforcing
  integer, parameter :: nsub_levels(nlevels)=[1,2,4,8,16,32]
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: reference_balance_rate_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: stability_factor=0.10_real64

  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: 'B01','B12','O01','O05','O14','O18']
  character(len=7), parameter :: forcing_ids(nforcing)=[character(len=7) :: 'DRYING ','NOMINAL']
  real(real64), parameter :: se_levels(nse)=[0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: qtop_factor(nforcing)=[-0.005_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(nforcing)=[-0.019_real64,-0.004_real64]

  real(real64), parameter :: p2e14_h_inf(nse)=[ &
       0.009310899886486368_real64,0.05684414280500505_real64,0.7386357920248865_real64]
  real(real64), parameter :: p2e14_h_rms(nse)=[ &
       0.004264337561059986_real64,0.02309047189054667_real64,0.19122530959872563_real64]
  real(real64), parameter :: p2e14_theta_inf(nse)=[ &
       0.000017908123244203544_real64,0.00024393588764148877_real64,0.0012274135237608785_real64]
  real(real64), parameter :: p2e14_theta_rms(nse)=[ &
       0.000006578609068585418_real64,0.00008095278187597767_real64,0.00035749599085978164_real64]
  real(real64), parameter :: p2e14_storage(nse)=[ &
       2.1316282072803006e-14_real64,2.842170943040401e-14_real64,2.8421709430404007e-14_real64]

  integer :: imat,ise,iforce,case_id,stable_count,unresolved_count
  logical :: stable
  character(len=40) :: failure_stage

  stable_count=0
  unresolved_count=0
  case_id=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E18_STABILITY_THRESHOLD|SE=',se_levels(ise), &
         '|D_H_INF=',stability_factor*p2e14_h_inf(ise), &
         '|D_H_RMS=',stability_factor*p2e14_h_rms(ise), &
         '|D_THETA_INF=',stability_factor*p2e14_theta_inf(ise), &
         '|D_THETA_RMS=',stability_factor*p2e14_theta_rms(ise), &
         '|D_STORAGE=',p2e14_storage(ise)
  end do

  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        case_id=case_id+1
        call run_case(case_id,ise,material_ids(imat),se_levels(ise),forcing_ids(iforce), &
             qtop_factor(iforce),qbot_factor(iforce),stable,failure_stage)
        if (stable) then
          stable_count=stable_count+1
        else
          unresolved_count=unresolved_count+1
        end if
      end do
    end do
  end do

  call require(case_id==ncases,'exact 36 REF-HIGH cases attempted')
  call require(stable_count+unresolved_count==ncases,'every REF-HIGH case classified')

  write(*,'(A,I0)') 'PUB_P2E18_CASE_COUNT=',ncases
  write(*,'(A,I0)') 'PUB_P2E18_MATERIAL_COUNT=',nmat
  write(*,'(A,I0)') 'PUB_P2E18_SE_LEVEL_COUNT=',nse
  write(*,'(A,I0)') 'PUB_P2E18_FORCING_COUNT=',nforcing
  write(*,'(A,I0)') 'PUB_P2E18_REFINEMENT_LEVEL_COUNT=',nlevels
  write(*,'(A,I0)') 'PUB_P2E18_REF_HIGH_SUBSTEPS=',nsub_levels(nlevels)
  write(*,'(A,I0)') 'PUB_P2E18_STABLE_COUNT=',stable_count
  write(*,'(A,I0)') 'PUB_P2E18_UNRESOLVED_COUNT=',unresolved_count
  write(*,'(A)') 'PUB_P2E18_STABILITY_COMPARISON=8_VS_16_AND_16_VS_32'
  write(*,'(A)') 'PUB_P2E18_HEAD_THETA_STABILITY_FACTOR=0.10'
  write(*,'(A)') 'PUB_P2E18_STORAGE_USES_P2E14_RESOLUTION_FLOOR=TRUE'
  write(*,'(A)') 'PUB_P2E18_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E18_TIMING_EXECUTED=FALSE'

  if (stable_count==ncases) then
    write(*,'(A)') 'PUB_P2E18_SCIENTIFIC_OUTCOME=QUALIFIED_REF_HIGH_36_OF_36'
  else
    write(*,'(A)') 'PUB_P2E18_SCIENTIFIC_OUTCOME=BLOCKED_REF_HIGH_UNRESOLVED_CASES'
  end if
  write(*,'(A)') 'PUB_P2E18_REF_HIGH_CONSTRUCTION_GATE=PASS'

contains

  subroutine run_case(case_id,ise,material_id,se,forcing_id,top_factor,bottom_factor,stable,failure_stage)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor
    logical,intent(out) :: stable
    character(len=*),intent(out) :: failure_stage

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),initial_heads(n),initial_theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: final_h(n,nlevels),final_theta(n,nlevels),storage(nlevels),max_mass(nlevels)
    logical :: level_valid(nlevels),found
    character(len=40) :: level_stage
    real(real64) :: h0,k0,top_flux,bottom_flux
    real(real64) :: d1_h_inf,d1_h_rms,d1_theta_inf,d1_theta_rms,d1_storage
    real(real64) :: d2_h_inf,d2_h_rms,d2_theta_inf,d2_theta_rms,d2_storage
    logical :: pass1_h_inf,pass1_h_rms,pass1_theta_inf,pass1_theta_rms,pass1_storage
    logical :: pass2_h_inf,pass2_h_rms,pass2_theta_inf,pass2_theta_rms,pass2_storage
    integer :: il

    stable=.false.
    failure_stage='INITIALIZATION'
    level_valid=.false.
    final_h=0.0_real64; final_theta=0.0_real64
    storage=0.0_real64; max_mass=0.0_real64

    call rossfast_d3r_material_from_id(material_id,material,found)
    if (.not.found) then
      failure_stage='MATERIAL_LOOKUP'
      call report_unresolved(case_id,material_id,se,forcing_id,failure_stage)
      return
    end if

    h0=head_from_effective_saturation(se,material)
    if (.not.ieee_is_finite(h0) .or. h0<=ROSSFAST_D3R_H_MIN_CM .or. h0>=ROSSFAST_D3R_H_MAX_CM) then
      failure_stage='INITIAL_HEAD_DOMAIN'
      call report_unresolved(case_id,material_id,se,forcing_id,failure_stage)
      return
    end if

    call initialize_parameter_contract(parameters,cofgen,material,case_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
    initial_heads=h0
    call constitutive%evaluate(initial_heads,initial_theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(initial_theta)) .or. any(.not.ieee_is_finite(conductivity)) .or. &
        any(conductivity<=0.0_real64)) then
      failure_stage='INITIAL_CONSTITUTIVE'
      call report_unresolved(case_id,material_id,se,forcing_id,failure_stage)
      return
    end if
    if (any(initial_theta<=material%theta_r) .or. any(initial_theta>=material%theta_s)) then
      failure_stage='INITIAL_THETA_DOMAIN'
      call report_unresolved(case_id,material_id,se,forcing_id,failure_stage)
      return
    end if

    k0=conductivity(1)
    top_flux=top_factor*k0
    bottom_flux=bottom_factor*k0
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    do il=1,nlevels
      call run_refinement_level(nsub_levels(il),parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
           material,initial_heads,initial_theta,top_flux,bottom_flux,level_valid(il),level_stage, &
           final_h(:,il),final_theta(:,il),storage(il),max_mass(il))
      write(*,'(*(g0))') 'PUB_P2E18_LEVEL|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
           '|NSUB=',nsub_levels(il),'|DT=',horizon_day/real(nsub_levels(il),real64), &
           '|VALID=',level_valid(il),'|STAGE=',trim(level_stage),'|MAX_MASS_CM=',max_mass(il)
    end do

    if (any(.not.level_valid)) then
      failure_stage='REFINEMENT_ROUTE_INVALID'
      call report_unresolved(case_id,material_id,se,forcing_id,failure_stage)
      return
    end if

    call endpoint_delta(final_h(:,4),final_theta(:,4),storage(4),final_h(:,5),final_theta(:,5),storage(5), &
         d1_h_inf,d1_h_rms,d1_theta_inf,d1_theta_rms,d1_storage)
    call endpoint_delta(final_h(:,5),final_theta(:,5),storage(5),final_h(:,6),final_theta(:,6),storage(6), &
         d2_h_inf,d2_h_rms,d2_theta_inf,d2_theta_rms,d2_storage)

    if (.not.all_finite_delta(d1_h_inf,d1_h_rms,d1_theta_inf,d1_theta_rms,d1_storage) .or. &
        .not.all_finite_delta(d2_h_inf,d2_h_rms,d2_theta_inf,d2_theta_rms,d2_storage)) then
      failure_stage='STABILITY_METRIC_NONFINITE'
      call report_unresolved(case_id,material_id,se,forcing_id,failure_stage)
      return
    end if

    pass1_h_inf=d1_h_inf<=stability_factor*p2e14_h_inf(ise)
    pass1_h_rms=d1_h_rms<=stability_factor*p2e14_h_rms(ise)
    pass1_theta_inf=d1_theta_inf<=stability_factor*p2e14_theta_inf(ise)
    pass1_theta_rms=d1_theta_rms<=stability_factor*p2e14_theta_rms(ise)
    pass1_storage=d1_storage<=p2e14_storage(ise)

    pass2_h_inf=d2_h_inf<=stability_factor*p2e14_h_inf(ise)
    pass2_h_rms=d2_h_rms<=stability_factor*p2e14_h_rms(ise)
    pass2_theta_inf=d2_theta_inf<=stability_factor*p2e14_theta_inf(ise)
    pass2_theta_rms=d2_theta_rms<=stability_factor*p2e14_theta_rms(ise)
    pass2_storage=d2_storage<=p2e14_storage(ise)

    stable=pass1_h_inf .and. pass1_h_rms .and. pass1_theta_inf .and. pass1_theta_rms .and. pass1_storage .and. &
           pass2_h_inf .and. pass2_h_rms .and. pass2_theta_inf .and. pass2_theta_rms .and. pass2_storage
    if (stable) then
      failure_stage='NONE'
    else
      failure_stage='REF_HIGH_STABILITY_FAIL'
    end if

    call report_delta(case_id,material_id,se,forcing_id,'8_VS_16',d1_h_inf,d1_h_rms,d1_theta_inf,d1_theta_rms,d1_storage, &
         pass1_h_inf,pass1_h_rms,pass1_theta_inf,pass1_theta_rms,pass1_storage,ise)
    call report_delta(case_id,material_id,se,forcing_id,'16_VS_32',d2_h_inf,d2_h_rms,d2_theta_inf,d2_theta_rms,d2_storage, &
         pass2_h_inf,pass2_h_rms,pass2_theta_inf,pass2_theta_rms,pass2_storage,ise)
    write(*,'(*(g0))') 'PUB_P2E18_STABILITY|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|STABLE=',stable,'|STAGE=',trim(failure_stage)
  end subroutine run_case

  subroutine endpoint_delta(h_a,theta_a,storage_a,h_b,theta_b,storage_b,d_h_inf,d_h_rms,d_theta_inf,d_theta_rms,d_storage)
    real(real64),intent(in) :: h_a(n),theta_a(n),storage_a,h_b(n),theta_b(n),storage_b
    real(real64),intent(out) :: d_h_inf,d_h_rms,d_theta_inf,d_theta_rms,d_storage
    d_h_inf=maxval(abs(h_b-h_a))
    d_h_rms=sqrt(sum((h_b-h_a)**2)/real(n,real64))
    d_theta_inf=maxval(abs(theta_b-theta_a))
    d_theta_rms=sqrt(sum((theta_b-theta_a)**2)/real(n,real64))
    d_storage=abs(storage_b-storage_a)
  end subroutine endpoint_delta

  pure logical function all_finite_delta(d_h_inf,d_h_rms,d_theta_inf,d_theta_rms,d_storage) result(ok)
    real(real64),intent(in) :: d_h_inf,d_h_rms,d_theta_inf,d_theta_rms,d_storage
    ok=ieee_is_finite(d_h_inf) .and. ieee_is_finite(d_h_rms) .and. ieee_is_finite(d_theta_inf) .and. &
       ieee_is_finite(d_theta_rms) .and. ieee_is_finite(d_storage)
  end function all_finite_delta

  subroutine report_delta(case_id,material_id,se,forcing_id,pair_label,d_h_inf,d_h_rms,d_theta_inf,d_theta_rms,d_storage, &
       pass_h_inf,pass_h_rms,pass_theta_inf,pass_theta_rms,pass_storage,ise)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,forcing_id,pair_label
    real(real64),intent(in) :: se,d_h_inf,d_h_rms,d_theta_inf,d_theta_rms,d_storage
    logical,intent(in) :: pass_h_inf,pass_h_rms,pass_theta_inf,pass_theta_rms,pass_storage
    write(*,'(*(g0))') 'PUB_P2E18_DELTA|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|PAIR=',trim(pair_label),'|D_H_INF=',d_h_inf,'|T_H_INF=',stability_factor*p2e14_h_inf(ise), &
         '|D_H_RMS=',d_h_rms,'|T_H_RMS=',stability_factor*p2e14_h_rms(ise), &
         '|D_THETA_INF=',d_theta_inf,'|T_THETA_INF=',stability_factor*p2e14_theta_inf(ise), &
         '|D_THETA_RMS=',d_theta_rms,'|T_THETA_RMS=',stability_factor*p2e14_theta_rms(ise), &
         '|D_STORAGE=',d_storage,'|T_STORAGE=',p2e14_storage(ise), &
         '|PASS_H_INF=',pass_h_inf,'|PASS_H_RMS=',pass_h_rms,'|PASS_THETA_INF=',pass_theta_inf, &
         '|PASS_THETA_RMS=',pass_theta_rms,'|PASS_STORAGE=',pass_storage
  end subroutine report_delta

  subroutine run_refinement_level(nsub,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
       material,initial_heads,initial_theta,top_flux,bottom_flux,valid,stage,final_heads,final_theta,final_storage,max_mass)
    integer,intent(in) :: nsub
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    character(len=*),intent(out) :: stage
    real(real64),intent(out) :: final_heads(n),final_theta(n),final_storage,max_mass

    type(soil_water_solve_result_t) :: result
    real(real64) :: current_heads(n),current_theta(n),ponding,dt
    logical :: step_valid
    integer :: isub

    valid=.false.; stage='LEVEL_INITIALIZATION'
    final_heads=0.0_real64; final_theta=0.0_real64; final_storage=0.0_real64; max_mass=0.0_real64
    current_heads=initial_heads
    current_theta=initial_theta
    ponding=0.0_real64
    dt=horizon_day/real(nsub,real64)

    do isub=1,nsub
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call run_reference_step(parameters,constitutive,source_sink,top_boundary,material,current_heads,current_theta, &
           ponding,top_flux,bottom_flux,dt,result,step_valid)
      if (.not.step_valid) then
        write(stage,'(A,I0)') 'SUBSTEP_REFERENCE_GATE_',isub
        return
      end if
      max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
      current_heads=result%candidate_state%pressure_head
      current_theta=result%candidate_state%water_content
      ponding=result%candidate_state%ponding_depth
    end do

    final_heads=current_heads
    final_theta=current_theta
    final_storage=sum(parameters%dz*current_theta)+ponding
    valid=.true.; stage='NONE'
  end subroutine run_refinement_level

  subroutine run_reference_step(parameters,constitutive,source_sink,top_boundary,material,heads,theta,ponding, &
       top_flux,bottom_flux,dt,result,valid)
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_provider_t),target,intent(in) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: heads(n),theta(n),ponding,top_flux,bottom_flux,dt
    type(soil_water_solve_result_t),intent(out) :: result
    logical,intent(out) :: valid

    type(soil_water_solve_request_t) :: request
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace

    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta,heads,ponding, &
         top_flux,bottom_flux,dt)
    call solver%solve(request,workspace,result)
    valid=reference_result_valid(result,request,material)
  end subroutine run_reference_step

  logical function reference_result_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>hard_mass_tol_cm) return
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
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_result_valid

  subroutine report_unresolved(case_id,material_id,se,forcing_id,stage)
    integer,intent(in) :: case_id
    character(len=*),intent(in) :: material_id,forcing_id,stage
    real(real64),intent(in) :: se
    write(*,'(*(g0))') 'PUB_P2E18_STABILITY|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|STABLE=F|STAGE=',trim(stage)
  end subroutine report_unresolved

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
    parameter_set%parameter_set_id=922000+case_id
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
       qtop,qbot,dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),ponding,qtop,qbot,dt

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
    req%numerical%compartment_balance_tolerance=reference_balance_rate_tol
    req%numerical%total_balance_tolerance=reference_balance_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

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
      write(*,'(A,1X,A)') 'PUB_P2E18_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e18_ref_high_construction
