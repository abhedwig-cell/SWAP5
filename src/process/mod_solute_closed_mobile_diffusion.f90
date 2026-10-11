module mod_solute_closed_mobile_diffusion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t, SOLUTE_OK, SOLUTE_INVALID, SOLUTE_BALANCE_FAILURE
  implicit none
  private
  integer, parameter, public :: SOLUTE_DIFFUSION_STEP_LIMIT=5
  type, public :: closed_diffusion_receipt_t
    integer :: substeps=0
    real(real64) :: closure_error_mg_cm2=0.0_real64
  end type
  public :: advance_closed_mobile_diffusion
contains
  subroutine advance_closed_mobile_diffusion(committed,dz,theta,theta_face,theta_sat_left,distance,ddif, &
      duration,max_step,max_substeps,candidate,receipt,status)
    type(mobile_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: dz(:),theta(:),theta_face(:),theta_sat_left(:),distance(:)
    real(real64), intent(in) :: ddif,duration,max_step
    integer, intent(in) :: max_substeps
    type(mobile_salt_state_t), intent(out) :: candidate
    type(closed_diffusion_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status
    real(real64), allocatable :: volume(:),g(:),out_rate(:),mass(:),next_mass(:),c(:)
    real(real64) :: stable,steps_real,step,transfer,tol,initial_total,log_g
    integer :: n,i,k,steps
    candidate=mobile_salt_state_t();receipt=closed_diffusion_receipt_t();status=SOLUTE_INVALID
    n=size(dz)
    if(n<1.or.size(theta)/=n.or.size(theta_face)/=n-1.or.size(theta_sat_left)/=n-1.or.size(distance)/=n-1)return
    if(.not.allocated(committed%mass_mg_cm2).or..not.allocated(committed%concentration_mg_cm3))return
    if(size(committed%mass_mg_cm2)/=n.or.size(committed%concentration_mg_cm3)/=n)return
    if(.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(theta)).or. &
      .not.all(ieee_is_finite(theta_face)).or..not.all(ieee_is_finite(theta_sat_left)).or. &
      .not.all(ieee_is_finite(distance)).or..not.all(ieee_is_finite(committed%mass_mg_cm2)).or. &
      .not.all(ieee_is_finite(committed%concentration_mg_cm3)).or. &
      .not.all(ieee_is_finite([ddif,duration,max_step])))return
    if(any(dz<=0.0_real64).or.any(theta<=0.0_real64).or.any(theta>1.0_real64).or. &
      any(theta_face<=0.0_real64).or.any(theta_sat_left<=0.0_real64).or.any(theta_sat_left>1.0_real64).or. &
      any(theta_face>theta_sat_left).or.any(distance<=0.0_real64).or. &
      any(committed%mass_mg_cm2<0.0_real64).or.any(committed%concentration_mg_cm3<0.0_real64).or. &
      ddif<0.0_real64.or.duration<=0.0_real64.or.max_step<=0.0_real64.or.max_substeps<1)return
    if(any(theta>huge(1.0_real64)/max(1.0_real64,maxval(dz))))return
    volume=theta*dz
    if(any(.not.ieee_is_finite(volume)).or.any(volume<=0.0_real64))return
    do i=1,n
      if(volume(i)<1.0_real64)then
        if(committed%mass_mg_cm2(i)>huge(1.0_real64)*volume(i))return
      end if
    end do
    c=committed%mass_mg_cm2/volume
    if(any(.not.ieee_is_finite(c)))return
    tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(c))
    if(any(abs(c-committed%concentration_mg_cm3)>tol))return
    allocate(g(n-1));g=0.0_real64
    if(ddif>0.0_real64)then
      do i=1,n-1
        log_g=log(ddif)+3.33_real64*log(theta_face(i))-2.0_real64*log(theta_sat_left(i))-log(distance(i))
        if(log_g>=log(huge(1.0_real64)))return
        if(log_g<log(tiny(1.0_real64)))return
        g(i)=exp(log_g)
      end do
    end if
    if(any(.not.ieee_is_finite(g)))return
    allocate(out_rate(n));out_rate=0.0_real64
    do i=1,n-1
      if(g(i)>huge(1.0_real64)-max(out_rate(i),out_rate(i+1)))return
      out_rate(i)=out_rate(i)+g(i);out_rate(i+1)=out_rate(i+1)+g(i)
    end do
    if(any(.not.ieee_is_finite(out_rate)))return
    stable=min(max_step,duration)
    do i=1,n
      if(out_rate(i)>0.0_real64)then
        ! Avoid forming a potentially overflowing V/G when G is tiny.
        if(log(out_rate(i))+log(stable)>log(volume(i)))stable=volume(i)/out_rate(i)
      end if
    end do
    if(stable<=0.0_real64)return
    if(stable<duration/real(max_substeps,real64))then
      status=SOLUTE_DIFFUSION_STEP_LIMIT;return
    end if
    steps_real=duration/stable
    if(.not.ieee_is_finite(steps_real))return
    if(steps_real>real(max_substeps,real64))then
      status=SOLUTE_DIFFUSION_STEP_LIMIT;return
    end if
    steps=max(1,ceiling(steps_real));step=duration/real(steps,real64)
    mass=committed%mass_mg_cm2;initial_total=sum(mass)
    if(.not.ieee_is_finite(initial_total))return
    do k=1,steps
      c=mass/volume;next_mass=mass
      do i=1,n-1
        transfer=step*g(i)*(c(i)-c(i+1))
        next_mass(i)=next_mass(i)-transfer;next_mass(i+1)=next_mass(i+1)+transfer
      end do
      if(any(.not.ieee_is_finite(next_mass)).or.any(next_mass<0.0_real64))return
      mass=next_mass
    end do
    tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,initial_total)*real(steps,real64)
    if(abs(sum(mass)-initial_total)>tol)then
      status=SOLUTE_BALANCE_FAILURE;return
    end if
    candidate%mass_mg_cm2=mass;candidate%concentration_mg_cm3=mass/volume
    receipt%substeps=steps;receipt%closure_error_mg_cm2=sum(mass)-initial_total
    status=SOLUTE_OK
  end subroutine
end module
