! Read-only observations of the actual thermal trial; no new physical state.
module mod_fmr_thermal_substep_receipt
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_temperature_contract,only:soil_temperature_parameters_t,soil_temperature_workspace_t, &
  soil_temperature_result_t,soil_temperature_forcing_t,SOIL_TEMP_OK,SOIL_TEMP_SOLUTION_NUMERIC, &
  SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
 implicit none
 private
 type,public::fmr_thermal_substep_receipt_t
  logical::available=.false.,conductive_profile_available=.false.,independent_boundary_heat=.false.
  logical::gas_transport_available=.false.,advective_energy_complete=.false.,full_energy_balance_complete=.false.
  integer::solution_mode=0,top_boundary_mode=0,bottom_boundary_mode=0
  real(real64)::t0=0d0,t1=0d0
  real(real64),allocatable::temperature_start_c(:),temperature_end_c(:),water_start(:),water_end(:)
  real(real64),allocatable::dz_cm(:),theta_sat(:),f_quartz(:),f_clay(:),f_organic(:)
  real(real64),allocatable::heat_capacity_average_j_cm3_k(:),conductive_face_energy_j_cm2(:)
  real(real64)::legacy_storage_change_j_cm2=0d0,legacy_boundary_energy_j_cm2=0d0
 end type
 public::capture_fmr_thermal_substep
contains
 subroutine capture_fmr_thermal_substep(p,w,f,r,water0,water1,t0,t1,receipt)
  type(soil_temperature_parameters_t),intent(in)::p
  type(soil_temperature_workspace_t),intent(in)::w
  type(soil_temperature_forcing_t),intent(in)::f
  type(soil_temperature_result_t),intent(in)::r
  real(real64),intent(in)::water0(:),water1(:),t0,t1
  type(fmr_thermal_substep_receipt_t),intent(out)::receipt
  integer::n,i
  real(real64)::dt
  receipt=fmr_thermal_substep_receipt_t()
  if(.not.p%ready().or.r%status/=SOIL_TEMP_OK.or..not.r%produced)return
  if(.not.all(ieee_is_finite([t0,t1])).or.t1<=t0)return
  n=p%node_count();dt=t1-t0
  if(size(water0)/=n.or.size(water1)/=n)return
  if(.not.allocated(w%old_temperature_c).or..not.allocated(w%solution).or. &
     .not.allocated(w%heat_capacity_j_cm3_k).or..not.allocated(w%face_conductivity_j_cm_k_day))return
  if(size(w%old_temperature_c)/=n.or.size(w%solution)/=n.or. &
     size(w%heat_capacity_j_cm3_k)/=n.or.size(w%face_conductivity_j_cm_k_day)/=n)return
  if(any(.not.ieee_is_finite(water0)).or.any(.not.ieee_is_finite(water1)).or. &
     any(.not.ieee_is_finite(w%old_temperature_c)).or.any(.not.ieee_is_finite(w%solution)).or. &
     any(.not.ieee_is_finite(w%heat_capacity_j_cm3_k)).or.any(w%heat_capacity_j_cm3_k<=0d0).or. &
     any(.not.ieee_is_finite(w%face_conductivity_j_cm_k_day)).or. &
     any(.not.ieee_is_finite([r%top_heat_flux_into_soil_j_cm2_day,r%bottom_heat_flux_into_soil_j_cm2_day, &
                            r%sensible_storage_change_j_cm2,r%boundary_energy_into_soil_j_cm2])))return
  receipt%t0=t0;receipt%t1=t1
  receipt%solution_mode=p%solution_mode;receipt%top_boundary_mode=f%top_boundary_mode
  receipt%bottom_boundary_mode=f%bottom_boundary_mode
  receipt%temperature_start_c=w%old_temperature_c;receipt%temperature_end_c=w%solution
  ! Preserve raw hydraulic values, including roundoff domain overshoot. No clip.
  receipt%water_start=water0;receipt%water_end=water1;receipt%dz_cm=p%dz_cm;receipt%theta_sat=p%theta_sat
  receipt%f_quartz=p%f_quartz;receipt%f_clay=p%f_clay;receipt%f_organic=p%f_organic
  receipt%heat_capacity_average_j_cm3_k=w%heat_capacity_j_cm3_k
  receipt%legacy_storage_change_j_cm2=r%sensible_storage_change_j_cm2
  receipt%legacy_boundary_energy_j_cm2=r%boundary_energy_into_soil_j_cm2
  receipt%conductive_profile_available=p%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC
  receipt%independent_boundary_heat=receipt%conductive_profile_available.and. &
       f%top_boundary_mode/=SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
  if(receipt%conductive_profile_available)then
   allocate(receipt%conductive_face_energy_j_cm2(n+1))
   ! All faces positive downward; bottom owner reports heat INTO soil (upward).
   receipt%conductive_face_energy_j_cm2(1)=dt*r%top_heat_flux_into_soil_j_cm2_day
   receipt%conductive_face_energy_j_cm2(n+1)=-dt*r%bottom_heat_flux_into_soil_j_cm2_day
   do i=2,n
    receipt%conductive_face_energy_j_cm2(i)=dt*w%face_conductivity_j_cm_k_day(i)* &
          (w%solution(i-1)-w%solution(i))/p%distance_above_cm(i)
   end do
  end if
  receipt%available=.true.
 end subroutine
end module
