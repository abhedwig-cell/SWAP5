module mod_solute_mobile_salt_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SOLUTE_OK=0, SOLUTE_INVALID=1, SOLUTE_WATER_CLOSURE=2
  integer, parameter, public :: SOLUTE_NEGATIVE_MASS=3, SOLUTE_BALANCE_FAILURE=4

  ! Restricted E1 owner: one conservative dissolved constituent in mobile
  ! water. Mass is authoritative; CML is always derived from this mass and
  ! the matching water-content state.
  type, public :: mobile_salt_state_t
    real(real64), allocatable :: mass_mg_cm2(:)
    real(real64), allocatable :: concentration_mg_cm3(:)
  end type


  ! One accepted Richards substep. These records are ordered in solver time;
  ! they are candidate-local and must be discarded together on rejection.
  type, public :: mobile_salt_substep_t
    real(real64), allocatable :: water_start(:),water_trial(:)
    real(real64), allocatable :: face_flux_cm_day(:),root_water_sink_cm_day(:)
    real(real64), allocatable :: qdra_rate(:,:),qssdi_rate(:)
    real(real64) :: cdrain_mg_cm3=0.0_real64
    logical :: cdrain_available=.false.
    real(real64) :: top_boundary_concentration=0.0_real64
    real(real64) :: bottom_boundary_concentration=0.0_real64
    real(real64) :: duration_day=0.0_real64
  end type

  type, public :: mobile_salt_fluxes_t
    real(real64) :: top_input_mg_cm2=0.0_real64
    real(real64) :: top_output_mg_cm2=0.0_real64
    real(real64) :: bottom_input_mg_cm2=0.0_real64
    real(real64) :: bottom_output_mg_cm2=0.0_real64
    real(real64) :: root_uptake_mg_cm2=0.0_real64
    real(real64), allocatable :: qdra_signed_out_mg_cm2(:)
    real(real64) :: closure_error_mg_cm2=0.0_real64
  end type

  public :: initialize_mobile_salt_state, advance_mobile_salt_trial, advance_mobile_salt_trace

