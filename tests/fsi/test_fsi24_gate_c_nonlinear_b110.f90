program test_fsi24_gate_c_nonlinear_b110
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_linear_solver, only: reference_tridag
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: total_dt=0.25_real64, hard_mass_gate=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h0, jump, hbot, expected_eobs, e1_512
  real(real64) :: heads0(numnod), water0(numnod), conductivity0_nodes(numnod), capacity0(numnod), dkdh0(numnod)
  real(real64) :: conductivity0, static_residual(numnod), hdot_n(numnod), hdot_np1(numnod), eraw(numnod)
  real(real64) :: water_final(numnod), conductivity_final(numnod), capacity_final(numnod), dkdh_final(numnod)
  real(real64) :: mdiag(numnod), lower(numnod), main(numnod), upper(numnod), rhs(numnod), delta(numnod), gamma(numnod)
  real(real64) :: face_g(numnod+1), raw_m, d2_m, bm, binf, dinf, eobs, raw_ratio, binf_ratio, dinf_ratio, raw_to_binf
  real(real64) :: storage0, storage1, total_in, total_out, mass_residual, solver_mass, max_mass
  real(real64) :: min_m, max_m, symmetry_residual, reproduction_diff, provider_water_diff, explicit_bottom_distance
  logical :: finite_consistent
  integer :: ierr, i

  call read_inputs(h0,jump,expected_eobs,e1_512)
  hbot=h0+jump
  call configure_problem(h0,parameters,hydraulic_parameters,constitutive,source_sink,top_provider, &
       initial_state,drainage,subsurface,root_sink,cofgen,conductivity0)

  heads0=h0
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,total_dt)
  call constitutive%evaluate(heads0,water0,conductivity0_nodes,capacity0,dkdh0)
  call require(all(ieee_is_finite(capacity0)) .and. all(capacity0>0.0_real64),'bootstrap capacity finite positive')
  call require(all(ieee_is_finite(conductivity0_nodes)) .and. all(conductivity0_nodes>0.0_real64), &
       'bootstrap conductivity finite positive')
  do i=2,numnod
    call require(transfer(conductivity0_nodes(i),0_int64)==transfer(conductivity0_nodes(1),0_int64), &
         'uniform initial conductivity')
  end do
  call require(transfer(conductivity0,0_int64)==transfer(conductivity0_nodes(1),0_int64),'k0 mapping')

  static_residual=0.0_real64
  static_residual(numnod)=conductivity0*(h0-hbot)/(0.5_real64*parameters%dz(numnod))
  hdot_n=-static_residual/(capacity0*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)),'finite right-sided bootstrap derivative')

  request=soil_water_solve_request_t()
  request%parameters=>parameters
  request%base_state=initial_state
  request%step_duration=total_dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=5
  request%boundary%top_flux=-conductivity0
  request%boundary%top_head=h0
  request%boundary%bottom_flux=12345.678_real64
  request%boundary%bottom_head=hbot
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=8
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-6_real64
  request%numerical%compartment_balance_tolerance=hard_mass_gate
  request%numerical%total_balance_tolerance=hard_mass_gate
  request%numerical%head_abs_tolerance=1.0e-12_real64
  request%numerical%head_rel_tolerance=1.0e-12_real64
  request%numerical%ponding_tolerance=1.0e-12_real64
  request%evaluation%constitutive=>constitutive
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider

  storage0=sum(initial_state%water_content*parameters%dz)+initial_state%ponding_depth
  call solver%solve(request,workspace,result)
  call require(result%status==SW_SOLVE_CONVERGED,'N1 direct Richards solve converged')
  storage1=sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
  total_in=max(0.0_real64,-result%top_flux)*total_dt+max(0.0_real64,result%bottom_flux)*total_dt
  total_out=max(0.0_real64,result%top_flux)*total_dt+max(0.0_real64,-result%bottom_flux)*total_dt
  mass_residual=storage1-storage0-(total_in-total_out)
  solver_mass=abs(result%unrounded_mass_balance_residual)
  max_mass=max(abs(mass_residual),solver_mass)
  call require(max_mass<=hard_mass_gate,'hard N1 mass gate')

  hdot_np1=(result%candidate_state%pressure_head-h0)/total_dt
  eraw=0.5_real64*total_dt*(hdot_np1-hdot_n)
  eobs=maxval(abs(eraw))
  reproduction_diff=abs(eobs-expected_eobs)
  call require(reproduction_diff<=fp_bound(max(abs(eobs),abs(expected_eobs))),'persisted C2 EOBS reproduction')
  call require(e1_512>0.0_real64 .and. ieee_is_finite(e1_512),'positive finite persisted E1_512 comparator')

  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,total_dt)
  call constitutive%evaluate(result%candidate_state%pressure_head,water_final,conductivity_final,capacity_final,dkdh_final)
  provider_water_diff=maxval(abs(water_final-result%candidate_state%water_content))
  call require(provider_water_diff<=fp_bound(max(maxval(abs(water_final)),maxval(abs(result%candidate_state%water_content)))), &
       'accepted-state water provider consistency')
  call require(all(ieee_is_finite(capacity_final)) .and. all(capacity_final>0.0_real64), &
       'accepted-state capacity finite positive')
  mdiag=capacity_final*parameters%dz
  call require(all(ieee_is_finite(mdiag)) .and. all(mdiag>0.0_real64),'positive final-state M diagonal')
  min_m=minval(mdiag); max_m=maxval(mdiag)

  explicit_bottom_distance=0.5_real64*parameters%dz(numnod)
  call require(explicit_bottom_distance>0.0_real64,'positive explicit lower-face distance')
  call assemble_current_policy_final_jacobian(conductivity0,mdiag,explicit_bottom_distance,lower,main,upper,face_g)
  symmetry_residual=0.0_real64
  do i=2,numnod
    symmetry_residual=max(symmetry_residual,abs(lower(i)-upper(i-1)))
  end do
  call require(symmetry_residual<=fp_bound(maxval(abs(lower))),'symmetric paired Darcy offdiagonals')
  call require(all(ieee_is_finite(lower)) .and. all(ieee_is_finite(main)) .and. all(ieee_is_finite(upper)), &
       'finite reconstructed final-state J')
  call require(all(main>0.0_real64),'positive reconstructed J diagonal')

  rhs=(mdiag/total_dt)*eraw
  gamma=0.0_real64
  call reference_tridag(numnod,lower,main,upper,rhs,delta,gamma,ierr)
  call require(ierr==0,'one final-state defect TRIDAG solve')
  call require(all(ieee_is_finite(delta)),'finite transported defect')

  raw_m=sqrt(sum(mdiag*eraw*eraw))
  d2_m=2.0_real64*sqrt(sum(mdiag*delta*delta))
  bm=min(raw_m,d2_m)
  binf=bm/sqrt(min_m)
  dinf=2.0_real64*maxval(abs(delta))
  call require(ieee_is_finite(raw_m) .and. ieee_is_finite(d2_m) .and. ieee_is_finite(bm) .and. &
       ieee_is_finite(binf) .and. ieee_is_finite(dinf),'finite indicator metrics')
  call require(raw_m>=0.0_real64 .and. d2_m>=0.0_real64 .and. bm>=0.0_real64 .and. binf>=0.0_real64 .and. dinf>=0.0_real64, &
       'nonnegative indicator metrics')

  raw_ratio=eobs/e1_512
  binf_ratio=binf/e1_512
  dinf_ratio=dinf/e1_512
  if (binf>0.0_real64) then
    raw_to_binf=eobs/binf
  else
    raw_to_binf=huge(1.0_real64)
  end if
  finite_consistent=binf>=e1_512
  call require(ieee_is_finite(raw_ratio) .and. ieee_is_finite(binf_ratio) .and. ieee_is_finite(dinf_ratio), &
       'finite comparator ratios')

  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,A,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
       'FSI24_GC_ROW:H0=',h0,':JUMP=',jump,':EOBS=',eobs,':E1_512=',e1_512,':RAW_M=',raw_m,':D2_M=',d2_m, &
       ':BM=',bm,':BINF=',binf,':DINF=',dinf,':MIN_M=',min_m,':BINF_GE_E1_512=',yesno(finite_consistent), &
       ':RAW_RATIO=',raw_ratio,':BINF_RATIO=',binf_ratio,':DINF_RATIO=',dinf_ratio
  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
       'FSI24_GC_DIAG:MAX_M=',max_m,':RAW_TO_BINF=',raw_to_binf,':MASS=',max_mass, &
       ':EOBS_REPRO_DIFF=',reproduction_diff,':WATER_PROVIDER_DIFF=',provider_water_diff, &
       ':EXPLICIT_BOTTOM_DISTANCE=',explicit_bottom_distance
  write(*,'(A)') 'FSI24_GATE_C_NONLINEAR_CASE PASS'

