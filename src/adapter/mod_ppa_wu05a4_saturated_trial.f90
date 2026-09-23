! Restricted single standard-domain evaluator: SATFLOW only, no surface input,
! absorption, rapid drainage, covering layer or interdomain redistribution.
module mod_ppa_wu05a4_saturated_trial
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_ppa_wu05a3_satflow_task1
  use mod_ppa_wu05a3_satflow_derivative
  use mod_ppa_wu05a3_volundr,only:ppa_wu05a3_volume_under_level,PPA_WU05A3_OK
  use mod_ppa_wu05a4_storage_bounds
  use mod_ppa_wu05a4_inflow_limit
  use mod_ppa_wu05a4_outflow_limit
  use mod_ppa_wu05a4_trial_exchange,only:macro_trial_key,macro_exchange_evaluation, &
      macro_used_exchange,discard_macro_exchange,apply_macro_residual,apply_macro_diagonal
  implicit none
  private
  type,public::saturated_domain_inputs
    integer::matrix_top=0,pore_saturated_top=0
    real(real64)::bottom=0,pore_level=0,matrix_level=0,storage=0,saturated_fraction=0
    real(real64),allocatable::z(:),dz(:),volume(:),resistance_inverse(:)
  end type
  public::prepare_saturated_trial,evaluate_saturated_residual,evaluate_saturated_system