contains

  subroutine initialize_mobile_salt_state(node_thickness_cm,water_content,initial_concentration,state,status)
    real(real64), intent(in) :: node_thickness_cm(:),water_content(:),initial_concentration(:)
    type(mobile_salt_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: n
    state=mobile_salt_state_t(); status=SOLUTE_INVALID
    n=size(node_thickness_cm)
    if(n==0.or.size(water_content)/=n.or.size(initial_concentration)/=n) return
    if(.not.all(ieee_is_finite(node_thickness_cm)).or..not.all(ieee_is_finite(water_content)).or. &
       .not.all(ieee_is_finite(initial_concentration))) return
    if(any(node_thickness_cm<=0.0_real64).or.any(water_content<=0.0_real64).or.any(initial_concentration<0.0_real64)) return
    allocate(state%mass_mg_cm2(n),state%concentration_mg_cm3(n))
    state%mass_mg_cm2=initial_concentration*water_content*node_thickness_cm
    state%concentration_mg_cm3=initial_concentration
    if(any(.not.ieee_is_finite(state%mass_mg_cm2))) then
      state=mobile_salt_state_t();return
    end if
    status=SOLUTE_OK
  end subroutine

  ! Advances a trial using explicit advection only. Face fluxes are positive
  ! downward and have units cm/day; qroot is positive water uptake in cm/day.
  ! The caller supplies water start/end states and must use the same accepted
  ! candidate root sink for its single water-mass receipt. This routine owns
  ! only salt and never mutates committed input state.
  subroutine advance_mobile_salt_trial(committed,node_thickness_cm,water_start,water_trial,face_flux_cm_day, &
       root_water_sink_cm_day,top_boundary_concentration,bottom_boundary_concentration,tscf,dt_day,candidate,fluxes,status, &
       qdra_rate,qssdi_rate,cdrain_mg_cm3,cdrain_available)
    type(mobile_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: node_thickness_cm(:),water_start(:),water_trial(:),face_flux_cm_day(:)
    real(real64), intent(in) :: root_water_sink_cm_day(:),top_boundary_concentration,bottom_boundary_concentration
    real(real64), intent(in) :: tscf,dt_day
    type(mobile_salt_state_t), intent(out) :: candidate
    type(mobile_salt_fluxes_t), intent(out) :: fluxes
    integer, intent(out) :: status
    real(real64), allocatable, intent(in), optional :: qdra_rate(:,:),qssdi_rate(:)
    real(real64), intent(in), optional :: cdrain_mg_cm3
    logical, intent(in), optional :: cdrain_available
    real(real64), allocatable :: delta_water(:),mass(:),c_start(:),qdra_by_level(:,:)
    real(real64) :: q,rate,tol,water_residual,expected_mass,drain_c
    logical :: has_qdra,has_qssdi,has_cdrain,cdrain_enabled
    integer :: n,i,nlev,lev

    candidate=mobile_salt_state_t();fluxes=mobile_salt_fluxes_t();status=SOLUTE_INVALID
    n=size(node_thickness_cm)
    if(n==0.or..not.allocated(committed%mass_mg_cm2)) return
    if(.not.allocated(committed%concentration_mg_cm3)) return
    if(size(committed%mass_mg_cm2)/=n.or.size(committed%concentration_mg_cm3)/=n.or. &
       size(water_start)/=n.or.size(water_trial)/=n.or.size(root_water_sink_cm_day)/=n.or.size(face_flux_cm_day)/=n+1) return
    if(.not.all(ieee_is_finite(node_thickness_cm)).or..not.all(ieee_is_finite(water_start)).or. &
       .not.all(ieee_is_finite(water_trial)).or..not.all(ieee_is_finite(face_flux_cm_day)).or. &
       .not.all(ieee_is_finite(root_water_sink_cm_day)).or..not.all(ieee_is_finite(committed%mass_mg_cm2)).or. &
       .not.all(ieee_is_finite(committed%concentration_mg_cm3)).or. &
       .not.all(ieee_is_finite([top_boundary_concentration,bottom_boundary_concentration,tscf,dt_day]))) return
    if(any(node_thickness_cm<=0.0_real64).or.any(water_start<=0.0_real64).or.any(water_trial<=0.0_real64).or. &
       any(root_water_sink_cm_day<0.0_real64).or.any(committed%mass_mg_cm2<0.0_real64).or. &
       any(committed%concentration_mg_cm3<0.0_real64).or.top_boundary_concentration<0.0_real64.or. &
       bottom_boundary_concentration<0.0_real64.or.tscf<0.0_real64.or.tscf>10.0_real64.or.dt_day<=0.0_real64) return

    has_qdra=.false.;has_qssdi=.false.
    if(present(qdra_rate))then
      if(.not.allocated(qdra_rate))return
      has_qdra=.true.
    end if
    if(present(qssdi_rate))then
      if(.not.allocated(qssdi_rate))return
      has_qssdi=.true.
    end if
    has_cdrain=present(cdrain_available).and.present(cdrain_mg_cm3)
    cdrain_enabled=.false.
    if(has_cdrain)cdrain_enabled=cdrain_available
    allocate(qdra_by_level(0,n))
    if(has_qssdi) then
      if(size(qssdi_rate)/=n.or.any(.not.ieee_is_finite(qssdi_rate)))return
    end if
    if(has_qdra) then
      if(size(qdra_rate,2)/=n.or.size(qdra_rate,1)<=0.or.any(.not.ieee_is_finite(qdra_rate)))return
      nlev=size(qdra_rate,1)
      if(any(qdra_rate<0.0_real64).and..not.cdrain_enabled)return
      deallocate(qdra_by_level);allocate(qdra_by_level(nlev,n));qdra_by_level=qdra_rate
      allocate(fluxes%qdra_signed_out_mg_cm2(nlev));fluxes%qdra_signed_out_mg_cm2=0.0_real64
    else
      nlev=0
    end if
    drain_c=0.0_real64
    if(present(cdrain_mg_cm3))then
      if(.not.ieee_is_finite(cdrain_mg_cm3).or.cdrain_mg_cm3<0.0_real64)return
      drain_c=cdrain_mg_cm3
    end if

    allocate(c_start(n),mass(n),delta_water(n))
    c_start=committed%mass_mg_cm2/(water_start*node_thickness_cm)
    tol=512.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(water_start*node_thickness_cm), &
       maxval(water_trial*node_thickness_cm),dt_day*maxval(abs(face_flux_cm_day)))
    if(any(abs(c_start-committed%concentration_mg_cm3)>tol*max(1.0_real64,maxval(c_start)))) return

    ! The mobile liquid volume and its fluxes must close before salt is moved.
    do i=1,n
      rate=0.0_real64
      if(has_qssdi)rate=qssdi_rate(i)
      if(has_qdra)rate=rate-sum(qdra_by_level(:,i))
      delta_water(i)=dt_day*(face_flux_cm_day(i)-face_flux_cm_day(i+1)+rate-root_water_sink_cm_day(i))
      water_residual=(water_trial(i)-water_start(i))*node_thickness_cm(i)-delta_water(i)
      if(abs(water_residual)>tol) then
        status=SOLUTE_WATER_CLOSURE;return
      end if
    end do

    mass=committed%mass_mg_cm2
    ! Top boundary: down is inflow, up is outflow from node 1.
    q=face_flux_cm_day(1)*dt_day
    if(q>=0.0_real64) then
      rate=q*top_boundary_concentration;mass(1)=mass(1)+rate;fluxes%top_input_mg_cm2=rate
    else
      rate=-q*c_start(1);mass(1)=mass(1)-rate;fluxes%top_output_mg_cm2=rate
    end if
    ! Internal faces use the upwind mobile concentration from the committed state.
    do i=1,n-1
      q=face_flux_cm_day(i+1)*dt_day
      if(q>=0.0_real64) then
        rate=q*c_start(i);mass(i)=mass(i)-rate;mass(i+1)=mass(i+1)+rate
      else
        rate=-q*c_start(i+1);mass(i+1)=mass(i+1)-rate;mass(i)=mass(i)+rate
      end if
    end do
    ! Bottom boundary: down is outflow from the last node, up is inflow.
    q=face_flux_cm_day(n+1)*dt_day
    if(q>=0.0_real64) then
      rate=q*c_start(n);mass(n)=mass(n)-rate;fluxes%bottom_output_mg_cm2=rate
    else
      rate=-q*bottom_boundary_concentration;mass(n)=mass(n)+rate;fluxes%bottom_input_mg_cm2=rate
    end if
    do i=1,n
      rate=tscf*root_water_sink_cm_day(i)*dt_day*c_start(i)
      mass(i)=mass(i)-rate;fluxes%root_uptake_mg_cm2=fluxes%root_uptake_mg_cm2+rate
    end do
    if(has_qdra)then
      do lev=1,nlev
        do i=1,n
          q=qdra_by_level(lev,i)*dt_day
          if(q>=0.0_real64)then
            rate=q*c_start(i)
          else
            rate=q*drain_c
          end if
          mass(i)=mass(i)-rate
          fluxes%qdra_signed_out_mg_cm2(lev)=fluxes%qdra_signed_out_mg_cm2(lev)+rate
        end do
      end do
    end if
    if(any(.not.ieee_is_finite(mass)).or. &
       .not.all(ieee_is_finite([fluxes%top_input_mg_cm2,fluxes%top_output_mg_cm2, &
       fluxes%bottom_input_mg_cm2,fluxes%bottom_output_mg_cm2,fluxes%root_uptake_mg_cm2]))) return
    if(any(mass < -tol)) then
      status=SOLUTE_NEGATIVE_MASS;return
    end if
    if(any(mass<0.0_real64)) then
      ! Roundoff-sized deficits are not physical clipping: reject the candidate
      ! rather than create or destroy salt under an undocumented floor.
      status=SOLUTE_NEGATIVE_MASS;return
    end if

    expected_mass=sum(committed%mass_mg_cm2)+fluxes%top_input_mg_cm2-fluxes%top_output_mg_cm2+ &
      fluxes%bottom_input_mg_cm2-fluxes%bottom_output_mg_cm2-fluxes%root_uptake_mg_cm2
    if(has_qdra)expected_mass=expected_mass-sum(fluxes%qdra_signed_out_mg_cm2)
    if(.not.ieee_is_finite(expected_mass)) return
    fluxes%closure_error_mg_cm2=sum(mass)-expected_mass
    tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(expected_mass),sum(abs(mass)))
    if(abs(fluxes%closure_error_mg_cm2)>tol) then
      status=SOLUTE_BALANCE_FAILURE;return
    end if
    candidate%mass_mg_cm2=mass
    candidate%concentration_mg_cm3=mass/(water_trial*node_thickness_cm)
    if(any(.not.ieee_is_finite(candidate%concentration_mg_cm3))) then
      candidate=mobile_salt_state_t();status=SOLUTE_INVALID;return
    end if
    status=SOLUTE_OK
  end subroutine


  ! Applies a time-ordered sequence of accepted physical substeps to one salt
  ! candidate. Every step uses the concentration produced by its predecessor.
  ! If any step is invalid, the entire trace is discarded and no partial receipt
  ! or candidate escapes this routine.
  subroutine advance_mobile_salt_trace(committed,node_thickness_cm,substeps,tscf,candidate,fluxes,status)
    type(mobile_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: node_thickness_cm(:),tscf
    type(mobile_salt_substep_t), intent(in) :: substeps(:)
    type(mobile_salt_state_t), intent(out) :: candidate
    type(mobile_salt_fluxes_t), intent(out) :: fluxes
    integer, intent(out) :: status
    type(mobile_salt_state_t) :: current,next
    type(mobile_salt_fluxes_t) :: step_fluxes
    real(real64) :: continuity_tolerance
    integer :: k

    candidate=mobile_salt_state_t()
    fluxes=mobile_salt_fluxes_t()
    status=SOLUTE_INVALID
    if(size(substeps)==0.or.size(node_thickness_cm)==0) return
    if(.not.allocated(committed%mass_mg_cm2).or..not.allocated(committed%concentration_mg_cm3)) return
    do k=1,size(substeps)
      if(.not.allocated(substeps(k)%water_start).or..not.allocated(substeps(k)%water_trial).or. &
         .not.allocated(substeps(k)%face_flux_cm_day).or..not.allocated(substeps(k)%root_water_sink_cm_day)) then
        status=SOLUTE_INVALID
        return
      end if
    end do
    do k=2,size(substeps)
      if(size(substeps(k)%water_start)/=size(substeps(k-1)%water_trial)) then
        status=SOLUTE_WATER_CLOSURE
        return
      end if
      continuity_tolerance=512.0_real64*epsilon(1.0_real64)*max(1.0_real64, &
           maxval(abs(substeps(k)%water_start)),maxval(abs(substeps(k-1)%water_trial)))
      if(any(abs(substeps(k)%water_start-substeps(k-1)%water_trial)>continuity_tolerance)) then
        status=SOLUTE_WATER_CLOSURE
        return
      end if
    end do
    current=committed
    do k=1,size(substeps)
      if(allocated(substeps(k)%qdra_rate).and.allocated(substeps(k)%qssdi_rate))then
        call advance_mobile_salt_trial(current,node_thickness_cm,substeps(k)%water_start,substeps(k)%water_trial, &
             substeps(k)%face_flux_cm_day,substeps(k)%root_water_sink_cm_day, &
             substeps(k)%top_boundary_concentration,substeps(k)%bottom_boundary_concentration,tscf, &
             substeps(k)%duration_day,next,step_fluxes,status,qdra_rate=substeps(k)%qdra_rate, &
             qssdi_rate=substeps(k)%qssdi_rate,cdrain_mg_cm3=substeps(k)%cdrain_mg_cm3, &
             cdrain_available=substeps(k)%cdrain_available)
      else if(allocated(substeps(k)%qdra_rate))then
        call advance_mobile_salt_trial(current,node_thickness_cm,substeps(k)%water_start,substeps(k)%water_trial, &
             substeps(k)%face_flux_cm_day,substeps(k)%root_water_sink_cm_day, &
             substeps(k)%top_boundary_concentration,substeps(k)%bottom_boundary_concentration,tscf, &
             substeps(k)%duration_day,next,step_fluxes,status,qdra_rate=substeps(k)%qdra_rate, &
             cdrain_mg_cm3=substeps(k)%cdrain_mg_cm3,cdrain_available=substeps(k)%cdrain_available)
      else if(allocated(substeps(k)%qssdi_rate))then
        call advance_mobile_salt_trial(current,node_thickness_cm,substeps(k)%water_start,substeps(k)%water_trial, &
             substeps(k)%face_flux_cm_day,substeps(k)%root_water_sink_cm_day, &
             substeps(k)%top_boundary_concentration,substeps(k)%bottom_boundary_concentration,tscf, &
             substeps(k)%duration_day,next,step_fluxes,status,qssdi_rate=substeps(k)%qssdi_rate, &
             cdrain_mg_cm3=substeps(k)%cdrain_mg_cm3,cdrain_available=substeps(k)%cdrain_available)
      else
        call advance_mobile_salt_trial(current,node_thickness_cm,substeps(k)%water_start,substeps(k)%water_trial, &
             substeps(k)%face_flux_cm_day,substeps(k)%root_water_sink_cm_day, &
             substeps(k)%top_boundary_concentration,substeps(k)%bottom_boundary_concentration,tscf, &
             substeps(k)%duration_day,next,step_fluxes,status,cdrain_mg_cm3=substeps(k)%cdrain_mg_cm3, &
             cdrain_available=substeps(k)%cdrain_available)
      end if
      if(status/=SOLUTE_OK) then
        fluxes=mobile_salt_fluxes_t()
        candidate=mobile_salt_state_t()
        return
      end if
      current=next
      fluxes%top_input_mg_cm2=fluxes%top_input_mg_cm2+step_fluxes%top_input_mg_cm2
      fluxes%top_output_mg_cm2=fluxes%top_output_mg_cm2+step_fluxes%top_output_mg_cm2
      fluxes%bottom_input_mg_cm2=fluxes%bottom_input_mg_cm2+step_fluxes%bottom_input_mg_cm2
      fluxes%bottom_output_mg_cm2=fluxes%bottom_output_mg_cm2+step_fluxes%bottom_output_mg_cm2
      fluxes%root_uptake_mg_cm2=fluxes%root_uptake_mg_cm2+step_fluxes%root_uptake_mg_cm2
      if(allocated(step_fluxes%qdra_signed_out_mg_cm2))then
        if(.not.allocated(fluxes%qdra_signed_out_mg_cm2))then
          allocate(fluxes%qdra_signed_out_mg_cm2(size(step_fluxes%qdra_signed_out_mg_cm2)))
          fluxes%qdra_signed_out_mg_cm2=0.0_real64
        else if(size(fluxes%qdra_signed_out_mg_cm2)/=size(step_fluxes%qdra_signed_out_mg_cm2))then
          fluxes=mobile_salt_fluxes_t();candidate=mobile_salt_state_t();status=SOLUTE_INVALID;return
        end if
        fluxes%qdra_signed_out_mg_cm2=fluxes%qdra_signed_out_mg_cm2+step_fluxes%qdra_signed_out_mg_cm2
      else if(allocated(fluxes%qdra_signed_out_mg_cm2))then
        fluxes=mobile_salt_fluxes_t();candidate=mobile_salt_state_t();status=SOLUTE_INVALID;return
      end if
      fluxes%closure_error_mg_cm2=fluxes%closure_error_mg_cm2+step_fluxes%closure_error_mg_cm2
      if(.not.all(ieee_is_finite([fluxes%top_input_mg_cm2,fluxes%top_output_mg_cm2, &
         fluxes%bottom_input_mg_cm2,fluxes%bottom_output_mg_cm2,fluxes%root_uptake_mg_cm2, &
         fluxes%closure_error_mg_cm2]))) then
        fluxes=mobile_salt_fluxes_t()
        candidate=mobile_salt_state_t()
        status=SOLUTE_INVALID
        return
      end if
    end do
    candidate=current
    status=SOLUTE_OK
  end subroutine

end module
