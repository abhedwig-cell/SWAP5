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
  integer,parameter,public::B111_REACTIVE_NOCONV=6
  integer,parameter,public::B111_TRANSPORT_REFERENCE=0,B111_TRANSPORT_IMPLICIT_UPWIND=1

  type,public::b111_reactive_solute_substep_forcing_t
    integer::transport_scheme=B111_TRANSPORT_REFERENCE
    real(real64)::dt_day=0.0_real64
    real(real64),allocatable::theta(:)
    ! Begin storage coefficient; absent only for legacy fixed-water callers.
    real(real64),allocatable::theta_previous(:)
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
    real(real64)::runon_rate_cm_day=0.0_real64,runon_c_mg_cm3=0.0_real64
    real(real64)::macropore_area_fraction=0.0_real64
    real(real64)::pond_end_cm=0.0_real64
    real(real64)::runoff_depth_cm=0.0_real64
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
    real(real64)::runoff_output_mg_cm2=0.0_real64
    real(real64)::mass_before_mg_cm2=0.0_real64
    real(real64)::mass_after_mg_cm2=0.0_real64
    real(real64)::balance_residual_mg_cm2=0.0_real64
    integer::nonlinear_sweeps=0
  end type

  public::advance_b111_reactive_solute_substep, b111_reactive_forcing_valid