contains
  ! Candidate-only assembly: residual and diagonal must belong to one evaluation.
  ! If either application fails, neither caller vector is changed.
  subroutine evaluate_saturated_system(input,head,dt,key,derivative_enabled,residual,diagonal, &
      used,storage_candidate,ok)
    type(saturated_domain_inputs),intent(in)::input
    real(real64),intent(in)::head(:),dt
    type(macro_trial_key),intent(in)::key
    logical,intent(in)::derivative_enabled
    real(real64),intent(inout)::residual(:),diagonal(:)
    type(macro_used_exchange),intent(out)::used
    real(real64),intent(out)::storage_candidate
    logical,intent(out)::ok
    type(macro_used_exchange)::trial_used
    real(real64),allocatable::trial_residual(:),trial_diagonal(:)
    real(real64)::trial_storage
    call discard_macro_exchange(used)
    storage_candidate=0
    trial_residual=residual; trial_diagonal=diagonal
    call evaluate_saturated_residual(input,head,dt,key,trial_residual,trial_used,trial_storage,ok)
    if(.not.ok)return
    call apply_macro_diagonal(trial_used,key,derivative_enabled,trial_diagonal,ok)
    if(.not.ok)return
    residual=trial_residual; diagonal=trial_diagonal
    used=trial_used; storage_candidate=trial_storage
  end subroutine

  ! This restricted evaluator admits fixed contiguous midpoint geometry only.
  ! The tolerance checks representation consistency; it is not a mass tolerance.
  logical function consistent_pore_geometry(input) result(valid)
    type(saturated_domain_inputs),intent(in)::input
    real(real64)::expected_storage,tolerance,scale
    integer::n,i,status
    valid=.false.
    n=size(input%dz)
    if(.not.all(ieee_is_finite(input%dz)).or..not.all(ieee_is_finite(input%z)))return
    if(.not.all(ieee_is_finite(input%volume)))return
    if(.not.all(ieee_is_finite([input%bottom,input%pore_level,input%storage])))return
    if(any(input%dz<=0).or.any(input%volume<0).or.any(input%volume>input%dz))return
    if(input%storage<0)return
    scale=max(1.0_real64,maxval(abs(input%z)),maxval(input%dz),abs(input%bottom))
    tolerance=32.0_real64*epsilon(1.0_real64)*scale
    if(abs(input%bottom-(input%z(n)-0.5_real64*input%dz(n)))>tolerance)return
    do i=2,n
      if(abs((input%z(i-1)-0.5_real64*input%dz(i-1)) &
          -(input%z(i)+0.5_real64*input%dz(i)))>tolerance)return
    end do
    if(input%pore_level<input%bottom.or.input%pore_level>input%z(1)+0.5_real64*input%dz(1))return
    call ppa_wu05a3_volume_under_level(input%pore_level,input%bottom,n,input%dz,input%volume, &
        expected_storage,status)
    if(status/=PPA_WU05A3_OK)return
    tolerance=32.0_real64*epsilon(1.0_real64)*max(1.0_real64,expected_storage,input%storage)
    if(abs(expected_storage-input%storage)>tolerance)return
    valid=.true.
  end function

  ! A failed preparation must not leave the previous residual's transfer usable.
  ! Scalar candidate storage is exposed only after successful residual application.
  subroutine evaluate_saturated_residual(input,head,dt,key,residual,used,storage_candidate,ok)
    type(saturated_domain_inputs),intent(in)::input
    real(real64),intent(in)::head(:),dt
    type(macro_trial_key),intent(in)::key
    real(real64),intent(inout)::residual(:)
    type(macro_used_exchange),intent(out)::used
    real(real64),intent(out)::storage_candidate
    logical,intent(out)::ok
    type(macro_exchange_evaluation)::evaluation
    real(real64)::trial_storage
    call discard_macro_exchange(used)
    storage_candidate=0
    call prepare_saturated_trial(input,head,dt,key,evaluation,trial_storage,ok)
    if(.not.ok)return
    call apply_macro_residual(evaluation,key,head,residual,used,ok)
    if(.not.ok)return
    storage_candidate=trial_storage
  end subroutine

  subroutine prepare_saturated_trial(input,head,dt,key,evaluation,storage_candidate,ok)
    type(saturated_domain_inputs),intent(in)::input
    real(real64),intent(in)::head(:),dt
    type(macro_trial_key),intent(in)::key
    type(macro_exchange_evaluation),intent(out)::evaluation
    real(real64),intent(out)::storage_candidate
    logical,intent(out)::ok
    real(real64),allocatable::dh(:),potential(:),inpot(:),outpot(:),zeros(:),ones(:)
    real(real64),allocatable::qin(:),qout(:),unused(:),unused2(:),hout(:),derivative(:)
    real(real64)::total_in,total_out,ground,minimum,total_volume,frac,tmp,maximum,excess,top(2),candidate
    integer::n,status
    logical::valid
    ok=.false.; storage_candidate=0
    n=size(head)
    if(n<1.or.key%lineage<=0.or.key%revision<0.or.key%attempt<=0.or.key%evaluation<=0) return
    if(.not.ieee_is_finite(dt))return
    if(dt<=0)return
    if(.not.allocated(input%z).or..not.allocated(input%dz).or..not.allocated(input%volume) &
        .or..not.allocated(input%resistance_inverse))return
    if(size(input%z)/=n.or.size(input%dz)/=n.or.size(input%volume)/=n &
        .or.size(input%resistance_inverse)/=n)return
    if(.not.all(ieee_is_finite(head)))return
    if(.not.consistent_pore_geometry(input))return
    total_volume=sum(input%volume)
    call domain_storage_bounds(input%bottom,n,input%dz,input%volume,total_volume,input%storage, &
        input%matrix_level,input%bottom,.false.,ground,minimum,valid)
    if(.not.valid)return
    allocate(dh(n),potential(n),inpot(n),outpot(n),zeros(n),ones(n),qin(n),qout(n), &
        unused(n),unused2(n),hout(n),derivative(n))
    zeros=0; ones=1
    ! Only the wet-pore Darcy branch is admitted here: dry-pore seepage/shape
    ! resistance would require additional physical parameters, not defaults.
    if(input%matrix_top<1.or.input%matrix_top>n)return
    if(.not.ieee_is_finite(input%pore_level))return
    if(.not.all(ieee_is_finite(input%z)))return
    if(any(input%pore_level-input%z(input%matrix_top:n)<=0))return
    call ppa_wu05a3_satflow_task1(n,input%matrix_top,n,input%pore_saturated_top, &
        input%pore_level,input%matrix_level,head,input%z,input%dz,input%saturated_fraction, &
        input%resistance_inverse,0,ones,ones,zeros,zeros,acos(-1.0_real64),1.0_real64,dt, &
        dh,potential,inpot,total_in,status)
    if(status/=PPA_WU05A3_SATFLOW_TASK1_OK)return
    outpot=max(-potential,0.0_real64); total_out=sum(outpot)
    call limit_domain_inflow(input%storage,total_volume,ground,dt,0.0_real64,0.0_real64, &
        0.0_real64,total_in,total_out,zeros,inpot,frac,tmp,maximum,excess,top,unused,qin,valid)
    if(.not.valid)return
    call limit_domain_outflow(dt,total_out,max(0.0_real64,minimum-tmp),outpot,zeros,zeros, &
        frac,qout,unused,unused2,valid)
    if(.not.valid)return
    call ppa_wu05a3_satflow_derivative(input%matrix_top,n,1,head,dh,qin,qout,zeros,hout,derivative,status)
    if(status/=PPA_WU05A3_SATFLOW_DERIVATIVE_OK)return
    candidate=input%storage+(sum(qin)-sum(qout))*dt
    if(.not.ieee_is_finite(candidate))return
    evaluation%key=key; evaluation%dt=dt; evaluation%head=head
    evaluation%rate=qout-qin; evaluation%derivative=derivative
    storage_candidate=candidate
    ok=.true.
  end subroutine
end module
