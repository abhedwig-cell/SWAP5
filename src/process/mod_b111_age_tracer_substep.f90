module mod_b111_age_tracer_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_compartment_state, only: solute_compartment_state_t
  implicit none
  private

  integer,parameter,public::B111_AGE_SUBSTEP_OK=0
  integer,parameter,public::B111_AGE_SUBSTEP_INVALID=1
  integer,parameter,public::B111_AGE_SUBSTEP_NEGATIVE=2
  integer,parameter,public::B111_AGE_SUBSTEP_BALANCE=3

  type,public::b111_age_tracer_substep_forcing_t
    real(real64)::dt_day=0.0_real64
    real(real64),allocatable::theta(:)
    real(real64),allocatable::theta_previous(:)
    real(real64),allocatable::dz_cm(:)
    real(real64),allocatable::q_face_up_cm_day(:)
    real(real64),allocatable::root_sink_cm_day(:)
    real(real64),allocatable::qdra_cm_day(:,:)
    real(real64)::drain_age_day=0.0_real64
    real(real64)::rain_rate_cm_day=0.0_real64
    real(real64)::rain_age_day=0.0_real64
    real(real64)::irrigation_rate_cm_day=0.0_real64
    real(real64)::irrigation_age_day=0.0_real64
    real(real64)::pond_previous_cm=0.0_real64
    real(real64)::pond_end_cm=0.0_real64
    real(real64)::macropore_area_fraction=0.0_real64
    real(real64),allocatable::face_left_weight(:)
    real(real64),allocatable::face_right_weight(:)
    real(real64),allocatable::face_distance_cm(:)
    real(real64),allocatable::theta_sat_left(:)
    real(real64),allocatable::dispersivity_cm(:)
    real(real64)::molecular_diffusion_cm2_day=0.0_real64
  end type

  type,public::b111_age_tracer_substep_receipt_t
    integer::status=B111_AGE_SUBSTEP_INVALID
    real(real64)::production_amount_cm_day=0.0_real64
    real(real64)::root_export_cm_day=0.0_real64
    real(real64)::drain_export_cm_day=0.0_real64
    real(real64)::drain_input_cm_day=0.0_real64
    real(real64)::bottom_export_cm_day=0.0_real64
    real(real64)::bottom_input_cm_day=0.0_real64
    real(real64)::pond_to_soil_cm_day=0.0_real64
    real(real64)::age_before_cm_day=0.0_real64
    real(real64)::age_after_cm_day=0.0_real64
    real(real64)::balance_residual_cm_day=0.0_real64
    real(real64)::pond_age_end_day=0.0_real64
  end type

  public::advance_b111_age_tracer_substep

