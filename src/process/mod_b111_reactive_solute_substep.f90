module mod_b111_reactive_solute_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_solute_sorption, only: b111_sorption_result_t, b111_sorption_storage_from_concentration, &
       b111_sorption_partition_total, B111_SORP_OK
  use mod_b111_solute_decay, only: b111_decay_result_t,evaluate_b111_solute_decay,B111_DECAY_OK
  use mod_b111_pond_solute_exchange, only: b111_pond_solute_result_t,evaluate_b111_pond_solute_exchange, &
       B111_POND_SOL_OK
  implicit none
  private

  integer,parameter,public::B111_REACTIVE_OK=0
  integer,parameter,public::B111_REACTIVE_INVALID=1
  integer,parameter,public::B111_REACTIVE_STATE_MISMATCH=2
  integer,parameter,public::B111_REACTIVE_NEGATIVE=3
  integer,parameter,public::B111_REACTIVE_PARTITION=4
  integer,parameter,public::B111_REACTIVE_BALANCE=5

  type,public::b111_reactive_solute_substep_forcing_t
    real(real64)::dt_day=0.0_real64
    real(real64),allocatable::theta(:)
    real(real64),allocatable::dz_cm(:)
    real(real64),allocatable::q_face_up_cm_day(:)
    real(real64),allocatable::root_sink_cm_day(:)
    real(real64),allocatable::qdra_cm_day(:,:)
    real(real64)::cdrain_mg_cm3=0.0_real64
    real(real64)::cseep_mg_cm3=0.0_real64
    real(real64)::tscf=0.0_real64
    real(real64)::rain_rate_cm_day=0.0_real64
    real(real64)::rain_c_mg_cm3=0.0_real64
    real(real64)::irrigation_rate_cm_day=0.0_real64
    real(real64)::irrigation_c_mg_cm3=0.0_real64
    real(real64)::macropore_area_fraction=0.0_real64
    real(real64)::pond_end_cm=0.0_real64
    real(real64),allocatable::face_left_weight(:)
    real(real64),allocatable::face_right_weight(:)
    real(real64),allocatable::face_distance_cm(:)
    real(real64),allocatable::theta_sat_left(:)
    real(real64),allocatable::dispersivity_cm(:)
    real(real64)::molecular_diffusion_cm2_day=0.0_real64
    logical::temperature_active=.false.
    real(real64),allocatable::temperature_c(:)
    real(real64),allocatable::gampar(:)
    real(real64),allocatable::rtheta(:)
    real(real64),allocatable::bexp(:)
    real(real64),allocatable::decpot(:)
    real(real64),allocatable::fdepth(:)
    real(real64),allocatable::bulk_density(:)
    real(real64),allocatable::kf(:)
    real(real64)::cref_mg_cm3=1.0_real64
    real(real64)::frexp=1.0_real64
  end type

  type,public::b111_reactive_solute_substep_receipt_t
    integer::status=B111_REACTIVE_INVALID
    real(real64)::external_input_mg_cm2=0.0_real64
    real(real64)::external_output_mg_cm2=0.0_real64
    real(real64)::decay_output_mg_cm2=0.0_real64
    real(real64)::root_output_mg_cm2=0.0_real64
    real(real64)::drain_output_mg_cm2=0.0_real64
    real(real64)::drain_input_mg_cm2=0.0_real64
    real(real64)::bottom_output_mg_cm2=0.0_real64
    real(real64)::bottom_input_mg_cm2=0.0_real64
    real(real64)::pond_to_soil_mg_cm2=0.0_real64
    real(real64)::mass_before_mg_cm2=0.0_real64
    real(real64)::mass_after_mg_cm2=0.0_real64
    real(real64)::balance_residual_mg_cm2=0.0_real64
  end type

  public::advance_b111_reactive_solute_substep

