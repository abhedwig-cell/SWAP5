program test_pub_p2e18d3_reference_total_balance_floor
  use, intrinsic :: iso_fortran_env, only: real64, real128
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
  integer, parameter :: nmat=2,nse=2,nforcing=1,nlevels=6,ncases=nmat*nse*nforcing
  integer, parameter :: nsub_levels(nlevels)=[1,2,4,8,16,32]
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: baseline_rate_tol=1.0e-12_real64
  real(real64), parameter :: integrated_balance_scale=baseline_rate_tol*horizon_day
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: 'B01','O18']
  character(len=7), parameter :: forcing_ids(nforcing)=[character(len=7) :: 'DRYING ']
  real(real64), parameter :: se_levels(nse)=[0.65_real64,0.96_real64]
  real(real64), parameter :: qtop_factor(nforcing)=[-0.005_real64]
  real(real64), parameter :: qbot_factor(nforcing)=[-0.019_real64]

  integer :: valid_by_level(nlevels),invalid_by_level(nlevels)
  integer :: imat,ise,iforce,il,case_id
  integer :: retry_balance_only,retry_head_only,retry_both,retry_other
  integer :: total_floor_states,total_floor_ge_tol,total_residual_le_floor,total_recon_supported,storage_floor_dominant
  logical :: valid
  character(len=48) :: stage,retry_class

  valid_by_level=0
  invalid_by_level=0
  retry_balance_only=0; retry_head_only=0; retry_both=0; retry_other=0
  total_floor_states=0; total_floor_ge_tol=0; total_residual_le_floor=0
  total_recon_supported=0; storage_floor_dominant=0
  case_id=0

  do il=1,nlevels
    write(*,'(*(g0))') 'PUB_P2E18D3_POLICY|NSUB=',nsub_levels(il), &
         '|DT=',horizon_day/real(nsub_levels(il),real64), &
         '|RATE_TOL=',integrated_balance_scale/(horizon_day/real(nsub_levels(il),real64)), &
         '|INTEGRATED_SCALE=',integrated_balance_scale
  end do

  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        case_id=case_id+1
        do il=1,nlevels
          call run_level(case_id,nsub_levels(il),material_ids(imat),se_levels(ise),forcing_ids(iforce), &
               qtop_factor(iforce),qbot_factor(iforce),valid,stage,retry_class)
          if (valid) then
            valid_by_level(il)=valid_by_level(il)+1
          else
            invalid_by_level(il)=invalid_by_level(il)+1
            select case(trim(retry_class))
            case('BALANCE_ONLY'); retry_balance_only=retry_balance_only+1
            case('HEAD_ONLY'); retry_head_only=retry_head_only+1
            case('BOTH'); retry_both=retry_both+1
            case default; retry_other=retry_other+1
            end select
          end if
        end do
      end do
    end do
  end do

  call require(case_id==ncases,'exact 4 mechanism-diagnostic cases attempted')
  do il=1,nlevels
    call require(valid_by_level(il)+invalid_by_level(il)==ncases,'every level classified')
    write(*,'(*(g0))') 'PUB_P2E18D3_LEVEL_SUMMARY|NSUB=',nsub_levels(il), &
         '|VALID=',valid_by_level(il),'|INVALID=',invalid_by_level(il)
  end do

  write(*,'(A,I0)') 'PUB_P2E18D3_CASE_COUNT=',ncases
  write(*,'(A,I0)') 'PUB_P2E18D3_LEVEL_RECORD_COUNT=',ncases*nlevels
  write(*,'(A,I0)') 'PUB_P2E18D3_RETRY_BALANCE_ONLY_COUNT=',retry_balance_only
  write(*,'(A,I0)') 'PUB_P2E18D3_RETRY_HEAD_ONLY_COUNT=',retry_head_only
  write(*,'(A,I0)') 'PUB_P2E18D3_RETRY_BOTH_COUNT=',retry_both
  write(*,'(A,I0)') 'PUB_P2E18D3_RETRY_OTHER_COUNT=',retry_other
  write(*,'(A,I0)') 'PUB_P2E18D3_TOTAL_FLOOR_STATE_COUNT=',total_floor_states
  write(*,'(A,I0)') 'PUB_P2E18D3_TOTAL_FLOOR_GE_TOL_COUNT=',total_floor_ge_tol
  write(*,'(A,I0)') 'PUB_P2E18D3_TOTAL_RESIDUAL_LE_FLOOR_COUNT=',total_residual_le_floor
  write(*,'(A,I0)') 'PUB_P2E18D3_TOTAL_RECON_SUPPORTED_COUNT=',total_recon_supported
  write(*,'(A,I0)') 'PUB_P2E18D3_STORAGE_FLOOR_DOMINANT_COUNT=',storage_floor_dominant
  call require(total_floor_states==retry_other,'every total-only retry diagnosed')
  call require(total_recon_supported==total_floor_states,'every total-floor reconstruction supported')
  write(*,'(A)') 'PUB_P2E18D3_POLICY=INVARIANT_INTEGRATED_BALANCE_SCALE_UNCHANGED_FROM_D1'
  write(*,'(A)') 'PUB_P2E18D3_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E18D3_TIMING_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E18D3_REF_HIGH_STABILITY_QUALIFIED=FALSE'
  write(*,'(A)') 'PUB_P2E18D3_DIAGNOSTIC_OUTCOME=TOTAL_BALANCE_FLOOR_CHARACTERIZED'
  write(*,'(A)') 'PUB_P2E18D3_GATE=PASS'

