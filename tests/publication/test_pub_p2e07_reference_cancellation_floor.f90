program test_pub_p2e07_reference_cancellation_floor
  use, intrinsic :: iso_fortran_env, only: real64, real128
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
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
  integer, parameter :: nclass = 7, ndt = 3
  integer, parameter :: C_ACCEPTED=1, C_TOTAL_ONLY=2, C_LOCAL_BAL=3, C_HEAD=4, C_MIXED=5, C_RETRY_OTHER=6, C_FAILED=7
  integer, parameter :: S_NONE=0, S_COARSE=1, S_HALF1=2, S_HALF2=3
  real(real64), parameter :: reference_balance_rate_tol = 1.0e-12_real64
  character(len=18), parameter :: class_name(nclass) = [character(len=18) :: &
       'ACCEPTED', 'RETRY_TOTAL_ONLY', 'RETRY_LOCAL_BAL', 'RETRY_HEAD', 'RETRY_MIXED', 'RETRY_OTHER', 'FAILED_OR_INVALID']
  character(len=3), parameter :: material_ids(6) = [character(len=3) :: 'B01','B12','O01','O05','O14','O18']
  character(len=7), parameter :: forcing_ids(3) = [character(len=7) :: 'DRYING ','NOMINAL','WETTING']
  real(real64), parameter :: se_levels(3) = [0.65_real64,0.85_real64,0.98_real64]
  real(real64), parameter :: dt_levels(ndt) = [0.0016_real64,0.0004_real64,0.0001_real64]
  real(real64), parameter :: qtop_factor(3) = [-0.005_real64,0.010_real64,0.025_real64]
  real(real64), parameter :: qbot_factor(3) = [-0.019_real64,-0.004_real64,0.011_real64]

  integer :: counts(nclass), counts_by_dt(nclass,ndt), local_stage_counts(3)
  integer :: floor_ge_tol_by_dt(ndt), reconstruction_supported_by_dt(ndt)
  integer :: internal_storage_nonzero_by_dt(ndt), public_storage_zero_by_dt(ndt)
  integer :: total_cases, imat, ise, iforce, idt, class_id, failed_stage, case_no
  real(real64) :: floor_sum(ndt), margin_sum(ndt), residual_floor_ratio_sum(ndt), cancellation_sum(ndt)
  real(real64) :: floor_min(ndt), floor_max(ndt), margin_min(ndt), margin_max(ndt)
  real(real64) :: max_closure_abs, estimated_floor, validity_margin, residual_floor_ratio
  real(real64) :: cancellation_ratio, closure_abs, internal_storage_rate, public_storage_rate
  logical :: reconstruction_supported

  counts=0; counts_by_dt=0; local_stage_counts=0
  floor_ge_tol_by_dt=0; reconstruction_supported_by_dt=0
  internal_storage_nonzero_by_dt=0; public_storage_zero_by_dt=0
  floor_sum=0.0_real64; margin_sum=0.0_real64; residual_floor_ratio_sum=0.0_real64; cancellation_sum=0.0_real64
  floor_min=huge(1.0_real64); floor_max=0.0_real64
  margin_min=huge(1.0_real64); margin_max=0.0_real64
  max_closure_abs=0.0_real64; total_cases=0; case_no=0

  do imat=1,size(material_ids)
    do ise=1,size(se_levels)
      do iforce=1,size(forcing_ids)
        do idt=1,ndt
          total_cases=total_cases+1; case_no=case_no+1
          call diagnose_case(case_no, material_ids(imat),se_levels(ise),forcing_ids(iforce), &
               qtop_factor(iforce),qbot_factor(iforce),dt_levels(idt),class_id,failed_stage, &
               estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs, &
               internal_storage_rate,public_storage_rate,reconstruction_supported)
          counts(class_id)=counts(class_id)+1
          counts_by_dt(class_id,idt)=counts_by_dt(class_id,idt)+1
          if (class_id==C_LOCAL_BAL) then
            if (failed_stage>=S_COARSE .and. failed_stage<=S_HALF2) local_stage_counts(failed_stage)=local_stage_counts(failed_stage)+1
            call require(ieee_is_finite(estimated_floor) .and. estimated_floor>0.0_real64,'positive finite estimated floor')
            call require(ieee_is_finite(validity_margin) .and. validity_margin>=0.0_real64,'finite validity margin')
            call require(ieee_is_finite(residual_floor_ratio) .and. residual_floor_ratio>=0.0_real64,'finite residual/floor ratio')
            call require(ieee_is_finite(cancellation_ratio) .and. cancellation_ratio>=0.0_real64,'finite nonnegative cancellation ratio')
            call require(ieee_is_finite(closure_abs) .and. closure_abs>=0.0_real64,'finite reconstruction closure')
            floor_sum(idt)=floor_sum(idt)+estimated_floor
            floor_min(idt)=min(floor_min(idt),estimated_floor); floor_max(idt)=max(floor_max(idt),estimated_floor)
            margin_sum(idt)=margin_sum(idt)+validity_margin
            margin_min(idt)=min(margin_min(idt),validity_margin); margin_max(idt)=max(margin_max(idt),validity_margin)
            residual_floor_ratio_sum(idt)=residual_floor_ratio_sum(idt)+residual_floor_ratio
            cancellation_sum(idt)=cancellation_sum(idt)+cancellation_ratio
            max_closure_abs=max(max_closure_abs,closure_abs)
            if (reconstruction_supported) then
              reconstruction_supported_by_dt(idt)=reconstruction_supported_by_dt(idt)+1
              if (estimated_floor>=reference_balance_rate_tol) floor_ge_tol_by_dt(idt)=floor_ge_tol_by_dt(idt)+1
            end if
            if (internal_storage_rate/=0.0_real64) internal_storage_nonzero_by_dt(idt)=internal_storage_nonzero_by_dt(idt)+1
            if (public_storage_rate==0.0_real64) public_storage_zero_by_dt(idt)=public_storage_zero_by_dt(idt)+1
          end if
        end do
      end do
    end do
  end do

  call require(total_cases==162,'exact P2E03 domain replayed')
  call require(counts(C_ACCEPTED)==47,'P2E06 accepted count reproduced')
  call require(counts(C_TOTAL_ONLY)==12,'P2E06 total-only count reproduced')
  call require(counts(C_LOCAL_BAL)==103,'P2E06 local-balance count reproduced')
  call require(sum(counts(C_HEAD:C_FAILED))==0,'P2E06 no-other-failure classes reproduced')
  call require(all(counts_by_dt(C_LOCAL_BAL,:)==[3,46,54]),'P2E06 local-balance dt pattern reproduced')

  write(*,'(A,I0)') 'PUB_P2E07_CASE_COUNT=',total_cases
  write(*,'(A,I0)') 'PUB_P2E07_ACCEPTED_COUNT=',counts(C_ACCEPTED)
  write(*,'(A,I0)') 'PUB_P2E07_TOTAL_ONLY_COUNT=',counts(C_TOTAL_ONLY)
  write(*,'(A,I0)') 'PUB_P2E07_LOCAL_BAL_COUNT=',counts(C_LOCAL_BAL)
  write(*,'(A,I0)') 'PUB_P2E07_LOCAL_STAGE_COARSE=',local_stage_counts(S_COARSE)
  write(*,'(A,I0)') 'PUB_P2E07_LOCAL_STAGE_HALF1=',local_stage_counts(S_HALF1)
  write(*,'(A,I0)') 'PUB_P2E07_LOCAL_STAGE_HALF2=',local_stage_counts(S_HALF2)

  do idt=1,ndt
    call require(counts_by_dt(C_LOCAL_BAL,idt)>0,'LOCAL_BAL summary denominator positive')
    write(*,'(*(g0))') 'PUB_P2E07_DT_SUMMARY|DT=',dt_levels(idt), &
         '|LOCAL=',counts_by_dt(C_LOCAL_BAL,idt), &
         '|RECON_SUPPORTED=',reconstruction_supported_by_dt(idt), &
         '|FLOOR_GE_TOL=',floor_ge_tol_by_dt(idt), &
         '|FLOOR_MIN=',floor_min(idt), &
         '|FLOOR_MEAN=',floor_sum(idt)/real(counts_by_dt(C_LOCAL_BAL,idt),real64), &
         '|FLOOR_MAX=',floor_max(idt), &
         '|MARGIN_MIN=',margin_min(idt), &
         '|MARGIN_MEAN=',margin_sum(idt)/real(counts_by_dt(C_LOCAL_BAL,idt),real64), &
         '|MARGIN_MAX=',margin_max(idt), &
         '|RES_OVER_FLOOR_MEAN=',residual_floor_ratio_sum(idt)/real(counts_by_dt(C_LOCAL_BAL,idt),real64), &
         '|CANCEL_MEAN=',cancellation_sum(idt)/real(counts_by_dt(C_LOCAL_BAL,idt),real64), &
         '|INTERNAL_STORAGE_NONZERO=',internal_storage_nonzero_by_dt(idt), &
         '|PUBLIC_STORAGE_ZERO=',public_storage_zero_by_dt(idt)
  end do

  write(*,'(*(g0))') 'PUB_P2E07_MAX_RECONSTRUCTION_CLOSURE=',max_closure_abs
  write(*,'(A,I0)') 'PUB_P2E07_RECONSTRUCTION_SUPPORTED_TOTAL=',sum(reconstruction_supported_by_dt)
  write(*,'(A,I0)') 'PUB_P2E07_FLOOR_GE_TOL_TOTAL=',sum(floor_ge_tol_by_dt)
  write(*,'(A,I0)') 'PUB_P2E07_INTERNAL_STORAGE_NONZERO_TOTAL=',sum(internal_storage_nonzero_by_dt)
  write(*,'(A,I0)') 'PUB_P2E07_PUBLIC_STORAGE_ZERO_TOTAL=',sum(public_storage_zero_by_dt)
  write(*,'(A)') 'PUB_P2E07_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E07_PRODUCTION_OR_REFERENCE_SOURCE_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E07_TOLERANCE_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E07_REFERENCE_CANCELLATION_FLOOR=PASS'