contains

  subroutine advance_b111_reactive_solute_substep(committed_mobile,committed_companion,f,candidate_mobile, &
       candidate_companion,receipt)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    type(b111_reactive_solute_substep_forcing_t),intent(in)::f
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(b111_reactive_solute_substep_receipt_t),intent(out)::receipt

    type(b111_pond_solute_result_t)::pond
    type(b111_sorption_result_t)::sorp,partition
    type(b111_decay_result_t)::decay
    real(real64)::cfluxt,cfluxb,cmlav,thetav,diffus,vpore,dispr,ctrans,crot,cdrtot
    real(real64)::total_density,new_density,expected_sorbed,scale,tol,q,mass
    integer::i,level,n,nlev

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=b111_reactive_solute_substep_receipt_t()
    if(.not.valid_forcing(f))return
    if(.not.mobile_valid(committed_mobile).or..not.committed_companion%valid())return
    n=size(f%theta);nlev=size(f%qdra_cm_day,1)
    if(size(committed_mobile%mass_mg_cm2)/=n.or.size(committed_companion%sorbed_matrix_mass)/=n)return
    if(size(committed_companion%age_amount)/=n)return

    ! Persisted reactive state must be on the same Freundlich equilibrium
    ! manifold as the concentration used by the source flux equations.
    do i=1,n
      call b111_sorption_storage_from_concentration(f%theta(i),f%bulk_density(i),f%kf(i), &
           f%cref_mg_cm3,f%frexp,committed_mobile%concentration_mg_cm3(i),sorp)
      if(sorp%status/=B111_SORP_OK)return
      expected_sorbed=sorp%sorbed_density*f%dz_cm(i)
      scale=max(1.0_real64,abs(expected_sorbed),abs(committed_companion%sorbed_matrix_mass(i)))
      tol=2048.0_real64*epsilon(1.0_real64)*scale
      if(abs(expected_sorbed-committed_companion%sorbed_matrix_mass(i))>tol)then
        receipt%status=B111_REACTIVE_STATE_MISMATCH
        return
      end if
      scale=max(1.0_real64,abs(sorp%dissolved_density*f%dz_cm(i)),abs(committed_mobile%mass_mg_cm2(i)))
      tol=2048.0_real64*epsilon(1.0_real64)*scale
      if(abs(sorp%dissolved_density*f%dz_cm(i)-committed_mobile%mass_mg_cm2(i))>tol)then
        receipt%status=B111_REACTIVE_STATE_MISMATCH
        return
      end if
    end do

    receipt%mass_before_mg_cm2=sum(committed_mobile%mass_mg_cm2)+committed_companion%solute_total()
    call evaluate_b111_pond_solute_exchange(committed_companion%pond_mass,f%rain_rate_cm_day,f%rain_c_mg_cm3, &
         f%irrigation_rate_cm_day,f%irrigation_c_mg_cm3,f%q_face_up_cm_day(1),f%macropore_area_fraction, &
         f%pond_end_cm,f%dt_day,pond)
    if(pond%status/=B111_POND_SOL_OK)return
    candidate_companion%pond_mass=pond%mass_after
    receipt%pond_to_soil_mg_cm2=pond%soil_transfer
    receipt%external_input_mg_cm2=pond%rain_input+pond%irrigation_input
    cfluxt=-pond%soil_transfer

    do i=1,n
      if(i<n)then
        cmlav=f%face_left_weight(i)*candidate_mobile%concentration_mg_cm3(i)+ &
             f%face_right_weight(i)*candidate_mobile%concentration_mg_cm3(i+1)
        thetav=f%face_left_weight(i)*f%theta(i)+f%face_right_weight(i)*f%theta(i+1)
        if(thetav<=0.0_real64)return
        vpore=abs(f%q_face_up_cm_day(i+1))/thetav
        diffus=f%molecular_diffusion_cm2_day*(thetav**2.33_real64)/(f%theta_sat_left(i)**2)
        dispr=diffus+f%dispersivity_cm(i)*vpore+0.5_real64*f%dt_day*vpore*vpore
        cfluxb=(f%q_face_up_cm_day(i+1)*cmlav+thetav*dispr* &
             (candidate_mobile%concentration_mg_cm3(i+1)-candidate_mobile%concentration_mg_cm3(i))/ &
             f%face_distance_cm(i))*f%dt_day
      else
        q=f%q_face_up_cm_day(n+1)
        if(q>0.0_real64)then
          cfluxb=q*f%cseep_mg_cm3*f%dt_day
          receipt%bottom_input_mg_cm2=receipt%bottom_input_mg_cm2+cfluxb
        else
          cfluxb=q*candidate_mobile%concentration_mg_cm3(i)*f%dt_day
          receipt%bottom_output_mg_cm2=receipt%bottom_output_mg_cm2-cfluxb
        end if
      end if

      total_density=(candidate_mobile%mass_mg_cm2(i)+candidate_companion%sorbed_matrix_mass(i))/f%dz_cm(i)
      call evaluate_b111_solute_decay(f%temperature_active,f%temperature_c(i),f%gampar(i),f%theta(i), &
           f%rtheta(i),f%bexp(i),f%decpot(i),f%fdepth(i),total_density,decay)
      if(decay%status/=B111_DECAY_OK)return
      ctrans=decay%transformation_density_rate
      receipt%decay_output_mg_cm2=receipt%decay_output_mg_cm2+ctrans*f%dt_day*f%dz_cm(i)

      crot=f%tscf*f%root_sink_cm_day(i)*candidate_mobile%concentration_mg_cm3(i)/f%dz_cm(i)
      receipt%root_output_mg_cm2=receipt%root_output_mg_cm2+ &
           f%tscf*f%root_sink_cm_day(i)*candidate_mobile%concentration_mg_cm3(i)*f%dt_day

      cdrtot=0.0_real64
      do level=1,nlev
        q=f%qdra_cm_day(level,i)
        if(q>0.0_real64)then
          cdrtot=cdrtot+q*candidate_mobile%concentration_mg_cm3(i)/f%dz_cm(i)
          receipt%drain_output_mg_cm2=receipt%drain_output_mg_cm2+ &
               q*candidate_mobile%concentration_mg_cm3(i)*f%dt_day
        else
          cdrtot=cdrtot+q*f%cdrain_mg_cm3/f%dz_cm(i)
          receipt%drain_input_mg_cm2=receipt%drain_input_mg_cm2-q*f%cdrain_mg_cm3*f%dt_day
        end if
      end do

      new_density=total_density+(cfluxb-cfluxt)/f%dz_cm(i)+(-ctrans-crot-cdrtot)*f%dt_day
      if(new_density<0.0_real64)then
        scale=max(1.0_real64,abs(total_density),abs((cfluxb-cfluxt)/f%dz_cm(i)))
        tol=2048.0_real64*epsilon(1.0_real64)*scale
        if(new_density< -tol)then
          candidate_mobile=committed_mobile;candidate_companion=committed_companion
          receipt%status=B111_REACTIVE_NEGATIVE;return
        end if
        new_density=0.0_real64
      end if

      call b111_sorption_partition_total(f%theta(i),f%bulk_density(i),f%kf(i),f%cref_mg_cm3,f%frexp, &
           new_density,candidate_mobile%concentration_mg_cm3(i),partition)
      if(partition%status/=B111_SORP_OK)then
        candidate_mobile=committed_mobile;candidate_companion=committed_companion
        receipt%status=B111_REACTIVE_PARTITION;return
      end if
      candidate_mobile%mass_mg_cm2(i)=partition%dissolved_density*f%dz_cm(i)
      candidate_companion%sorbed_matrix_mass(i)=partition%sorbed_density*f%dz_cm(i)
      candidate_mobile%concentration_mg_cm3(i)=partition%concentration
      cfluxt=cfluxb
    end do

    receipt%external_input_mg_cm2=receipt%external_input_mg_cm2+receipt%bottom_input_mg_cm2+receipt%drain_input_mg_cm2
    receipt%external_output_mg_cm2=receipt%decay_output_mg_cm2+receipt%root_output_mg_cm2+ &
         receipt%drain_output_mg_cm2+receipt%bottom_output_mg_cm2
    receipt%mass_after_mg_cm2=sum(candidate_mobile%mass_mg_cm2)+candidate_companion%solute_total()
    receipt%balance_residual_mg_cm2=receipt%mass_after_mg_cm2-receipt%mass_before_mg_cm2- &
         receipt%external_input_mg_cm2+receipt%external_output_mg_cm2
    scale=max(1.0_real64,abs(receipt%mass_before_mg_cm2),abs(receipt%mass_after_mg_cm2), &
         receipt%external_input_mg_cm2,receipt%external_output_mg_cm2)
    tol=8192.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual_mg_cm2)>tol)then
      candidate_mobile=committed_mobile;candidate_companion=committed_companion
      receipt%status=B111_REACTIVE_BALANCE;return
    end if
    receipt%status=B111_REACTIVE_OK
  end subroutine

  logical function mobile_valid(s) result(ok)
    type(mobile_salt_state_t),intent(in)::s
    ok=.false.
    if(.not.allocated(s%mass_mg_cm2).or..not.allocated(s%concentration_mg_cm3))return
    if(size(s%mass_mg_cm2)<1.or.size(s%concentration_mg_cm3)/=size(s%mass_mg_cm2))return
    ok=all(ieee_is_finite(s%mass_mg_cm2)).and.all(ieee_is_finite(s%concentration_mg_cm3)).and. &
       all(s%mass_mg_cm2>=0.0_real64).and.all(s%concentration_mg_cm3>=0.0_real64)
  end function

  logical function valid_forcing(f) result(ok)
    type(b111_reactive_solute_substep_forcing_t),intent(in)::f
    integer::n
    ok=.false.
    if(.not.allocated(f%theta).or..not.allocated(f%dz_cm).or..not.allocated(f%q_face_up_cm_day).or. &
       .not.allocated(f%root_sink_cm_day).or..not.allocated(f%qdra_cm_day))return
    n=size(f%theta)
    if(n<1.or.size(f%dz_cm)/=n.or.size(f%q_face_up_cm_day)/=n+1.or.size(f%root_sink_cm_day)/=n.or. &
       size(f%qdra_cm_day,2)/=n)return
    if(.not.allocated(f%temperature_c).or..not.allocated(f%gampar).or..not.allocated(f%rtheta).or. &
       .not.allocated(f%bexp).or..not.allocated(f%decpot).or..not.allocated(f%fdepth).or. &
       .not.allocated(f%bulk_density).or..not.allocated(f%kf))return
    if(any([size(f%temperature_c),size(f%gampar),size(f%rtheta),size(f%bexp),size(f%decpot), &
       size(f%fdepth),size(f%bulk_density),size(f%kf)]/=n))return
    if(n>1)then
      if(.not.allocated(f%face_left_weight).or..not.allocated(f%face_right_weight).or. &
         .not.allocated(f%face_distance_cm).or..not.allocated(f%theta_sat_left).or. &
         .not.allocated(f%dispersivity_cm))return
      if(any([size(f%face_left_weight),size(f%face_right_weight),size(f%face_distance_cm), &
         size(f%theta_sat_left),size(f%dispersivity_cm)]/=n-1))return
    end if
    if(.not.all(ieee_is_finite(f%theta)).or..not.all(ieee_is_finite(f%dz_cm)).or. &
       .not.all(ieee_is_finite(f%q_face_up_cm_day)).or..not.all(ieee_is_finite(f%root_sink_cm_day)).or. &
       .not.all(ieee_is_finite(f%qdra_cm_day)))return
    if(.not.all(ieee_is_finite(f%temperature_c)).or..not.all(ieee_is_finite(f%gampar)).or. &
       .not.all(ieee_is_finite(f%rtheta)).or..not.all(ieee_is_finite(f%bexp)).or. &
       .not.all(ieee_is_finite(f%decpot)).or..not.all(ieee_is_finite(f%fdepth)).or. &
       .not.all(ieee_is_finite(f%bulk_density)).or..not.all(ieee_is_finite(f%kf)))return
    if(.not.all(ieee_is_finite([f%dt_day,f%cdrain_mg_cm3,f%cseep_mg_cm3,f%tscf, &
       f%rain_rate_cm_day,f%rain_c_mg_cm3,f%irrigation_rate_cm_day,f%irrigation_c_mg_cm3, &
       f%macropore_area_fraction,f%pond_end_cm,f%molecular_diffusion_cm2_day,f%cref_mg_cm3,f%frexp])))return
    if(f%dt_day<=0.0_real64.or.any(f%theta<=0.0_real64).or.any(f%dz_cm<=0.0_real64).or. &
       any(f%root_sink_cm_day<0.0_real64).or.any(f%rtheta<=0.0_real64).or.any(f%bexp<0.0_real64).or. &
       any(f%decpot<0.0_real64).or.any(f%fdepth<0.0_real64).or.any(f%bulk_density<0.0_real64).or. &
       any(f%kf<0.0_real64).or.min(f%cdrain_mg_cm3,f%cseep_mg_cm3,f%tscf,f%rain_rate_cm_day, &
       f%rain_c_mg_cm3,f%irrigation_rate_cm_day,f%irrigation_c_mg_cm3,f%pond_end_cm, &
       f%molecular_diffusion_cm2_day,f%cref_mg_cm3,f%frexp)<0.0_real64)return
    if(f%tscf>10.0_real64.or.f%macropore_area_fraction<0.0_real64.or.f%macropore_area_fraction>1.0_real64)return
    if(n>1)then
      if(.not.all(ieee_is_finite(f%face_left_weight)).or..not.all(ieee_is_finite(f%face_right_weight)).or. &
         .not.all(ieee_is_finite(f%face_distance_cm)).or..not.all(ieee_is_finite(f%theta_sat_left)).or. &
         .not.all(ieee_is_finite(f%dispersivity_cm)))return
      if(any(f%face_left_weight<0.0_real64).or.any(f%face_right_weight<0.0_real64).or. &
         any(f%face_distance_cm<=0.0_real64).or.any(f%theta_sat_left<=0.0_real64).or. &
         any(f%dispersivity_cm<0.0_real64))return
    end if
    ok=.true.
  end function
end module
