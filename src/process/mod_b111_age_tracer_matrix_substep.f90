module mod_b111_age_tracer_matrix_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_compartment_state, only: solute_compartment_state_t
  implicit none
  private

  integer,parameter,public::B111_AGE_MATRIX_OK=0
  integer,parameter,public::B111_AGE_MATRIX_INVALID=1
  integer,parameter,public::B111_AGE_MATRIX_NEGATIVE=2
  integer,parameter,public::B111_AGE_MATRIX_BALANCE=3

  type,public::b111_age_matrix_physics_t
    real(real64)::molecular_diffusion_cm2_day=0.0_real64
    real(real64),allocatable::dispersivity_cm(:)
    real(real64),allocatable::theta_sat_left(:)
    real(real64),allocatable::face_distance_cm(:)
    real(real64),allocatable::face_left_weight(:)
    real(real64),allocatable::face_right_weight(:)
  end type

  type,public::b111_age_matrix_receipt_t
    integer::status=B111_AGE_MATRIX_INVALID
    real(real64)::age_before=0.0_real64
    real(real64)::age_after=0.0_real64
    real(real64)::age_production=0.0_real64
    real(real64)::top_input=0.0_real64
    real(real64)::top_output=0.0_real64
    real(real64)::bottom_input=0.0_real64
    real(real64)::bottom_output=0.0_real64
    real(real64)::root_output=0.0_real64
    real(real64)::drainage_input=0.0_real64
    real(real64)::drainage_output=0.0_real64
    real(real64)::balance_residual=0.0_real64
  end type

  public::advance_b111_age_matrix_substep