contains

  subroutine diagnose_case(case_id,material_id,se,forcing_id,top_factor,bottom_factor,coarse_dt,class_id,failed_stage, &
       estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs, &
       internal_storage_rate,public_storage_rate,reconstruction_supported)
    integer,intent(in) :: case_id
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor,coarse_dt
    integer,intent(out) :: class_id,failed_stage
    real(real64),intent(out) :: estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs
    real(real64),intent(out) :: internal_storage_rate,public_storage_rate
    logical,intent(out) :: reconstruction_supported
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
    estimated_floor=0.0_real64; validity_margin=0.0_real64; residual_floor_ratio=0.0_real64
    cancellation_ratio=1.0_real64; closure_abs=0.0_real64
    internal_storage_rate=0.0_real64; public_storage_rate=0.0_real64; reconstruction_supported=.false.
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
    if (class_id/=C_ACCEPTED) then
      failed_stage=S_COARSE
      if (class_id==C_LOCAL_BAL) call diagnose_local_failure(case_id,material_id,se,forcing_id,coarse_dt,failed_stage, &
           request,result,workspace,k0,estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs, &
           internal_storage_rate,public_storage_rate,reconstruction_supported)
      return
    end if

    half_dt=0.5_real64*coarse_dt
    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0, &
         top_factor*k0,bottom_factor*k0,half_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(request,workspace,result)
    call classify_result(result,workspace,material,class_id)
    if (class_id/=C_ACCEPTED) then
      failed_stage=S_HALF1
      if (class_id==C_LOCAL_BAL) call diagnose_local_failure(case_id,material_id,se,forcing_id,coarse_dt,failed_stage, &
           request,result,workspace,k0,estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs, &
           internal_storage_rate,public_storage_rate,reconstruction_supported)
      return
    end if

    request%base_state=result%candidate_state
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
    call solver%solve(request,workspace,result)
    call classify_result(result,workspace,material,class_id)
    if (class_id/=C_ACCEPTED) then
      failed_stage=S_HALF2
      if (class_id==C_LOCAL_BAL) call diagnose_local_failure(case_id,material_id,se,forcing_id,coarse_dt,failed_stage, &
           request,result,workspace,k0,estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs, &
           internal_storage_rate,public_storage_rate,reconstruction_supported)
      return
    end if
    failed_stage=S_NONE
  end subroutine diagnose_case

  subroutine diagnose_local_failure(case_id,material_id,se,forcing_id,coarse_dt,stage,request,result,workspace,k0, &
       estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs, &
       internal_storage_rate,public_storage_rate,reconstruction_supported)
    integer,intent(in) :: case_id,stage
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,coarse_dt,k0
    type(soil_water_solve_request_t),intent(in) :: request
    type(soil_water_solve_result_t),intent(in) :: result
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    real(real64),intent(out) :: estimated_floor,validity_margin,residual_floor_ratio,cancellation_ratio,closure_abs
    real(real64),intent(out) :: internal_storage_rate,public_storage_rate
    logical,intent(out) :: reconstruction_supported
    integer :: imax,flag_count
    real(real64) :: signed_residual,component(4),native_sum,l1_scale,storage_quant_floor
    real(real64) :: order_spread,hp_difference,theta_internal,theta_base
    real(real128) :: hp_sum

    flag_count=count(workspace%richards%nonconverged_balance)
    call require(flag_count>0,'LOCAL_BAL has at least one flagged node')
    imax=maxloc(abs(workspace%richards%residual),dim=1)
    signed_residual=workspace%richards%residual(imax)
    theta_internal=workspace%richards%provider_theta(imax)
    theta_base=request%base_state%water_content(imax)
    call require(ieee_is_finite(theta_internal) .and. ieee_is_finite(theta_base),'finite internal/base theta')

    internal_storage_rate=(theta_internal-theta_base)*request%parameters%dz(imax)/request%step_duration
    public_storage_rate=(result%candidate_state%water_content(imax)-theta_base)* &
         request%parameters%dz(imax)/request%step_duration

    component=0.0_real64
    component(1)=internal_storage_rate
    if (imax==1) then
      component(2)=k0*workspace%richards%head_gradient(2)
      component(3)=request%boundary%top_flux
    else if (imax==n) then
      component(2)=-k0*workspace%richards%head_gradient(n)
      component(3)=-request%boundary%bottom_flux
    else
      component(2)=-k0*workspace%richards%head_gradient(imax)
      component(3)= k0*workspace%richards%head_gradient(imax+1)
    end if
    component(4)=workspace%richards%sink(imax)-workspace%richards%source(imax)+workspace%richards%provider_root_sink(imax)

    call require(all(ieee_is_finite(component)),'finite residual components')
    native_sum=component(1)
    native_sum=native_sum+component(2)
    native_sum=native_sum+component(3)
    native_sum=native_sum+component(4)
    closure_abs=abs(signed_residual-native_sum)
    l1_scale=sum(abs(component))
    cancellation_ratio=l1_scale/max(abs(signed_residual),tiny(1.0_real64))

    storage_quant_floor=0.5_real64*(spacing(theta_internal)+spacing(theta_base))* &
         request%parameters%dz(imax)/request%step_duration
    hp_sum=real(component(1),real128)+real(component(2),real128)+real(component(3),real128)+real(component(4),real128)
    hp_difference=real(abs(real(native_sum,real128)-hp_sum),real64)
    order_spread=summation_order_spread(component)
    estimated_floor=max(storage_quant_floor,hp_difference,order_spread)
    validity_margin=reference_balance_rate_tol/estimated_floor
    residual_floor_ratio=abs(signed_residual)/estimated_floor
    reconstruction_supported=(closure_abs<=estimated_floor)

    write(*,'(*(g0))') 'PUB_P2E07_LOCAL|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|COARSE_DT=',coarse_dt,'|STAGE=',trim(stage_label(stage)),'|ACTUAL_DT=',request%step_duration, &
         '|FLAGS=',flag_count,'|IMAX=',imax,'|R_RATE=',abs(signed_residual), &
         '|STORAGE_INTERNAL=',internal_storage_rate,'|STORAGE_PUBLIC=',public_storage_rate, &
         '|FACE_A=',component(2),'|FACE_B=',component(3),'|SRC_SINK_ROOT=',component(4), &
         '|RECON=',native_sum,'|CLOSURE=',closure_abs,'|L1=',l1_scale,'|CANCEL=',cancellation_ratio, &
         '|STORAGE_QFLOOR=',storage_quant_floor,'|HP_DIFF=',hp_difference,'|ORDER_SPREAD=',order_spread, &
         '|FLOOR=',estimated_floor,'|DT_FLOOR=',request%step_duration*estimated_floor, &
         '|TOL_OVER_FLOOR=',validity_margin,'|R_OVER_FLOOR=',residual_floor_ratio, &
         '|RECON_SUPPORTED=',reconstruction_supported
  end subroutine diagnose_local_failure

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

  subroutine classify_result(result,workspace,material,class_id)
    type(soil_water_solve_result_t),intent(in) :: result
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    type(rossfast_d3r_material_t),intent(in) :: material
    integer,intent(out) :: class_id
    call classify_result_without_endpoint_bounds(result,workspace,class_id)
    if (class_id==C_ACCEPTED) then
      if (.not.endpoint_valid(result,material)) class_id=C_FAILED
    end if
  end subroutine classify_result

  subroutine classify_result_without_endpoint_bounds(result,workspace,class_id)
    type(soil_water_solve_result_t),intent(in) :: result
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    integer,intent(out) :: class_id
    integer :: bal,head
    real(real64) :: rsum,rmax

    class_id=C_FAILED
    if (result%status==SW_SOLVE_CONVERGED) then
      if (trim(result%diagnostics%route)/='legacy-reference-bound') return
      if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
      if (abs(result%native_balance_rate_residual_cm_per_day)>reference_balance_rate_tol) return
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
             rmax<=reference_balance_rate_tol .and. abs(rsum)>reference_balance_rate_tol) then
      class_id=C_TOTAL_ONLY
    else
      class_id=C_RETRY_OTHER
    end if
  end subroutine classify_result_without_endpoint_bounds

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
    parameter_set%parameter_set_id=920701; parameter_set%active_nodes=n
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
    req%numerical%compartment_balance_tolerance=reference_balance_rate_tol
    req%numerical%total_balance_tolerance=reference_balance_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider; req%evaluation%source_sink=>source_provider; req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then; write(*,'(A,1X,A)') 'PUB_P2E07_FAIL',trim(label); error stop 1; end if
  end subroutine require
end program test_pub_p2e07_reference_cancellation_floor
