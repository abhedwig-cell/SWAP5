! Research formulation: explicit phase-volume receipts, conservative heat trial.
! No production caller. No ice/vapor/atmospheric owner or full-SWAP energy claim.
module mod_conservative_soil_heat_trial
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_linear_mixture_sensible_storage,only:linear_mixture_sensible_storage_parameters_t, &
  evaluate_mixture_heat_capacity,evaluate_sensible_storage,LMSS_OK
 use mod_reference_linear_solver,only:reference_tridag
 implicit none
 private
 integer,parameter,public::CH_OK=0,CH_INVALID=1,CH_WATER_BALANCE=2,CH_GAS_BALANCE=3, &
  CH_MISSING_DONOR=4,CH_MISSING_HEAT=5,CH_UNSUPPORTED_PHASE=6,CH_NUMERIC=7
 type,public::conservative_heat_request_t
  type(linear_mixture_sensible_storage_parameters_t),allocatable::material(:)
  real(real64),allocatable::dz_cm(:),theta_start(:),theta_end(:),temperature_start_c(:)
  ! Integrated cm/column area over this trial; faces positive downward.
  real(real64),allocatable::water_face_cm(:),gas_face_cm(:),root_water_out_cm(:)
  real(real64),allocatable::water_external_cm(:),gas_external_cm(:)
  real(real64),allocatable::water_source_temperature_c(:),gas_source_temperature_c(:)
  logical,allocatable::water_source_available(:),gas_source_available(:)
  real(real64),allocatable::internal_conductance_j_cm2_k(:)
  real(real64)::water_boundary_temperature_c(2)=0d0,gas_boundary_temperature_c(2)=0d0
  logical::water_boundary_available(2)=.false.,gas_boundary_available(2)=.false.
  real(real64)::boundary_heat_into_j_cm2(2)=0d0
  logical::boundary_heat_available(2)=.false.
  logical::phase_change_active=.false.,vapor_active=.false.
 end type
 type,public::conservative_heat_result_t
  integer::status=CH_INVALID
  logical::produced=.false.,sensible_scope_complete=.false.
  logical::full_swap_energy_balance_complete=.false.
  real(real64),allocatable::temperature_c(:),water_face_energy_j_cm2(:),gas_face_energy_j_cm2(:)
  real(real64)::storage_change_j_cm2=0d0,external_energy_into_j_cm2=0d0,residual_j_cm2=0d0
  real(real64)::root_energy_out_j_cm2=0d0,water_source_energy_into_j_cm2=0d0,gas_source_energy_into_j_cm2=0d0
 end type
 public::trial_conservative_soil_heat
