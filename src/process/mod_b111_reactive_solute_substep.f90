module mod_b111_reactive_solute_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_solute_sorption, only: b111_sorption_result_t,b111_sorption_partition_total,B111_SORP_OK
  use mod_b111_solute_decay, only: b111_decay_result_t,evaluate_b111_solute_decay,B111_DECAY_OK
  use mod_b111_pond_solute_exchange, only: b111_pond_solute_result_t,evaluate_b111_pond_solute_exchange,B111_POND_SOL_OK
  implicit none
  private

  integer,parameter,public::B111_REACTIVE_OK=0
  integer,parameter,public::B111_REACTIVE_INVALID=1
  integer,parameter,public::B111_REACTIVE_NEGATIVE=2
  integer,parameter,public::B111_REACTIVE_PARTITION_FAILED=3
  integer,parameter,public::B111_REACTIVE_BALANCE=4

  type,public::b111_reactive_dispersion_t
    real(real64)::molecular_diffusion_cm2_day=0.0_real64
    real(real64),allocatable::dispersivity_cm(:)
    real(real64),allocatable::theta_sat_left(:)
    real(real64),allocatable::face_distance_cm(:)
    real(real64),allocatable::face_left_weight(:)
    real(real64),allocatable::face_right_weight(:)
  end type

  type,public::b111_reactive_substep_receipt_t
    integer::status=B111_REACTIVE_INVALID
    real(real64)::external_input=0.0_real64
    real(real64)::external_output=0.0_real64
    real(real64)::rain_input=0.0_real64
    real(real64)::irrigation_input=0.0_real64
    real(real64)::bottom_input=0.0_real64
    real(real64)::bottom_output=0.0_real64
    real(real64)::drainage_input=0.0_real64
    real(real64)::drainage_output=0.0_real64
    real(real64)::root_output=0.0_real64
    real(real64)::decay_output=0.0_real64
    real(real64)::mass_before=0.0_real64
    real(real64)::mass_after=0.0_real64
    real(real64)::balance_residual=0.0_real64
    type(b111_pond_solute_result_t)::pond
  end type

  public::advance_b111_reactive_solute_substep