contains

  subroutine run_level(case_id,nsub,material_id,se,forcing_id,top_factor,bottom_factor,valid,stage,retry_class)
    integer,intent(in) :: case_id,nsub
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor
    logical,intent(out) :: valid
    character(len=*),intent(out) :: stage,retry_class

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: h0,k0,top_flux,bottom_flux,dt,ponding,rate_tol
    logical :: found,step_valid
    integer :: isub,nbal,nhead
    real(real64) :: max_abs_residual,abs_sum_residual

    valid=.false.; stage='INITIALIZATION'; retry_class='NONE'
    call rossfast_d3r_material_from_id(material_id,material,found)
    if (.not.found) then
      stage='MATERIAL_LOOKUP'
      call report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,0,0.0_real64)
      return
    end if

    h0=head_from_effective_saturation(se,material)
    if (.not.ieee_is_finite(h0) .or. h0<=ROSSFAST_D3R_H_MIN_CM .or. h0>=ROSSFAST_D3R_H_MAX_CM) then
      stage='INITIAL_HEAD_DOMAIN'
      call report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,0,0.0_real64)
      return
    end if

    call initialize_parameter_contract(parameters,cofgen,material,case_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    dt=horizon_day/real(nsub,real64)
    rate_tol=integrated_balance_scale/dt
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    heads=h0
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta)) .or. any(.not.ieee_is_finite(conductivity)) .or. any(conductivity<=0.0_real64)) then
      stage='INITIAL_CONSTITUTIVE'
      call report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,0,rate_tol)
      return
    end if
    if (any(theta<=material%theta_r) .or. any(theta>=material%theta_s)) then
      stage='INITIAL_THETA_DOMAIN'
      call report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,0,rate_tol)
      return
    end if

    k0=conductivity(1)
    top_flux=top_factor*k0
    bottom_flux=bottom_factor*k0
    ponding=0.0_real64
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    do isub=1,nsub
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta,heads,ponding, &
           top_flux,bottom_flux,dt,rate_tol)
      call solver%solve(request,workspace,result)

      step_valid=reference_result_valid(result,request,material)
      nbal=0; nhead=0; max_abs_residual=0.0_real64; abs_sum_residual=0.0_real64
      if (allocated(workspace%richards%nonconverged_balance)) nbal=count(workspace%richards%nonconverged_balance)
      if (allocated(workspace%richards%nonconverged_head)) nhead=count(workspace%richards%nonconverged_head)
      if (allocated(workspace%richards%residual)) then
        max_abs_residual=maxval(abs(workspace%richards%residual))
        abs_sum_residual=abs(sum(workspace%richards%residual))
      end if
      if (.not.step_valid .and. result%retry_advised) then
        if (nbal>0 .and. nhead==0) then
          retry_class='BALANCE_ONLY'
        else if (nbal==0 .and. nhead>0) then
          retry_class='HEAD_ONLY'
        else if (nbal>0 .and. nhead>0) then
          retry_class='BOTH'
        else
          retry_class='OTHER'
        end if
      else
        retry_class='NONE'
      end if
      write(*,'(*(g0))') 'PUB_P2E18D3_STEP|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
           '|F=',trim(forcing_id),'|NSUB=',nsub,'|ISUB=',isub,'|DT=',dt,'|RATE_TOL=',rate_tol, &
           '|STATUS=',result%status,'|ROUTE=',trim(result%diagnostics%route), &
           '|RETRY=',result%retry_advised,'|NIT=',result%diagnostics%nonlinear_iterations, &
           '|BACKTRACK=',result%diagnostics%backtracking_attempts, &
           '|INTERNAL_RETRIES=',result%diagnostics%internal_retries, &
           '|NBAL_FAIL=',nbal,'|NHEAD_FAIL=',nhead, &
           '|MAX_ABS_RESIDUAL=',max_abs_residual,'|ABS_SUM_RESIDUAL=',abs_sum_residual, &
           '|RETRY_CLASS=',trim(retry_class),'|VALID=',step_valid
      if (.not.step_valid) then
        if (result%retry_advised .and. trim(retry_class)=='OTHER' .and. nbal==0 .and. nhead==0) then
          call diagnose_total_floor(case_id,material_id,se,forcing_id,nsub,isub,request,workspace,rate_tol)
        end if
        write(stage,'(A,I0)') 'SUBSTEP_REFERENCE_GATE_',isub
        call report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,isub,rate_tol)
        return
      end if

      heads=result%candidate_state%pressure_head
      theta=result%candidate_state%water_content
      ponding=result%candidate_state%ponding_depth
    end do

    valid=.true.; stage='NONE'
    call report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,nsub,rate_tol)
  end subroutine run_level

  subroutine diagnose_total_floor(case_id,material_id,se,forcing_id,nsub,isub,request,workspace,rate_tol)
    integer,intent(in) :: case_id,nsub,isub
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,rate_tol
    type(soil_water_solve_request_t),intent(in) :: request
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    real(real64) :: component(4),workspace_total,native_sum,closure_abs
    real(real64) :: storage_quant_floor,hp_difference,order_spread,estimated_floor
    real(real64) :: tol_over_floor,residual_over_floor,dt_floor
    real(real128) :: hp_sum
    character(len=24) :: dominant

    call require(allocated(workspace%richards%provider_theta),'total-floor internal theta allocated')
    call require(allocated(workspace%richards%residual),'total-floor residual allocated')
    call require(size(workspace%richards%provider_theta)==n,'total-floor internal theta size')
    call require(size(workspace%richards%residual)==n,'total-floor residual size')
    call require(all(ieee_is_finite(workspace%richards%provider_theta)),'total-floor internal theta finite')
    call require(all(ieee_is_finite(workspace%richards%residual)),'total-floor residual finite')

    component=0.0_real64
    component(1)=sum((workspace%richards%provider_theta-request%base_state%water_content)*request%parameters%dz) / &
         request%step_duration
    component(2)=request%boundary%top_flux
    component(3)=-request%boundary%bottom_flux
    component(4)=sum(workspace%richards%sink-workspace%richards%source+workspace%richards%provider_root_sink)

    workspace_total=sum(workspace%richards%residual)
    native_sum=component(1)
    native_sum=native_sum+component(2)
    native_sum=native_sum+component(3)
    native_sum=native_sum+component(4)
    closure_abs=abs(workspace_total-native_sum)

    storage_quant_floor=0.5_real64*sum((spacing(workspace%richards%provider_theta)+ &
         spacing(request%base_state%water_content))*request%parameters%dz)/request%step_duration
    hp_sum=real(component(1),real128)+real(component(2),real128)+real(component(3),real128)+real(component(4),real128)
    hp_difference=real(abs(real(native_sum,real128)-hp_sum),real64)
    order_spread=summation_order_spread(component)
    estimated_floor=max(storage_quant_floor,hp_difference,order_spread)

    call require(ieee_is_finite(estimated_floor) .and. estimated_floor>0.0_real64,'positive finite total floor')
    call require(ieee_is_finite(closure_abs) .and. closure_abs>=0.0_real64,'finite total reconstruction closure')
    tol_over_floor=rate_tol/estimated_floor
    residual_over_floor=abs(workspace_total)/estimated_floor
    dt_floor=request%step_duration*estimated_floor

    if (estimated_floor==storage_quant_floor) then
      dominant='STORAGE_QUANTIZATION'
      storage_floor_dominant=storage_floor_dominant+1
    else if (estimated_floor==hp_difference) then
      dominant='HIGH_PRECISION_DIFF'
    else
      dominant='SUMMATION_ORDER'
    end if

    total_floor_states=total_floor_states+1
    if (estimated_floor>=rate_tol) total_floor_ge_tol=total_floor_ge_tol+1
    if (abs(workspace_total)<=estimated_floor) total_residual_le_floor=total_residual_le_floor+1
    if (closure_abs<=estimated_floor) total_recon_supported=total_recon_supported+1

    write(*,'(*(g0))') 'PUB_P2E18D3_TOTAL_FLOOR|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|NSUB=',nsub,'|ISUB=',isub,'|DT=',request%step_duration, &
         '|RATE_TOL=',rate_tol,'|WORKSPACE_TOTAL=',workspace_total,'|ABS_TOTAL=',abs(workspace_total), &
         '|STORAGE_TOTAL=',component(1),'|TOP=',component(2),'|BOTTOM=',component(3),'|SSR=',component(4), &
         '|RECON=',native_sum,'|CLOSURE=',closure_abs,'|STORAGE_QFLOOR=',storage_quant_floor, &
         '|HP_DIFF=',hp_difference,'|ORDER_SPREAD=',order_spread,'|FLOOR=',estimated_floor, &
         '|DT_FLOOR=',dt_floor,'|TOL_OVER_FLOOR=',tol_over_floor,'|R_OVER_FLOOR=',residual_over_floor, &
         '|DOMINANT=',trim(dominant),'|FLOOR_GE_TOL=',estimated_floor>=rate_tol, &
         '|RESIDUAL_LE_FLOOR=',abs(workspace_total)<=estimated_floor,'|RECON_SUPPORTED=',closure_abs<=estimated_floor
  end subroutine diagnose_total_floor

  real(real64) function summation_order_spread(component) result(spread)
    real(real64),intent(in) :: component(4)
    integer :: i,j,k,l
    real(real64) :: s,smin,smax
    smin=huge(1.0_real64); smax=-huge(1.0_real64)
    do i=1,4
      do j=1,4
        if (j==i) cycle
        do k=1,4
          if (k==i .or. k==j) cycle
          do l=1,4
            if (l==i .or. l==j .or. l==k) cycle
            s=component(i); s=s+component(j); s=s+component(k); s=s+component(l)
            smin=min(smin,s); smax=max(smax,s)
          end do
        end do
      end do
    end do
    spread=smax-smin
  end function summation_order_spread

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
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_result_valid

  subroutine report_level(case_id,nsub,material_id,se,forcing_id,valid,stage,completed_substeps,rate_tol)
    integer,intent(in) :: case_id,nsub,completed_substeps
    character(len=*),intent(in) :: material_id,forcing_id,stage
    real(real64),intent(in) :: se,rate_tol
    logical,intent(in) :: valid
    write(*,'(*(g0))') 'PUB_P2E18D3_LEVEL|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|NSUB=',nsub,'|DT=',horizon_day/real(nsub,real64), &
         '|RATE_TOL=',rate_tol,'|VALID=',valid,'|COMPLETED=',completed_substeps,'|STAGE=',trim(stage)
  end subroutine report_level

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
    parameter_set%parameter_set_id=922100+case_id
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
       qtop,qbot,dt,rate_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),ponding,qtop,qbot,dt,rate_tol

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
    req%numerical%compartment_balance_tolerance=rate_tol
    req%numerical%total_balance_tolerance=rate_tol
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
      write(*,'(A,1X,A)') 'PUB_P2E18D3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e18d3_reference_total_balance_floor
