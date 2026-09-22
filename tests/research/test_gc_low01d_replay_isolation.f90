program test_gc_low01d_replay_isolation
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=4
  real(real64), parameter :: dt=1.0e-4_real64, mass_tol=1.0e-10_real64
  real(real64), parameter :: z(n)=[-25.0_real64,-75.0_real64,-150.0_real64,-250.0_real64]
  real(real64), parameter :: dz(n)=[50.0_real64,50.0_real64,100.0_real64,100.0_real64]
  real(real64), parameter :: node_distance(n)=[25.0_real64,50.0_real64,75.0_real64,100.0_real64]
  real(real64), parameter :: bottom_face=-300.0_real64
  real(real64), parameter :: hphi_a=-350.0_real64, hphi_b=-349.9_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_result_t) :: a1,b,a2
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: raw(24,n), origin_h(n), origin_theta(n)
  real(real64) :: accepted_h(n), accepted_theta(n), accepted_gwl, accepted_mass
  real(real64) :: mass_a1,mass_b,mass_a2
  integer :: accepted_revision

  call configure()
  accepted_h=origin_h
  accepted_theta=origin_theta
  accepted_gwl=hphi_a
  accepted_mass=0.0_real64
  accepted_revision=0

  call run_trial(hphi_a,a1,mass_a1)
  call require_origin_unchanged('after A1 reject')

  call run_trial(hphi_b,b,mass_b)
  call require_origin_unchanged('after B reject')

  call run_trial(hphi_a,a2,mass_a2)
  call require_origin_unchanged('before A2 accept')

  call require(result_bitwise_same(a1,a2),'A1/A2 candidate replay')
  call require(.not.result_bitwise_same(a1,b),'B non-vacuous candidate')
  call require(same_bits(mass_a1,mass_a2),'A1/A2 mass residual replay')

  ! Exactly one publication: final A2 only.
  accepted_h=a2%candidate_state%pressure_head
  accepted_theta=a2%candidate_state%water_content
  accepted_gwl=hphi_a
  accepted_revision=accepted_revision+1
  accepted_mass=accepted_mass+a2%bottom_flux*dt

  call require(accepted_revision==1,'exactly one accepted revision')
  call require(same_array_bits(accepted_h,a2%candidate_state%pressure_head),'accepted head is A2')
  call require(same_array_bits(accepted_theta,a2%candidate_state%water_content),'accepted water is A2')
  call require(same_bits(accepted_gwl,hphi_a),'accepted H_phreatic is A2')
  call require(abs(accepted_mass-a2%bottom_flux*dt)<=1.0e-12_real64,'exactly one accepted interface mass')
  call require(abs(accepted_mass-b%bottom_flux*dt)>1.0e-16_real64 .or. &
               .not.same_bits(b%bottom_flux,a2%bottom_flux), 'rejected B not ledger authority')

  write(*,'(A,ES26.17E3)') 'GC_LOW01D_A1_QBOT_CM_PER_DAY=',a1%bottom_flux
  write(*,'(A,ES26.17E3)') 'GC_LOW01D_B_QBOT_CM_PER_DAY=',b%bottom_flux
  write(*,'(A,ES26.17E3)') 'GC_LOW01D_A2_QBOT_CM_PER_DAY=',a2%bottom_flux
  write(*,'(A,ES26.17E3)') 'GC_LOW01D_ACCEPTED_MASS_CM=',accepted_mass
  write(*,'(A,I0)') 'GC_LOW01D_ACCEPTED_REVISION=',accepted_revision
  write(*,'(A)') 'GC_LOW01D_REJECTED_TRIALS_ISOLATED=PASS'
  write(*,'(A)') 'GC_LOW01D_A1_A2_REPLAY=PASS'
  write(*,'(A)') 'GC_LOW01D_NONVACUOUS_B=PASS'
  write(*,'(A)') 'GC_LOW01D_EXACTLY_ONCE_ACCEPTANCE=PASS'
  write(*,'(A)') 'GC_LOW01D_LEDGER_PUBLICATION=PASS'
  write(*,'(A)') 'GC_LOW01D_GATE=PASS'

