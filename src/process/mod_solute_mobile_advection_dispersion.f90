module mod_solute_mobile_advection_dispersion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state
  implicit none
  private
  integer,parameter,public :: SOLUTE_TRANSPORT_STEP_LIMIT=6
  type,public :: mobile_dispersion_physics_t
    real(real64) :: molecular_diffusion_cm2_day=0.0_real64
    real(real64),allocatable :: dispersivity_cm(:),theta_sat_left(:),face_distance_cm(:),face_left_weight(:),face_right_weight(:)
  contains
    procedure :: valid => physics_valid
  end type
  type,public :: mobile_transport_numerical_t
    logical :: enabled=.false.
    real(real64) :: max_step_day=0.0_real64
    real(real64) :: courant_fraction=0.9_real64
    integer :: max_substeps=0
  contains
    procedure :: valid => numerical_valid
  end type
  type,public :: mobile_transport_receipt_t
    type(mobile_salt_fluxes_t) :: balance
    real(real64),allocatable :: root_by_node_mg_cm2(:)
    integer :: substeps=0
  end type
  public :: advance_mobile_advection_dispersion
contains
  pure logical function physics_valid(self,n) result(ok)
    class(mobile_dispersion_physics_t),intent(in)::self
    integer,intent(in)::n
    ok=.false.
    if(n<1.or..not.allocated(self%dispersivity_cm).or..not.allocated(self%theta_sat_left).or. &
      .not.allocated(self%face_distance_cm).or..not.allocated(self%face_left_weight).or. &
      .not.allocated(self%face_right_weight))return
    if(size(self%dispersivity_cm)/=n-1.or.size(self%theta_sat_left)/=n-1.or. &
      size(self%face_distance_cm)/=n-1.or.size(self%face_left_weight)/=n-1.or.size(self%face_right_weight)/=n-1)return
    if(.not.ieee_is_finite(self%molecular_diffusion_cm2_day))return
    if(any(.not.ieee_is_finite(self%dispersivity_cm)).or.any(.not.ieee_is_finite(self%theta_sat_left)).or. &
      any(.not.ieee_is_finite(self%face_distance_cm)).or.any(.not.ieee_is_finite(self%face_left_weight)).or. &
      any(.not.ieee_is_finite(self%face_right_weight)))return
    ok=self%molecular_diffusion_cm2_day>=0.0_real64.and.all(self%dispersivity_cm>=0.0_real64).and. &
      all(self%theta_sat_left>0.0_real64).and.all(self%theta_sat_left<=1.0_real64).and. &
      all(self%face_distance_cm>0.0_real64).and.all(self%face_left_weight>=0.0_real64).and. &
      all(self%face_left_weight<=1.0_real64).and.all(self%face_right_weight>=0.0_real64).and. &
      all(self%face_right_weight<=1.0_real64).and.all(self%face_left_weight+self%face_right_weight>0.0_real64)
  end function
  pure logical function numerical_valid(self) result(ok)
    class(mobile_transport_numerical_t),intent(in)::self
    ok=self%enabled.and.ieee_is_finite(self%max_step_day).and.ieee_is_finite(self%courant_fraction)
    ok=ok.and.self%max_step_day>0.0_real64.and.self%max_substeps>0.and. &
      self%courant_fraction>0.0_real64.and.self%courant_fraction<=1.0_real64
  end function

  subroutine face_conductance(physics,water,q,g,ok)
    type(mobile_dispersion_physics_t),intent(in)::physics
    real(real64),intent(in)::water(:),q(:)
    real(real64),intent(out)::g(:)
    logical,intent(out)::ok
    real(real64)::tf,log_term,molecular,mechanical
    integer::i
    ok=.false.;g=0.0_real64
    do i=1,size(g)
      tf=physics%face_left_weight(i)*water(i)+physics%face_right_weight(i)*water(i+1)
      if(tf<=0.0_real64.or..not.ieee_is_finite(tf))return
      molecular=0.0_real64;mechanical=0.0_real64
      if(physics%molecular_diffusion_cm2_day>0.0_real64)then
        log_term=log(physics%molecular_diffusion_cm2_day)+3.33_real64*log(tf)- &
          2.0_real64*log(physics%theta_sat_left(i))-log(physics%face_distance_cm(i))
        if(log_term>=log(huge(1.0_real64)).or.log_term<log(tiny(1.0_real64)))return
        molecular=exp(log_term)
      end if
      if(physics%dispersivity_cm(i)>0.0_real64.and.abs(q(i+1))>0.0_real64)then
        log_term=log(physics%dispersivity_cm(i))+log(abs(q(i+1)))-log(physics%face_distance_cm(i))
        if(log_term>=log(huge(1.0_real64)).or.log_term<log(tiny(1.0_real64)))return
        mechanical=exp(log_term)
      end if
      if(molecular>huge(1.0_real64)-mechanical)return
      g(i)=molecular+mechanical
    end do
    ok=.true.
  end subroutine

  subroutine advance_mobile_advection_dispersion(committed,dz,water_start,water_end,q,root,top_c,bottom_c,tscf, &
      duration,physics,numerical,qdra,qssdi,cdrain,cdrain_available,candidate,receipt,status,top_outflow_carries_solute)
    type(mobile_salt_state_t),intent(in)::committed
    real(real64),intent(in)::dz(:),water_start(:),water_end(:),q(:),root(:),top_c,bottom_c,tscf,duration
    type(mobile_dispersion_physics_t),intent(in)::physics
    type(mobile_transport_numerical_t),intent(in)::numerical
    real(real64),allocatable,intent(in)::qdra(:,:),qssdi(:)
    real(real64),intent(in)::cdrain
    logical,intent(in)::cdrain_available
    logical,intent(in),optional::top_outflow_carries_solute
    type(mobile_salt_state_t),intent(out)::candidate
    type(mobile_transport_receipt_t),intent(out)::receipt
    integer,intent(out)::status
    type(mobile_salt_state_t)::current,advected
    type(mobile_salt_fluxes_t)::step_balance
    type(mobile_transport_receipt_t)::total
    real(real64),allocatable::g(:),outgoing(:),vmin(:),w0(:),w1(:),c(:),mass(:)
    real(real64)::stable,dt,ratio,a,b,transfer,expected,tol,water_error
    integer::n,i,k,steps
    logical::ok,top_liquid
    candidate=mobile_salt_state_t();receipt=mobile_transport_receipt_t();status=SOLUTE_INVALID
    top_liquid=.true.
    if(present(top_outflow_carries_solute))top_liquid=top_outflow_carries_solute
    n=size(dz)
    if(.not.physics%valid(n).or..not.numerical%valid())return
    if(size(water_start)/=n.or.size(water_end)/=n.or.size(root)/=n.or.size(q)/=n+1)return
    if(.not.allocated(qdra).or..not.allocated(qssdi))return
    if(size(qdra,2)/=n.or.size(qssdi)/=n)return
    if(.not.allocated(committed%mass_mg_cm2).or..not.allocated(committed%concentration_mg_cm3))return
    if(size(committed%mass_mg_cm2)/=n.or.size(committed%concentration_mg_cm3)/=n)return
    if(any(.not.ieee_is_finite(dz)).or.any(.not.ieee_is_finite(water_start)).or. &
      any(.not.ieee_is_finite(water_end)).or.any(.not.ieee_is_finite(q)).or.any(.not.ieee_is_finite(root)).or. &
      any(.not.ieee_is_finite(qdra)).or.any(.not.ieee_is_finite(qssdi)).or. &
      any(.not.ieee_is_finite(committed%mass_mg_cm2)).or.any(.not.ieee_is_finite(committed%concentration_mg_cm3)))return
    if(.not.all(ieee_is_finite([top_c,bottom_c,tscf,duration,cdrain])))return
    if(any(dz<=0.0_real64).or.any(water_start<=0.0_real64).or.any(water_end<=0.0_real64).or. &
      any(water_start>1.0_real64).or.any(water_end>1.0_real64).or.any(root<0.0_real64).or. &
      any(committed%mass_mg_cm2<0.0_real64).or.any(committed%concentration_mg_cm3<0.0_real64).or. &
      min(top_c,bottom_c,cdrain)<0.0_real64.or.tscf<0.0_real64.or.tscf>10.0_real64.or.duration<=0.0_real64)return
    if(any(qdra<0.0_real64).and..not.cdrain_available)return
    tol=512.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(dz*water_start),maxval(dz*water_end), &
      duration*maxval(abs(q)))
    do i=1,n
      water_error=(water_end(i)-water_start(i))*dz(i)-duration*(q(i)-q(i+1)+qssdi(i)-sum(qdra(:,i))-root(i))
      if(abs(water_error)>tol)then
        status=SOLUTE_WATER_CLOSURE;return
      end if
    end do
    allocate(g(n-1),outgoing(n))
    call face_conductance(physics,max(water_start,water_end),q,g,ok)
    if(.not.ok)return
    outgoing=tscf*root+sum(max(qdra,0.0_real64),dim=1)
    if(top_liquid)outgoing(1)=outgoing(1)+max(-q(1),0.0_real64)
    outgoing(n)=outgoing(n)+max(q(n+1),0.0_real64)
    do i=1,n-1
      outgoing(i)=outgoing(i)+max(q(i+1),0.0_real64)+g(i)
      outgoing(i+1)=outgoing(i+1)+max(-q(i+1),0.0_real64)+g(i)
    end do
    if(any(.not.ieee_is_finite(outgoing)))return
    vmin=min(water_start,water_end)*dz
    stable=min(duration,numerical%max_step_day)
    do i=1,n
      if(outgoing(i)>0.0_real64)then
        if(log(outgoing(i))+log(stable)>log(vmin(i))+log(numerical%courant_fraction)) &
          stable=numerical%courant_fraction*vmin(i)/outgoing(i)
      end if
    end do
    if(stable<=0.0_real64)return
    if(stable<duration/real(numerical%max_substeps,real64))then
      status=SOLUTE_TRANSPORT_STEP_LIMIT;return
    end if
    ratio=duration/stable
    if(.not.ieee_is_finite(ratio).or.ratio>real(numerical%max_substeps,real64))then
      status=SOLUTE_TRANSPORT_STEP_LIMIT;return
    end if
    steps=max(1,ceiling(ratio));dt=duration/real(steps,real64)
    current=committed
    allocate(total%root_by_node_mg_cm2(n),total%balance%qdra_signed_out_mg_cm2(size(qdra,1)))
    total%root_by_node_mg_cm2=0.0_real64;total%balance%qdra_signed_out_mg_cm2=0.0_real64
    do k=1,steps
      a=real(k-1,real64)/real(steps,real64);b=real(k,real64)/real(steps,real64)
      w0=water_start+a*(water_end-water_start);w1=water_start+b*(water_end-water_start)
      do i=1,n
        if(w0(i)*dz(i)<1.0_real64)then
          if(current%mass_mg_cm2(i)>huge(1.0_real64)*(w0(i)*dz(i)))then
            status=SOLUTE_INVALID;return
          end if
        end if
        ! Conservatively reject an unrepresentable drying concentration before
        ! calling the advection primitive, which derives its candidate CML.
        if(w1(i)*dz(i)<1.0_real64)then
          if(current%mass_mg_cm2(i)>huge(1.0_real64)*(w1(i)*dz(i)))then
            status=SOLUTE_INVALID;return
          end if
        end if
      end do
      current%concentration_mg_cm3=current%mass_mg_cm2/(w0*dz)
      if(k==1)then
        tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(current%concentration_mg_cm3))
        if(any(abs(current%concentration_mg_cm3-committed%concentration_mg_cm3)>tol))return
      end if
      c=current%concentration_mg_cm3
      ! A zero-level drainage matrix is a valid no-drainage layout. The older
      ! primitive requires a positive level count when its optional argument exists.
      if(size(qdra,1)>0)then
        call advance_mobile_salt_trial(current,dz,w0,w1,q,root,top_c,bottom_c,tscf,dt,advected,step_balance,status, &
          qdra_rate=qdra,qssdi_rate=qssdi,cdrain_mg_cm3=cdrain,cdrain_available=cdrain_available,top_outflow_carries_solute=top_liquid)
      else
        call advance_mobile_salt_trial(current,dz,w0,w1,q,root,top_c,bottom_c,tscf,dt,advected,step_balance,status, &
          qssdi_rate=qssdi,cdrain_mg_cm3=cdrain,cdrain_available=cdrain_available,top_outflow_carries_solute=top_liquid)
      end if
      if(status/=SOLUTE_OK)return
      call face_conductance(physics,w0,q,g,ok)
      if(.not.ok)then
        status=SOLUTE_INVALID;return
      end if
      mass=advected%mass_mg_cm2
      do i=1,n-1
        transfer=dt*g(i)*(c(i)-c(i+1))
        mass(i)=mass(i)-transfer;mass(i+1)=mass(i+1)+transfer
      end do
      if(any(.not.ieee_is_finite(mass)).or.any(mass<0.0_real64))then
        status=SOLUTE_NEGATIVE_MASS;return
      end if
      do i=1,n
        if(w1(i)*dz(i)<1.0_real64)then
          if(mass(i)>huge(1.0_real64)*(w1(i)*dz(i)))then
            status=SOLUTE_INVALID;return
          end if
        end if
      end do
      current%mass_mg_cm2=mass;current%concentration_mg_cm3=mass/(w1*dz)
      total%root_by_node_mg_cm2=total%root_by_node_mg_cm2+tscf*root*dt*c
      total%balance%top_input_mg_cm2=total%balance%top_input_mg_cm2+step_balance%top_input_mg_cm2
      total%balance%top_output_mg_cm2=total%balance%top_output_mg_cm2+step_balance%top_output_mg_cm2
      total%balance%bottom_input_mg_cm2=total%balance%bottom_input_mg_cm2+step_balance%bottom_input_mg_cm2
      total%balance%bottom_output_mg_cm2=total%balance%bottom_output_mg_cm2+step_balance%bottom_output_mg_cm2
      if(size(qdra,1)>0)total%balance%qdra_signed_out_mg_cm2= &
        total%balance%qdra_signed_out_mg_cm2+step_balance%qdra_signed_out_mg_cm2
    end do
    total%balance%root_uptake_mg_cm2=sum(total%root_by_node_mg_cm2)
    expected=sum(committed%mass_mg_cm2)+total%balance%top_input_mg_cm2-total%balance%top_output_mg_cm2+ &
      total%balance%bottom_input_mg_cm2-total%balance%bottom_output_mg_cm2-total%balance%root_uptake_mg_cm2- &
      sum(total%balance%qdra_signed_out_mg_cm2)
    total%balance%closure_error_mg_cm2=sum(current%mass_mg_cm2)-expected
    tol=1024.0_real64*epsilon(1.0_real64)*real(steps,real64)*max(1.0_real64,abs(expected),sum(current%mass_mg_cm2))
    if(.not.ieee_is_finite(total%balance%closure_error_mg_cm2).or.abs(total%balance%closure_error_mg_cm2)>tol)then
      status=SOLUTE_BALANCE_FAILURE;return
    end if
    total%substeps=steps;candidate=current;receipt=total;status=SOLUTE_OK
  end subroutine
end module