contains

  subroutine advance_b111_reactive_solute_substep(committed_mobile,committed_companion,dz,theta,q,root,qdra, &
       rain_rate,rain_c,irrigation_rate,irrigation_c,pond_end,bottom_c,drain_c,tscf, &
       temperature_active,tsoil,gampar,rtheta,bexp,decpot,fdepth,bdens,kf,cref,frexp,dt,physics, &
       candidate_mobile,candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    real(real64),intent(in)::dz(:),theta(:),q(:),root(:),qdra(:,:)
    real(real64),intent(in)::rain_rate,rain_c,irrigation_rate,irrigation_c,pond_end,bottom_c,drain_c,tscf
    logical,intent(in)::temperature_active
    real(real64),intent(in)::tsoil(:),gampar(:),rtheta(:),bexp(:),decpot(:),fdepth(:),bdens(:),kf(:),cref,frexp,dt
    type(b111_reactive_dispersion_t),intent(in)::physics
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(b111_reactive_substep_receipt_t),intent(out)::receipt

    real(real64),allocatable::c(:)
    real(real64)::cfluxt,cfluxb,cmlav,thetav,vpore,diffus,dispr
    real(real64)::total_density,new_total_density,crot,cdrtot,decayed_density
    real(real64)::expected,scale,tol,rate
    integer::n,i,level
    type(b111_decay_result_t)::decay
    type(b111_sorption_result_t)::partition

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=b111_reactive_substep_receipt_t()
    if(.not.committed_companion%valid())return
    if(.not.allocated(committed_mobile%mass_mg_cm2).or..not.allocated(committed_mobile%concentration_mg_cm3))return
    n=size(committed_mobile%mass_mg_cm2)
    if(n<1.or.size(committed_mobile%concentration_mg_cm3)/=n.or.size(committed_companion%sorbed_matrix_mass)/=n)return
    if(size(dz)/=n.or.size(theta)/=n.or.size(q)/=n+1.or.size(root)/=n.or.size(qdra,2)/=n)return
    if(size(tsoil)/=n.or.size(gampar)/=n.or.size(rtheta)/=n.or.size(bexp)/=n.or.size(decpot)/=n.or. &
       size(fdepth)/=n.or.size(bdens)/=n.or.size(kf)/=n.or..not.physics_valid(physics,n))return
    if(.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(theta)).or..not.all(ieee_is_finite(q)).or. &
       .not.all(ieee_is_finite(root)).or..not.all(ieee_is_finite(qdra)).or. &
       .not.all(ieee_is_finite([rain_rate,rain_c,irrigation_rate,irrigation_c,pond_end,bottom_c,drain_c,tscf,cref,frexp,dt])))return
    if(any(dz<=0.0_real64).or.any(theta<=0.0_real64).or.any(root<0.0_real64).or. &
       min(rain_rate,rain_c,irrigation_rate,irrigation_c,pond_end,bottom_c,drain_c,tscf)<0.0_real64.or. &
       cref<=0.0_real64.or.frexp<=0.0_real64.or.dt<=0.0_real64)return

    allocate(c(n))
    c=committed_mobile%mass_mg_cm2/(theta*dz)
    scale=max(1.0_real64,maxval(abs(c)),maxval(abs(committed_mobile%concentration_mg_cm3)))
    tol=2048.0_real64*epsilon(1.0_real64)*scale
    if(any(abs(c-committed_mobile%concentration_mg_cm3)>tol))return

    receipt%mass_before=sum(committed_mobile%mass_mg_cm2)+committed_companion%solute_total()
    call evaluate_b111_pond_solute_exchange(committed_companion%pond_mass,rain_rate,rain_c, &
         irrigation_rate,irrigation_c,q(1),0.0_real64,pond_end,dt,receipt%pond)
    if(receipt%pond%status/=B111_POND_SOL_OK)return
    candidate_companion%pond_mass=receipt%pond%mass_after
    receipt%rain_input=receipt%pond%rain_input
    receipt%irrigation_input=receipt%pond%irrigation_input
    cfluxt=-receipt%pond%soil_transfer

    do i=1,n
      if(i<n)then
        thetav=physics%face_left_weight(i)*theta(i)+physics%face_right_weight(i)*theta(i+1)
        if(thetav<=0.0_real64)return
        cmlav=physics%face_left_weight(i)*c(i)+physics%face_right_weight(i)*c(i+1)
        vpore=abs(q(i+1))/thetav
        diffus=physics%molecular_diffusion_cm2_day*thetav**2.33_real64/physics%theta_sat_left(i)**2
        dispr=diffus+physics%dispersivity_cm(i)*vpore+0.5_real64*dt*vpore*vpore
        cfluxb=(q(i+1)*cmlav+thetav*dispr*(c(i+1)-c(i))/physics%face_distance_cm(i))*dt
      else
        if(q(i+1)>0.0_real64)then
          cfluxb=q(i+1)*bottom_c*dt
          receipt%bottom_input=receipt%bottom_input+cfluxb
        else
          cfluxb=q(i+1)*c(i)*dt
          receipt%bottom_output=receipt%bottom_output-cfluxb
        end if
      end if

      total_density=(candidate_mobile%mass_mg_cm2(i)+candidate_companion%sorbed_matrix_mass(i))/dz(i)
      call evaluate_b111_solute_decay(temperature_active,tsoil(i),gampar(i),theta(i),rtheta(i),bexp(i), &
           decpot(i),fdepth(i),total_density,decay)
      if(decay%status/=B111_DECAY_OK)return
      decayed_density=decay%transformation_density_rate
      crot=tscf*root(i)*c(i)/dz(i)
      cdrtot=0.0_real64
      do level=1,size(qdra,1)
        if(qdra(level,i)>0.0_real64)then
          rate=qdra(level,i)*c(i)/dz(i)
          receipt%drainage_output=receipt%drainage_output+rate*dz(i)*dt
        else
          rate=qdra(level,i)*drain_c/dz(i)
          receipt%drainage_input=receipt%drainage_input-rate*dz(i)*dt
        end if
        cdrtot=cdrtot+rate
      end do
      receipt%root_output=receipt%root_output+tscf*root(i)*c(i)*dt
      receipt%decay_output=receipt%decay_output+decayed_density*dt*dz(i)

      new_total_density=total_density+(cfluxb-cfluxt)/dz(i)+(-decayed_density-crot-cdrtot)*dt
      if(new_total_density<0.0_real64)then
        candidate_mobile=committed_mobile;candidate_companion=committed_companion
        receipt%status=B111_REACTIVE_NEGATIVE
        return
      end if
      call b111_sorption_partition_total(theta(i),bdens(i),kf(i),cref,frexp,new_total_density,c(i),partition)
      if(partition%status/=B111_SORP_OK)then
        candidate_mobile=committed_mobile;candidate_companion=committed_companion
        receipt%status=B111_REACTIVE_PARTITION_FAILED
        return
      end if
      candidate_mobile%mass_mg_cm2(i)=partition%dissolved_density*dz(i)
      candidate_companion%sorbed_matrix_mass(i)=partition%sorbed_density*dz(i)
      candidate_mobile%concentration_mg_cm3(i)=partition%concentration
      c(i)=partition%concentration
      cfluxt=cfluxb
    end do

    receipt%external_input=receipt%rain_input+receipt%irrigation_input+receipt%bottom_input+receipt%drainage_input
    receipt%external_output=receipt%bottom_output+receipt%drainage_output+receipt%root_output+receipt%decay_output
    receipt%mass_after=sum(candidate_mobile%mass_mg_cm2)+candidate_companion%solute_total()
    expected=receipt%mass_before+receipt%external_input-receipt%external_output
    receipt%balance_residual=receipt%mass_after-expected
    scale=max(1.0_real64,abs(receipt%mass_before),abs(receipt%mass_after),abs(expected))
    tol=8192.0_real64*epsilon(1.0_real64)*scale
    if(.not.candidate_companion%valid().or.any(candidate_mobile%mass_mg_cm2<0.0_real64).or. &
       .not.all(ieee_is_finite(candidate_mobile%concentration_mg_cm3)).or.abs(receipt%balance_residual)>tol)then
      candidate_mobile=committed_mobile;candidate_companion=committed_companion
      receipt%status=B111_REACTIVE_BALANCE
      return
    end if
    receipt%status=B111_REACTIVE_OK
  end subroutine

  pure logical function physics_valid(p,n) result(ok)
    type(b111_reactive_dispersion_t),intent(in)::p
    integer,intent(in)::n
    ok=.false.
    if(n<1.or..not.ieee_is_finite(p%molecular_diffusion_cm2_day).or.p%molecular_diffusion_cm2_day<0.0_real64)return
    if(.not.allocated(p%dispersivity_cm).or..not.allocated(p%theta_sat_left).or. &
       .not.allocated(p%face_distance_cm).or..not.allocated(p%face_left_weight).or..not.allocated(p%face_right_weight))return
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