contains
 subroutine trial_conservative_soil_heat(r,result)
  type(conservative_heat_request_t),intent(in)::r
  type(conservative_heat_result_t),intent(out)::result
  real(real64),allocatable::a(:),b(:),c(:),rhs(:),gamma(:),t(:),capacity0(:),capacity1(:)
  real(real64),allocatable::cw(:),cg(:),ew(:),eg(:)
  real(real64)::reference,old,new,scale,stock_scale,amount,heat,eps,water_change,gas_change
  integer::n,i,status
  logical::ok
  result=conservative_heat_result_t();eps=epsilon(1d0)
  if(r%phase_change_active.or.r%vapor_active)then
   result%status=CH_UNSUPPORTED_PHASE;return
  end if
  if(.not.allocated(r%material).or..not.allocated(r%dz_cm).or..not.allocated(r%theta_start).or. &
   .not.allocated(r%theta_end).or..not.allocated(r%temperature_start_c).or..not.allocated(r%water_face_cm).or. &
   .not.allocated(r%gas_face_cm).or..not.allocated(r%root_water_out_cm).or. &
   .not.allocated(r%water_external_cm).or..not.allocated(r%gas_external_cm).or. &
   .not.allocated(r%water_source_temperature_c).or..not.allocated(r%gas_source_temperature_c).or. &
   .not.allocated(r%water_source_available).or..not.allocated(r%gas_source_available).or. &
   .not.allocated(r%internal_conductance_j_cm2_k))return
  n=size(r%material);if(n<1)return
  if(size(r%dz_cm)/=n.or.size(r%theta_start)/=n.or.size(r%theta_end)/=n.or. &
   size(r%temperature_start_c)/=n.or.size(r%water_face_cm)/=n+1.or.size(r%gas_face_cm)/=n+1.or. &
   size(r%root_water_out_cm)/=n.or.size(r%water_external_cm)/=n.or.size(r%gas_external_cm)/=n.or. &
   size(r%water_source_temperature_c)/=n.or.size(r%gas_source_temperature_c)/=n.or. &
   size(r%water_source_available)/=n.or.size(r%gas_source_available)/=n.or. &
   size(r%internal_conductance_j_cm2_k)/=n-1)return
  if(any(.not.ieee_is_finite(r%dz_cm)).or.any(r%dz_cm<=0d0).or. &
   any(.not.ieee_is_finite(r%temperature_start_c)).or. &
   any(.not.ieee_is_finite(r%water_face_cm)).or.any(.not.ieee_is_finite(r%gas_face_cm)).or. &
   any(.not.ieee_is_finite(r%root_water_out_cm)).or.any(r%root_water_out_cm<0d0).or. &
   any(.not.ieee_is_finite(r%water_external_cm)).or.any(.not.ieee_is_finite(r%gas_external_cm)).or. &
   any(.not.ieee_is_finite(r%internal_conductance_j_cm2_k)).or.any(r%internal_conductance_j_cm2_k<0d0))return
  if(any(r%temperature_start_c<0d0))then
   result%status=CH_UNSUPPORTED_PHASE;return
  end if
  if(.not.all(r%boundary_heat_available))then
   result%status=CH_MISSING_HEAT;return
  end if
  if(any(.not.ieee_is_finite(r%boundary_heat_into_j_cm2)))return
  allocate(a(n),b(n),c(n),rhs(n),gamma(n),t(n),capacity0(n),capacity1(n),cw(n),cg(n),ew(n+1),eg(n+1))
  reference=r%material(1)%reference_temperature_c
  do i=1,n
   if(.not.r%material(i)%ready())return
   if(r%material(i)%reference_temperature_c/=reference)return
   call evaluate_mixture_heat_capacity(r%theta_start(i),r%material(i),capacity0(i),status)
   if(status/=LMSS_OK)return
   call evaluate_mixture_heat_capacity(r%theta_end(i),r%material(i),capacity1(i),status)
   if(status/=LMSS_OK)return
   cw(i)=r%material(i)%liquid_heat_capacity_j_cm3_k;cg(i)=r%material(i)%gas_heat_capacity_j_cm3_k
   ! This first research seam requires one phase material across connected faces.
   if(cw(i)/=cw(1).or.cg(i)/=cg(1))return
   water_change=r%dz_cm(i)*(r%theta_end(i)-r%theta_start(i))
   amount=r%water_face_cm(i)-r%water_face_cm(i+1)+r%water_external_cm(i)-r%root_water_out_cm(i)
   scale=max(tiny(1d0),abs(r%dz_cm(i)*r%theta_start(i)),abs(r%dz_cm(i)*r%theta_end(i)), &
    abs(r%water_face_cm(i))+abs(r%water_face_cm(i+1))+abs(r%water_external_cm(i))+r%root_water_out_cm(i))
   if(abs(water_change-amount)>128d0*eps*scale)then
    result%status=CH_WATER_BALANCE;return
   end if
   gas_change=-water_change
   amount=r%gas_face_cm(i)-r%gas_face_cm(i+1)+r%gas_external_cm(i)
   scale=max(scale,abs(r%gas_face_cm(i))+abs(r%gas_face_cm(i+1))+abs(r%gas_external_cm(i)))
   if(abs(gas_change-amount)>128d0*eps*scale)then
    result%status=CH_GAS_BALANCE;return
   end if
  end do
  a=0d0;c=0d0;b=r%dz_cm*capacity1;rhs=r%dz_cm*capacity0*(r%temperature_start_c-reference)
  rhs(1)=rhs(1)+r%boundary_heat_into_j_cm2(1);rhs(n)=rhs(n)+r%boundary_heat_into_j_cm2(2)
  do i=1,n-1
   heat=r%internal_conductance_j_cm2_k(i)
   b(i)=b(i)+heat;b(i+1)=b(i+1)+heat;c(i)=c(i)-heat;a(i+1)=a(i+1)-heat
  end do
  call assemble_phase(r%water_face_cm,cw(1),r%water_boundary_temperature_c,r%water_boundary_available, &
   r%water_external_cm,r%water_source_temperature_c,r%water_source_available,ok)
  if(.not.ok)then
   result%status=CH_MISSING_DONOR;return
  end if
  call assemble_phase(r%gas_face_cm,cg(1),r%gas_boundary_temperature_c,r%gas_boundary_available, &
   r%gas_external_cm,r%gas_source_temperature_c,r%gas_source_available,ok)
  if(.not.ok)then
   result%status=CH_MISSING_DONOR;return
  end if
  b=b+cw*r%root_water_out_cm
  call reference_tridag(n,a,b,c,rhs,t,gamma,status)
  if(status/=0.or.any(.not.ieee_is_finite(t)))then
   result%status=CH_NUMERIC;return
  end if
  t=t+reference
  if(any(t<0d0))then
   result%status=CH_UNSUPPORTED_PHASE;return
  end if
  stock_scale=0d0
  do i=1,n
   call evaluate_sensible_storage(r%dz_cm(i),r%theta_start(i),r%temperature_start_c(i),r%material(i),old,status)
   if(status/=LMSS_OK)return
   call evaluate_sensible_storage(r%dz_cm(i),r%theta_end(i),t(i),r%material(i),new,status)
   if(status/=LMSS_OK)return
   result%storage_change_j_cm2=result%storage_change_j_cm2+(new-old)/1d4
   stock_scale=stock_scale+(abs(new)+abs(old))/1d4
  end do
  call phase_energy(r%water_face_cm,cw(1),r%water_boundary_temperature_c,r%water_external_cm, &
   r%water_source_temperature_c,ew,result%water_source_energy_into_j_cm2)
  call phase_energy(r%gas_face_cm,cg(1),r%gas_boundary_temperature_c,r%gas_external_cm, &
   r%gas_source_temperature_c,eg,result%gas_source_energy_into_j_cm2)
  result%root_energy_out_j_cm2=sum(cw*r%root_water_out_cm*(t-reference))
  result%external_energy_into_j_cm2=sum(r%boundary_heat_into_j_cm2)+ew(1)-ew(n+1)+eg(1)-eg(n+1)+ &
   result%water_source_energy_into_j_cm2+result%gas_source_energy_into_j_cm2-result%root_energy_out_j_cm2
  result%residual_j_cm2=result%storage_change_j_cm2-result%external_energy_into_j_cm2
  if(.not.ieee_is_finite(result%residual_j_cm2).or. &
   abs(result%residual_j_cm2)>512d0*eps*real(n,real64)*max(tiny(1d0),stock_scale,abs(result%external_energy_into_j_cm2)))then
   result%status=CH_NUMERIC;return
  end if
  result%temperature_c=t;result%water_face_energy_j_cm2=ew;result%gas_face_energy_j_cm2=eg
  result%status=CH_OK;result%produced=.true.;result%sensible_scope_complete=.true.
 contains
  subroutine assemble_phase(face,capacity,external_t,available,source,source_t,source_available,valid)
   real(real64),intent(in)::face(:),capacity,external_t(2),source(:),source_t(:)
   logical,intent(in)::available(2),source_available(:)
   logical,intent(out)::valid
   integer::j
   real(real64)::value
   valid=.false.
   do j=1,n-1
    value=capacity*face(j+1)
    if(value>=0d0)then
     b(j)=b(j)+value;a(j+1)=a(j+1)-value
    else
     b(j+1)=b(j+1)-value;c(j)=c(j)+value
    end if
   end do
   if(face(1)>0d0)then
    if(.not.available(1).or..not.ieee_is_finite(external_t(1)))return
    rhs(1)=rhs(1)+capacity*face(1)*(external_t(1)-reference)
   else
    b(1)=b(1)-capacity*face(1)
   end if
   if(face(n+1)<0d0)then
    if(.not.available(2).or..not.ieee_is_finite(external_t(2)))return
    rhs(n)=rhs(n)-capacity*face(n+1)*(external_t(2)-reference)
   else
    b(n)=b(n)+capacity*face(n+1)
   end if
   do j=1,n
    if(source(j)>0d0)then
     if(.not.source_available(j).or..not.ieee_is_finite(source_t(j)))return
     rhs(j)=rhs(j)+capacity*source(j)*(source_t(j)-reference)
    else
     b(j)=b(j)-capacity*source(j)
    end if
   end do
   valid=.true.
  end subroutine
  subroutine phase_energy(face,capacity,external_t,source,source_t,energy,source_energy)
   real(real64),intent(in)::face(:),capacity,external_t(2),source(:),source_t(:)
   real(real64),intent(out)::energy(:),source_energy
   integer::j
   energy=0d0;source_energy=0d0
   if(face(1)>0d0)energy(1)=capacity*face(1)*(external_t(1)-reference)
   if(face(1)<0d0)energy(1)=capacity*face(1)*(t(1)-reference)
   if(face(n+1)<0d0)energy(n+1)=capacity*face(n+1)*(external_t(2)-reference)
   if(face(n+1)>0d0)energy(n+1)=capacity*face(n+1)*(t(n)-reference)
   do j=1,n-1
    if(face(j+1)>=0d0)then
     energy(j+1)=capacity*face(j+1)*(t(j)-reference)
    else
     energy(j+1)=capacity*face(j+1)*(t(j+1)-reference)
    end if
   end do
   do j=1,n
    if(source(j)>0d0)then
     source_energy=source_energy+capacity*source(j)*(source_t(j)-reference)
    else
     source_energy=source_energy+capacity*source(j)*(t(j)-reference)
    end if
   end do
  end subroutine
 end subroutine
end module