contains

  subroutine advance_b111_reactive_solute_substep(committed_mobile,committed_companion,f,candidate_mobile, &
       candidate_companion,receipt,exact_empty_pond_limit)
    type(mobile_salt_state_t),intent(in)::committed_mobile
    type(solute_compartment_state_t),intent(in)::committed_companion
    type(b111_reactive_solute_substep_forcing_t),intent(in)::f
    type(mobile_salt_state_t),intent(out)::candidate_mobile
    type(solute_compartment_state_t),intent(out)::candidate_companion
    type(b111_reactive_solute_substep_receipt_t),intent(out)::receipt
    logical,intent(in),optional::exact_empty_pond_limit

    type(b111_pond_solute_result_t)::pond
    type(b111_sorption_result_t)::sorp,partition
    type(b111_decay_result_t)::decay
    real(real64)::cfluxt,cfluxb,cmlav,thetav,diffus,vpore,dispr,ctrans,crot,cdrtot
    real(real64)::total_density,new_density,expected_sorbed,scale,tol,q,theta0,decay_density
    integer::i,level,n,nlev

    candidate_mobile=committed_mobile
    candidate_companion=committed_companion
    receipt=b111_reactive_solute_substep_receipt_t()
    if(.not.b111_reactive_forcing_valid(f))return
    if(.not.mobile_valid(committed_mobile).or..not.committed_companion%valid())return
    n=size(f%theta);nlev=size(f%qdra_cm_day,1)
    if(size(committed_mobile%mass_mg_cm2)/=n.or.size(committed_companion%sorbed_matrix_mass)/=n)return
    if(size(committed_companion%age_amount)/=n)return

    ! Persisted reactive state must be on the same Freundlich equilibrium
    ! manifold as the concentration used by the source flux equations.
    do i=1,n
      theta0=f%theta(i)
      if(allocated(f%theta_previous))theta0=f%theta_previous(i)
      call b111_sorption_storage_from_concentration(theta0,f%bulk_density(i),f%kf(i), &
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

    if(f%transport_scheme==B111_TRANSPORT_IMPLICIT_UPWIND)then
      call implicit_upwind(committed_mobile,committed_companion,f,candidate_mobile,candidate_companion, &
           receipt,exact_empty_pond_limit)
      return
    end if

    receipt%mass_before_mg_cm2=sum(committed_mobile%mass_mg_cm2)+committed_companion%solute_total()
    call evaluate_b111_pond_solute_exchange(committed_companion%pond_mass,f%rain_rate_cm_day,f%rain_c_mg_cm3, &
         f%irrigation_rate_cm_day,f%irrigation_c_mg_cm3,f%q_face_up_cm_day(1),f%macropore_area_fraction, &
         f%pond_end_cm,f%dt_day,pond,f%runon_rate_cm_day,f%runon_c_mg_cm3,f%runoff_depth_cm, &
         exact_empty_pond_limit=exact_empty_pond_limit)
    if(pond%status/=B111_POND_SOL_OK)return
    candidate_companion%pond_mass=pond%mass_after
    receipt%pond_to_soil_mg_cm2=pond%soil_transfer
    receipt%runoff_output_mg_cm2=pond%runoff_output
    receipt%external_input_mg_cm2=pond%rain_input+pond%irrigation_input+pond%runon_input
    cfluxt=-pond%soil_transfer

    do i=1,n
      if(i<n)then
        cmlav=f%face_left_weight(i)*candidate_mobile%concentration_mg_cm3(i)+ &
             f%face_right_weight(i)*candidate_mobile%concentration_mg_cm3(i+1)
        thetav=f%face_left_weight(i)*f%theta(i)+f%face_right_weight(i)*f%theta(i+1)
        if(thetav<=0.0_real64)then
          candidate_mobile=committed_mobile;candidate_companion=committed_companion
          return
        end if
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
      ! Historical cmsy persists across the hydraulic step; ctrans uses the
      ! NEW theta with the pre-update concentration (solute.f90:394).
      decay_density=f%theta(i)*candidate_mobile%concentration_mg_cm3(i)+ &
           candidate_companion%sorbed_matrix_mass(i)/f%dz_cm(i)
      call evaluate_b111_solute_decay(f%temperature_active,f%temperature_c(i),f%gampar(i),f%theta(i), &
           f%rtheta(i),f%bexp(i),f%decpot(i),f%fdepth(i),decay_density,decay)
      if(decay%status/=B111_DECAY_OK)then
        candidate_mobile=committed_mobile;candidate_companion=committed_companion
        return
      end if
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
         receipt%drain_output_mg_cm2+receipt%bottom_output_mg_cm2+receipt%runoff_output_mg_cm2
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

  ! Backward Euler finite-volume transport with nonnegative donor advection.
  ! Positive scalar solves reuse the physical Freundlich inversion. All faces
  ! use one flux for both adjacent cells; failure returns both original owners.
  subroutine implicit_upwind(m,s,f,next,next_s,r,exact_empty_pond_limit)
    type(mobile_salt_state_t),intent(in)::m
    type(solute_compartment_state_t),intent(in)::s
    type(b111_reactive_solute_substep_forcing_t),intent(in)::f
    type(mobile_salt_state_t),intent(out)::next
    type(solute_compartment_state_t),intent(out)::next_s
    type(b111_reactive_solute_substep_receipt_t),intent(out)::r
    logical,intent(in),optional::exact_empty_pond_limit
    type(b111_pond_solute_result_t)::pond
    type(b111_decay_result_t)::decay
    type(b111_sorption_result_t)::partition,storage
    real(real64)::a(size(f%theta)-1),b(size(f%theta)-1),c(size(f%theta)),diag(size(f%theta))
    real(real64)::initial(size(f%theta)),source(size(f%theta)),rate(size(f%theta)),drain(size(f%theta))
    real(real64)::pivot(size(f%theta)),right(size(f%theta)),factor
    real(real64)::rhs,thetav,diffus,q,g,residual,local_scale,tol,largest,dt
    integer::n,i,k,sweep
    next=m;next_s=s;r=b111_reactive_solute_substep_receipt_t()
    n=size(f%theta);dt=f%dt_day
    r%mass_before_mg_cm2=sum(m%mass_mg_cm2)+s%solute_total()
    call evaluate_b111_pond_solute_exchange(s%pond_mass,f%rain_rate_cm_day,f%rain_c_mg_cm3, &
      f%irrigation_rate_cm_day,f%irrigation_c_mg_cm3,f%q_face_up_cm_day(1),f%macropore_area_fraction, &
      f%pond_end_cm,dt,pond,f%runon_rate_cm_day,f%runon_c_mg_cm3,f%runoff_depth_cm, &
      exact_empty_pond_limit=exact_empty_pond_limit)
    if(pond%status/=B111_POND_SOL_OK)return
    initial=m%mass_mg_cm2+s%sorbed_matrix_mass;source=initial
    source(1)=source(1)+pond%soil_transfer
    c=m%concentration_mg_cm3
    do i=1,n-1
      thetav=f%face_left_weight(i)*f%theta(i)+f%face_right_weight(i)*f%theta(i+1)
      if(thetav<=0.0_real64)return
      q=f%q_face_up_cm_day(i+1)
      diffus=f%molecular_diffusion_cm2_day*thetav**2.33_real64/f%theta_sat_left(i)**2
      g=(thetav*diffus+f%dispersivity_cm(i)*abs(q))/f%face_distance_cm(i)
      a(i)=min(q,0.0_real64)-g;b(i)=max(q,0.0_real64)+g
    end do
    do i=1,n
      call evaluate_b111_solute_decay(f%temperature_active,f%temperature_c(i),f%gampar(i),f%theta(i), &
        f%rtheta(i),f%bexp(i),f%decpot(i),f%fdepth(i),0.0_real64,decay)
      if(decay%status/=B111_DECAY_OK)return
      rate(i)=decay%decay_rate;drain(i)=0.0_real64
      do k=1,size(f%qdra_cm_day,1)
        q=f%qdra_cm_day(k,i)
        if(q>0.0_real64)then
          drain(i)=drain(i)+q
        else
          source(i)=source(i)-dt*q*f%cdrain_mg_cm3
          r%drain_input_mg_cm2=r%drain_input_mg_cm2-dt*q*f%cdrain_mg_cm3
        end if
      end do
      diag(i)=(1.0_real64+dt*rate(i))*f%theta(i)*f%dz_cm(i)+ &
        dt*(f%tscf*f%root_sink_cm_day(i)+drain(i))
      if(i>1)diag(i)=diag(i)+dt*b(i-1)
      if(i<n)diag(i)=diag(i)-dt*a(i)
    end do
    q=f%q_face_up_cm_day(n+1)
    if(q>0.0_real64)then
      source(n)=source(n)+dt*q*f%cseep_mg_cm3;r%bottom_input_mg_cm2=dt*q*f%cseep_mg_cm3
    else
      diag(n)=diag(n)-dt*q
    end if
    ! Every iteration solves a positive diagonal equation. The residual, rather
    ! than a change in concentration alone, certifies the coupled solve.
    local_scale=max(1.0_real64,maxval(source));tol=128.0_real64*epsilon(1.0_real64)*local_scale
    if(abs(f%frexp-1.0_real64)<=epsilon(1.0_real64))then
      ! Exact tridiagonal linear storage case, including very stiff diffusion.
      pivot=diag+(1.0_real64+dt*rate)*f%bulk_density*f%kf*f%dz_cm;right=source
      do i=2,n
        if(pivot(i-1)<=0.0_real64)return
        factor=dt*a(i-1)/pivot(i-1)
        pivot(i)=pivot(i)+factor*dt*b(i-1);right(i)=right(i)-factor*right(i-1)
      end do
      if(any(pivot<=0.0_real64))return
      c(n)=right(n)/pivot(n)
      do i=n-1,1,-1
        c(i)=(right(i)+dt*b(i)*c(i+1))/pivot(i)
      end do
      sweep=1
    else
     do sweep=1,2048
      do i=1,n
        rhs=source(i)
        if(i>1)rhs=rhs-dt*a(i-1)*c(i-1)
        if(i<n)rhs=rhs+dt*b(i)*c(i+1)
        call b111_sorption_partition_total(diag(i)/f%dz_cm(i), &
          (1.0_real64+dt*rate(i))*f%bulk_density(i),f%kf(i),f%cref_mg_cm3,f%frexp, &
          rhs/f%dz_cm(i),c(i),partition)
        if(partition%status/=B111_SORP_OK)then
          r%status=B111_REACTIVE_PARTITION;return
        end if
        c(i)=partition%concentration
      end do
      largest=0.0_real64
      do i=1,n
        call b111_sorption_storage_from_concentration(f%theta(i),f%bulk_density(i),f%kf(i), &
          f%cref_mg_cm3,f%frexp,c(i),storage)
        if(storage%status/=B111_SORP_OK)return
        rhs=source(i)
        if(i>1)rhs=rhs-dt*a(i-1)*c(i-1)
        if(i<n)rhs=rhs+dt*b(i)*c(i+1)
        residual=diag(i)*c(i)+(1.0_real64+dt*rate(i))*storage%sorbed_density*f%dz_cm(i)-rhs
        largest=max(largest,abs(residual))
      end do
      if(largest<=tol)exit
     end do
    end if
    r%nonlinear_sweeps=min(sweep,2048)
    if(sweep>2048)then
      r%status=B111_REACTIVE_NOCONV;return
    end if
    next%concentration_mg_cm3=c;next_s%pond_mass=pond%mass_after
    r%pond_to_soil_mg_cm2=pond%soil_transfer;r%runoff_output_mg_cm2=pond%runoff_output
    do i=1,n
      call b111_sorption_storage_from_concentration(f%theta(i),f%bulk_density(i),f%kf(i), &
        f%cref_mg_cm3,f%frexp,c(i),storage)
      next%mass_mg_cm2(i)=storage%dissolved_density*f%dz_cm(i)
      next_s%sorbed_matrix_mass(i)=storage%sorbed_density*f%dz_cm(i)
      r%decay_output_mg_cm2=r%decay_output_mg_cm2+dt*rate(i)*storage%total_density*f%dz_cm(i)
      r%root_output_mg_cm2=r%root_output_mg_cm2+dt*f%tscf*f%root_sink_cm_day(i)*c(i)
      r%drain_output_mg_cm2=r%drain_output_mg_cm2+dt*drain(i)*c(i)
    end do
    r%bottom_output_mg_cm2=-min(q,0.0_real64)*dt*c(n)
    r%external_input_mg_cm2=pond%rain_input+pond%irrigation_input+pond%runon_input+ &
      r%bottom_input_mg_cm2+r%drain_input_mg_cm2
    r%external_output_mg_cm2=r%decay_output_mg_cm2+r%root_output_mg_cm2+r%drain_output_mg_cm2+ &
      r%bottom_output_mg_cm2+r%runoff_output_mg_cm2
    r%mass_after_mg_cm2=sum(next%mass_mg_cm2)+next_s%solute_total()
    r%balance_residual_mg_cm2=r%mass_after_mg_cm2-r%mass_before_mg_cm2- &
      r%external_input_mg_cm2+r%external_output_mg_cm2
    local_scale=max(1.0_real64,r%mass_before_mg_cm2,r%mass_after_mg_cm2, &
      r%external_input_mg_cm2,r%external_output_mg_cm2)
    if(abs(r%balance_residual_mg_cm2)>8192.0_real64*epsilon(1.0_real64)*local_scale)then
      next=m;next_s=s;r%status=B111_REACTIVE_BALANCE;return
    end if
    r%status=B111_REACTIVE_OK
  end subroutine

  logical function mobile_valid(s) result(ok)
    type(mobile_salt_state_t),intent(in)::s
    ok=.false.
    if(.not.allocated(s%mass_mg_cm2).or..not.allocated(s%concentration_mg_cm3))return
    if(size(s%mass_mg_cm2)<1.or.size(s%concentration_mg_cm3)/=size(s%mass_mg_cm2))return
    ok=all(ieee_is_finite(s%mass_mg_cm2)).and.all(ieee_is_finite(s%concentration_mg_cm3)).and. &
       all(s%mass_mg_cm2>=0.0_real64).and.all(s%concentration_mg_cm3>=0.0_real64)
  end function

  logical function b111_reactive_forcing_valid(f) result(ok)
    type(b111_reactive_solute_substep_forcing_t),intent(in)::f
    integer::n
    ok=.false.
    if(f%transport_scheme/=B111_TRANSPORT_REFERENCE.and.f%transport_scheme/=B111_TRANSPORT_IMPLICIT_UPWIND)return
    if(.not.allocated(f%theta).or..not.allocated(f%dz_cm).or..not.allocated(f%q_face_up_cm_day).or. &
       .not.allocated(f%root_sink_cm_day).or..not.allocated(f%qdra_cm_day))return
    n=size(f%theta)
    if(allocated(f%theta_previous))then
      if(size(f%theta_previous)/=n)return
      if(.not.all(ieee_is_finite(f%theta_previous)))return
      if(any(f%theta_previous<=0.0_real64))return
    end if
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
       f%macropore_area_fraction,f%pond_end_cm,f%runoff_depth_cm,f%runon_rate_cm_day,f%runon_c_mg_cm3, &
       f%molecular_diffusion_cm2_day,f%cref_mg_cm3,f%frexp])))return
    if(f%dt_day<=0.0_real64.or.any(f%theta<=0.0_real64).or.any(f%dz_cm<=0.0_real64).or. &
       any(f%root_sink_cm_day<0.0_real64).or.any(f%rtheta<=0.0_real64).or.any(f%bexp<0.0_real64).or. &
       any(f%decpot<0.0_real64).or.any(f%fdepth<0.0_real64).or.any(f%bulk_density<0.0_real64).or. &
       any(f%kf<0.0_real64).or.min(f%cdrain_mg_cm3,f%cseep_mg_cm3,f%tscf,f%rain_rate_cm_day, &
       f%rain_c_mg_cm3,f%irrigation_rate_cm_day,f%irrigation_c_mg_cm3, &
       f%runon_rate_cm_day,f%runon_c_mg_cm3,f%pond_end_cm,f%runoff_depth_cm, &
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