contains

  subroutine read_inputs(initial_head,jump_head,expected_obs,reference_difference)
    real(real64), intent(out) :: initial_head,jump_head,expected_obs,reference_difference
    character(len=128) :: arg
    integer :: stat
    if (command_argument_count()/=4) error stop 'F-SI24 Gate C requires h0 jump expected_eobs e1_512'
    call get_command_argument(1,arg); read(arg,*,iostat=stat) initial_head; if (stat/=0) error stop 'bad h0'
    call get_command_argument(2,arg); read(arg,*,iostat=stat) jump_head; if (stat/=0) error stop 'bad jump'
    call get_command_argument(3,arg); read(arg,*,iostat=stat) expected_obs; if (stat/=0) error stop 'bad expected eobs'
    call get_command_argument(4,arg); read(arg,*,iostat=stat) reference_difference; if (stat/=0) error stop 'bad E1_512'
  end subroutine read_inputs

  subroutine configure_problem(initial_head,p,hp,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id=240242_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)

    allocate(c(24,numnod)); c=0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)
    heads=initial_head
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    do k=2,numnod
      call require(transfer(conductivity(k),0_int64)==transfer(conductivity(1),0_int64),'uniform initial K configure')
    end do
    k0=conductivity(1)

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
    if (.not.same_type_as(tp,tp)) error stop 'F-SI24 Gate C invalid top provider type'
  end subroutine configure_problem

  subroutine assemble_current_policy_final_jacobian(k0,m,bottom_distance,subdiag,diag,superdiag,g)
    real(real64), intent(in) :: k0,m(:),bottom_distance
    real(real64), intent(out) :: subdiag(:),diag(:),superdiag(:),g(:)
    integer :: j
    subdiag=0.0_real64; superdiag=0.0_real64; diag=0.0_real64; g=0.0_real64
    do j=2,numnod
      g(j)=k0/parameters%node_distance(j)
      subdiag(j)=-g(j)
      superdiag(j-1)=-g(j)
    end do
    g(numnod+1)=k0/bottom_distance
    diag(1)=m(1)/total_dt+g(2)
    do j=2,numnod-1
      diag(j)=m(j)/total_dt+g(j)+g(j+1)
    end do
    diag(numnod)=m(numnod)/total_dt+g(numnod)+g(numnod+1)
  end subroutine assemble_current_policy_final_jacobian

  pure real(real64) function fp_bound(scale) result(value)
    real(real64), intent(in) :: scale
    value=65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(scale))
  end function fp_bound

  pure function yesno(value) result(text)
    logical, intent(in) :: value
    character(len=3) :: text
    if (value) then; text='YES'; else; text='NO '; end if
  end function yesno

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FSI24_GATE_C_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi24_gate_c_nonlinear_b110