contains

  subroutine configure()
    integer :: j
    real(real64) :: conductivity(n),capacity(n),dkdh(n)

    parameters%parameter_set_id=101004_int64
    parameters%active_nodes=n
    allocate(parameters%z(n),parameters%dz(n),parameters%node_distance(n))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=node_distance

    raw=0.0_real64
    do j=1,n
      raw(1,j)=0.032_real64; raw(2,j)=0.423_real64; raw(3,j)=4.75_real64
      raw(4,j)=0.0135_real64; raw(5,j)=0.365_real64; raw(6,j)=1.455_real64
      raw(7,j)=1.0_real64-1.0_real64/raw(6,j); raw(8,j)=raw(4,j)
      raw(9,j)=0.0_real64; raw(10,j)=raw(3,j); raw(11,j)=0.999_real64
      raw(12,j)=0.99_real64*raw(3,j); raw(22,j)=-1.0e6_real64; raw(23,j)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,raw)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)

    origin_h=hphi_a-z
    call constitutive%evaluate(origin_h,origin_theta,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(origin_theta)),'finite origin water')

    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
  end subroutine configure

  subroutine run_trial(hphi,result,mass_residual)
    real(real64), intent(in) :: hphi
    type(soil_water_solve_result_t), intent(out) :: result
    real(real64), intent(out) :: mass_residual
    type(soil_water_solve_request_t) :: request
    real(real64) :: storage0,storage1,hbot

    call require(hphi<bottom_face,'trial below bottom face')
    hbot=hphi-bottom_face

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state%active_nodes=n
    allocate(request%base_state%pressure_head(n),request%base_state%water_content(n))
    request%base_state%pressure_head=accepted_h
    request%base_state%water_content=accepted_theta
    request%base_state%ponding_depth=0.0_real64
    request%base_state%groundwater_level=accepted_gwl
    request%step_duration=dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%top_flux=0.0_real64
    request%boundary%top_head=accepted_h(1)
    request%boundary%bottom_mode=5
    request%boundary%bottom_head=hbot
    request%boundary%bottom_flux=0.0_real64
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=24
    request%numerical%max_backtracking=8
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-12_real64
    request%numerical%compartment_balance_tolerance=1.0e-10_real64
    request%numerical%total_balance_tolerance=1.0e-10_real64
    request%numerical%head_abs_tolerance=1.0e-10_real64
    request%numerical%head_rel_tolerance=1.0e-10_real64
    request%numerical%ponding_tolerance=1.0e-10_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider

    storage0=sum(accepted_theta*dz)
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,'mode5 trial converged')
    call require(.not.result%retry_advised,'no retry')
    call require(result%diagnostics%alternative_solver_calls==0,'no alternative solver')
    storage1=sum(result%candidate_state%water_content*dz)+result%candidate_state%ponding_depth
    mass_residual=storage1-storage0-(-result%top_flux+result%bottom_flux)*dt
    call require(abs(mass_residual)<=mass_tol,'trial mass closure')

    deallocate(request%base_state%pressure_head,request%base_state%water_content)
  end subroutine run_trial

  subroutine require_origin_unchanged(label)
    character(len=*), intent(in) :: label
    call require(accepted_revision==0,trim(label)//' revision')
    call require(same_array_bits(accepted_h,origin_h),trim(label)//' head')
    call require(same_array_bits(accepted_theta,origin_theta),trim(label)//' water')
    call require(same_bits(accepted_gwl,hphi_a),trim(label)//' H_phreatic')
    call require(same_bits(accepted_mass,0.0_real64),trim(label)//' ledger')
  end subroutine require_origin_unchanged

  logical function result_bitwise_same(x,y) result(ok)
    type(soil_water_solve_result_t), intent(in) :: x,y
    ok=same_array_bits(x%candidate_state%pressure_head,y%candidate_state%pressure_head) .and. &
       same_array_bits(x%candidate_state%water_content,y%candidate_state%water_content) .and. &
       same_bits(x%bottom_flux,y%bottom_flux) .and. same_bits(x%top_flux,y%top_flux) .and. &
       x%diagnostics%nonlinear_iterations==y%diagnostics%nonlinear_iterations .and. &
       x%diagnostics%linear_solves==y%diagnostics%linear_solves
  end function result_bitwise_same

  logical function same_array_bits(a,b) result(ok)
    real(real64), intent(in) :: a(:),b(:)
    integer :: j
    ok=size(a)==size(b)
    if(.not.ok)return
    do j=1,size(a)
      if(.not.same_bits(a(j),b(j))) then
        ok=.false.; return
      end if
    end do
  end function same_array_bits

  logical function same_bits(a,b) result(ok)
    real(real64), intent(in) :: a,b
    ok=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine require(ok,label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if(.not.ok) then
      write(*,'(A,1X,A)') 'GC_LOW01D_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_gc_low01d_replay_isolation