contains

  subroutine advance_b111_age_matrix_substep(committed,dz,theta_start,theta_end,q,root,qdra, &
       top_age,bottom_age,drain_age,dt,physics,candidate,receipt)
    type(solute_compartment_state_t),intent(in)::committed
    real(real64),intent(in)::dz(:),theta_start(:),theta_end(:),q(:),root(:),qdra(:,:)
    real(real64),intent(in)::top_age,bottom_age,drain_age,dt
    type(b111_age_matrix_physics_t),intent(in)::physics
    type(solute_compartment_state_t),intent(out)::candidate
    type(b111_age_matrix_receipt_t),intent(out)::receipt
    real(real64),allocatable::c(:),face_flux(:)
    real(real64)::theta_face,age_face,vpore,diffus,dispr
    real(real64)::top_flux,bottom_flux,drain_flux,root_flux,production
    real(real64)::before_i,after_i,expected,tol,scale
    integer::n,i,level

    candidate=committed
    receipt=b111_age_matrix_receipt_t()
    if(.not.committed%valid())return
    n=size(committed%age_amount)
    if(n<1.or.size(dz)/=n.or.size(theta_start)/=n.or.size(theta_end)/=n.or.size(root)/=n.or.size(q)/=n+1)return
    if(size(qdra,2)/=n.or..not.physics_valid(physics,n))return
    if(.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(theta_start)).or. &
       .not.all(ieee_is_finite(theta_end)).or..not.all(ieee_is_finite(q)).or. &
       .not.all(ieee_is_finite(root)).or..not.all(ieee_is_finite(qdra)).or. &
       .not.all(ieee_is_finite([top_age,bottom_age,drain_age,dt])))return
    if(any(dz<=0.0_real64).or.any(theta_start<=0.0_real64).or.any(theta_end<=0.0_real64).or. &
       any(root<0.0_real64).or.min(top_age,bottom_age,drain_age)<0.0_real64.or.dt<=0.0_real64)return

    allocate(c(n),face_flux(max(0,n-1)))
    c=committed%age_amount/(theta_start*dz)
    if(.not.all(ieee_is_finite(c)).or.any(c<0.0_real64))return

    do i=1,n-1
      theta_face=physics%face_left_weight(i)*theta_start(i)+physics%face_right_weight(i)*theta_start(i+1)
      if(theta_face<=0.0_real64)return
      age_face=physics%face_left_weight(i)*c(i)+physics%face_right_weight(i)*c(i+1)
      vpore=abs(q(i+1))/theta_face
      diffus=physics%molecular_diffusion_cm2_day*theta_face**2.33_real64/physics%theta_sat_left(i)**2
      dispr=diffus+physics%dispersivity_cm(i)*vpore+0.5_real64*dt*vpore*vpore
      face_flux(i)=(q(i+1)*age_face+theta_face*dispr*(c(i+1)-c(i))/physics%face_distance_cm(i))*dt
      if(.not.ieee_is_finite(face_flux(i)))return
    end do

    if(q(1)<0.0_real64)then
      top_flux=q(1)*top_age*dt
      receipt%top_input=-top_flux
    else
      top_flux=q(1)*c(1)*dt
      receipt%top_output=top_flux
    end if
    if(q(n+1)>0.0_real64)then
      bottom_flux=q(n+1)*bottom_age*dt
      receipt%bottom_input=bottom_flux
    else
      bottom_flux=q(n+1)*c(n)*dt
      receipt%bottom_output=-bottom_flux
    end if

    receipt%age_before=sum(committed%age_amount)
    receipt%age_production=0.0_real64
    do i=1,n
      before_i=committed%age_amount(i)
      root_flux=root(i)*c(i)*dt
      drain_flux=0.0_real64
      do level=1,size(qdra,1)
        if(qdra(level,i)>0.0_real64)then
          drain_flux=drain_flux+qdra(level,i)*c(i)*dt
          receipt%drainage_output=receipt%drainage_output+qdra(level,i)*c(i)*dt
        else
          drain_flux=drain_flux+qdra(level,i)*drain_age*dt
          receipt%drainage_input=receipt%drainage_input-qdra(level,i)*drain_age*dt
        end if
      end do
      production=0.5_real64*(theta_end(i)+theta_start(i))*dt*dz(i)
      receipt%root_output=receipt%root_output+root_flux
      receipt%age_production=receipt%age_production+production

      if(n==1)then
        candidate%age_amount(i)=before_i+bottom_flux-top_flux-root_flux-drain_flux+production
      else if(i==1)then
        candidate%age_amount(i)=before_i+face_flux(i)-top_flux-root_flux-drain_flux+production
      else if(i==n)then
        candidate%age_amount(i)=before_i+bottom_flux-face_flux(i-1)-root_flux-drain_flux+production
      else
        candidate%age_amount(i)=before_i+face_flux(i)-face_flux(i-1)-root_flux-drain_flux+production
      end if
    end do

    if(.not.candidate%valid().or.any(candidate%age_amount<0.0_real64))then
      candidate=committed
      receipt%status=B111_AGE_MATRIX_NEGATIVE
      return
    end if

    receipt%age_after=sum(candidate%age_amount)
    expected=receipt%age_before+receipt%top_input-receipt%top_output+receipt%bottom_input-receipt%bottom_output- &
         receipt%root_output+receipt%drainage_input-receipt%drainage_output+receipt%age_production
    receipt%balance_residual=receipt%age_after-expected
    scale=max(1.0_real64,abs(receipt%age_before),abs(receipt%age_after),abs(expected))
    tol=4096.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual)>tol)then
      candidate=committed
      receipt%status=B111_AGE_MATRIX_BALANCE
      return
    end if
    receipt%status=B111_AGE_MATRIX_OK
  end subroutine

  pure logical function physics_valid(p,n) result(ok)
    type(b111_age_matrix_physics_t),intent(in)::p
    integer,intent(in)::n
    ok=.false.
    if(n<1.or..not.ieee_is_finite(p%molecular_diffusion_cm2_day).or.p%molecular_diffusion_cm2_day<0.0_real64)return
    if(.not.allocated(p%dispersivity_cm).or..not.allocated(p%theta_sat_left).or. &
       .not.allocated(p%face_distance_cm).or..not.allocated(p%face_left_weight).or. &
       .not.allocated(p%face_right_weight))return
    if(size(p%dispersivity_cm)/=n-1.or.size(p%theta_sat_left)/=n-1.or.size(p%face_distance_cm)/=n-1.or. &
       size(p%face_left_weight)/=n-1.or.size(p%face_right_weight)/=n-1)return
    if(.not.all(ieee_is_finite(p%dispersivity_cm)).or..not.all(ieee_is_finite(p%theta_sat_left)).or. &
       .not.all(ieee_is_finite(p%face_distance_cm)).or..not.all(ieee_is_finite(p%face_left_weight)).or. &
       .not.all(ieee_is_finite(p%face_right_weight)))return
    ok=all(p%dispersivity_cm>=0.0_real64).and.all(p%theta_sat_left>0.0_real64).and. &
       all(p%face_distance_cm>0.0_real64).and.all(p%face_left_weight>=0.0_real64).and. &
       all(p%face_right_weight>=0.0_real64).and.all(p%face_left_weight+p%face_right_weight>0.0_real64)
  end function
end module