contains

  subroutine advance_b111_age_tracer_substep(committed,f,candidate,receipt)
    type(solute_compartment_state_t),intent(in)::committed
    type(b111_age_tracer_substep_forcing_t),intent(in)::f
    type(solute_compartment_state_t),intent(out)::candidate
    type(b111_age_tracer_substep_receipt_t),intent(out)::receipt
    real(real64),allocatable::age_c(:)
    real(real64)::agesurf,agepond,agefluxt,agefluxb,agemlav,thetav,vpore,diffus,dispr
    real(real64)::agerot,agedrtot,ageprod,q,new_amount,scale,tol
    integer::i,level,n,nlev

    candidate=committed
    receipt=b111_age_tracer_substep_receipt_t()
    if(.not.committed%valid().or..not.valid_forcing(f))return
    n=size(f%theta);nlev=size(f%qdra_cm_day,1)
    if(size(committed%age_amount)/=n)return
    allocate(age_c(n))
    age_c=committed%age_amount/(f%theta_previous*f%dz_cm)
    if(.not.all(ieee_is_finite(age_c)).or.any(age_c<0.0_real64))return

    receipt%age_before_cm_day=sum(committed%age_amount)
    agesurf=(f%irrigation_rate_cm_day*f%irrigation_age_day+f%rain_rate_cm_day*f%rain_age_day)*f%dt_day + &
         f%pond_previous_cm*committed%age_pond_previous_concentration
    agepond=0.0_real64
    agefluxt=0.0_real64
    if(f%q_face_up_cm_day(1)<-1.0e-6_real64)then
      if(f%pond_end_cm-f%q_face_up_cm_day(1)*f%dt_day<=0.0_real64)return
      agepond=agesurf/(f%pond_end_cm-f%q_face_up_cm_day(1)*f%dt_day)
      agefluxt=f%q_face_up_cm_day(1)*(1.0_real64-f%macropore_area_fraction)*agepond*f%dt_day
      agesurf=agesurf+agefluxt
      receipt%pond_to_soil_cm_day=-agefluxt
    end if

    do i=1,n
      if(i<n)then
        agemlav=f%face_left_weight(i)*age_c(i)+f%face_right_weight(i)*age_c(i+1)
        thetav=f%face_left_weight(i)*f%theta(i)+f%face_right_weight(i)*f%theta(i+1)
        if(thetav<=0.0_real64)return
        vpore=abs(f%q_face_up_cm_day(i+1))/thetav
        diffus=f%molecular_diffusion_cm2_day*(thetav**2.33_real64)/(f%theta_sat_left(i)**2)
        dispr=diffus+f%dispersivity_cm(i)*vpore+0.5_real64*f%dt_day*vpore*vpore
        agefluxb=(f%q_face_up_cm_day(i+1)*agemlav+thetav*dispr*(age_c(i+1)-age_c(i))/ &
             f%face_distance_cm(i))*f%dt_day
      else
        q=f%q_face_up_cm_day(n+1)
        if(q>0.0_real64)then
          agefluxb=q*f%drain_age_day*f%dt_day
          receipt%bottom_input_cm_day=receipt%bottom_input_cm_day+agefluxb
        else
          agefluxb=q*age_c(i)*f%dt_day
          receipt%bottom_export_cm_day=receipt%bottom_export_cm_day-agefluxb
        end if
      end if

      agerot=f%root_sink_cm_day(i)*age_c(i)/f%dz_cm(i)
      receipt%root_export_cm_day=receipt%root_export_cm_day+f%root_sink_cm_day(i)*age_c(i)*f%dt_day

      agedrtot=0.0_real64
      do level=1,nlev
        q=f%qdra_cm_day(level,i)
        if(q>0.0_real64)then
          agedrtot=agedrtot+q*age_c(i)/f%dz_cm(i)
          receipt%drain_export_cm_day=receipt%drain_export_cm_day+q*age_c(i)*f%dt_day
        else
          agedrtot=agedrtot+q*f%drain_age_day/f%dz_cm(i)
          receipt%drain_input_cm_day=receipt%drain_input_cm_day-q*f%drain_age_day*f%dt_day
        end if
      end do

      ageprod=0.5_real64*(f%theta(i)+f%theta_previous(i))
      receipt%production_amount_cm_day=receipt%production_amount_cm_day+ageprod*f%dt_day*f%dz_cm(i)
      new_amount=committed%age_amount(i)+(agefluxb-agefluxt)+(-agerot-agedrtot+ageprod)*f%dt_day*f%dz_cm(i)
      if(new_amount<0.0_real64)then
        scale=max(1.0_real64,abs(committed%age_amount(i)),abs(agefluxb),abs(agefluxt))
        tol=4096.0_real64*epsilon(1.0_real64)*scale
        if(new_amount< -tol)then
          candidate=committed;receipt%status=B111_AGE_SUBSTEP_NEGATIVE;return
        end if
        new_amount=0.0_real64
      end if
      candidate%age_amount(i)=new_amount
      age_c(i)=new_amount/(f%theta(i)*f%dz_cm(i))
      agefluxt=agefluxb
    end do

    candidate%age_pond_previous_concentration=agepond
    if(.not.candidate%valid())then
      candidate=committed;return
    end if
    receipt%pond_age_end_day=agepond
    receipt%age_after_cm_day=sum(candidate%age_amount)
    receipt%balance_residual_cm_day=receipt%age_after_cm_day-receipt%age_before_cm_day- &
         receipt%production_amount_cm_day-receipt%drain_input_cm_day-receipt%bottom_input_cm_day+ &
         receipt%root_export_cm_day+receipt%drain_export_cm_day+receipt%bottom_export_cm_day-receipt%pond_to_soil_cm_day
    ! pond_to_soil is internal to the combined soil+pond-age system, but the
    ! persisted age owner does not store pond age amount separately. Source
    ! continuation is the concentration Agepondm1 plus accepted pond water.
    scale=max(1.0_real64,abs(receipt%age_before_cm_day),abs(receipt%age_after_cm_day), &
         receipt%production_amount_cm_day,receipt%pond_to_soil_cm_day)
    tol=8192.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual_cm_day)>tol)then
      candidate=committed;receipt%status=B111_AGE_SUBSTEP_BALANCE;return
    end if
    receipt%status=B111_AGE_SUBSTEP_OK
  end subroutine

  logical function valid_forcing(f) result(ok)
    type(b111_age_tracer_substep_forcing_t),intent(in)::f
    integer::n
    ok=.false.
    if(.not.allocated(f%theta).or..not.allocated(f%theta_previous).or..not.allocated(f%dz_cm).or. &
       .not.allocated(f%q_face_up_cm_day).or..not.allocated(f%root_sink_cm_day).or..not.allocated(f%qdra_cm_day))return
    n=size(f%theta)
    if(n<1.or.size(f%theta_previous)/=n.or.size(f%dz_cm)/=n.or.size(f%q_face_up_cm_day)/=n+1.or. &
       size(f%root_sink_cm_day)/=n.or.size(f%qdra_cm_day,2)/=n)return
    if(.not.all(ieee_is_finite(f%theta)).or..not.all(ieee_is_finite(f%theta_previous)).or. &
       .not.all(ieee_is_finite(f%dz_cm)).or..not.all(ieee_is_finite(f%q_face_up_cm_day)).or. &
       .not.all(ieee_is_finite(f%root_sink_cm_day)).or..not.all(ieee_is_finite(f%qdra_cm_day)))return
    if(.not.all(ieee_is_finite([f%dt_day,f%drain_age_day,f%rain_rate_cm_day,f%rain_age_day, &
       f%irrigation_rate_cm_day,f%irrigation_age_day,f%pond_previous_cm,f%pond_end_cm, &
       f%macropore_area_fraction,f%molecular_diffusion_cm2_day])))return
    if(f%dt_day<=0.0_real64.or.any(f%theta<=0.0_real64).or.any(f%theta_previous<=0.0_real64).or. &
       any(f%dz_cm<=0.0_real64).or.any(f%root_sink_cm_day<0.0_real64).or. &
       min(f%drain_age_day,f%rain_rate_cm_day,f%rain_age_day,f%irrigation_rate_cm_day,f%irrigation_age_day, &
       f%pond_previous_cm,f%pond_end_cm,f%molecular_diffusion_cm2_day)<0.0_real64)return
    if(f%macropore_area_fraction<0.0_real64.or.f%macropore_area_fraction>1.0_real64)return
    if(n>1)then
      if(.not.allocated(f%face_left_weight).or..not.allocated(f%face_right_weight).or. &
         .not.allocated(f%face_distance_cm).or..not.allocated(f%theta_sat_left).or..not.allocated(f%dispersivity_cm))return
      if(any([size(f%face_left_weight),size(f%face_right_weight),size(f%face_distance_cm), &
         size(f%theta_sat_left),size(f%dispersivity_cm)]/=n-1))return
      if(.not.all(ieee_is_finite(f%face_left_weight)).or..not.all(ieee_is_finite(f%face_right_weight)).or. &
         .not.all(ieee_is_finite(f%face_distance_cm)).or..not.all(ieee_is_finite(f%theta_sat_left)).or. &
         .not.all(ieee_is_finite(f%dispersivity_cm)))return
      if(any(f%face_left_weight<0.0_real64).or.any(f%face_right_weight<0.0_real64).or. &
         any(f%face_distance_cm<=0.0_real64).or.any(f%theta_sat_left<=0.0_real64).or.any(f%dispersivity_cm<0.0_real64))return
    end if
    ok=.true.
  end function
end module
