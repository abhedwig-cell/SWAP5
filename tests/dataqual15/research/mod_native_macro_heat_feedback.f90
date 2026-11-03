module mod_native_macro_heat_feedback
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_temperature_contract
 use mod_restricted_soil_temperature,only:trial_restricted_soil_temperature
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_reference_linear_solver,only:reference_tridag
 use mod_macro_liquid_thermal
 implicit none
 private
 type,public::native_heat_feedback_result_t
  logical::produced=.false.
  integer::iterations=0
  real(real64),allocatable::matrix_temperature_c(:),macro_temperature_c(:,:),macro_energy_to_matrix_j_cm2(:,:)
  real(real64)::matrix_storage_change_j_cm2=0d0,macro_storage_change_j_cm2=0d0
  real(real64)::conductive_boundary_into_j_cm2=0d0,macro_external_into_j_cm2=0d0
  real(real64)::water_roundoff_energy_j_cm2=0d0,joint_residual_j_cm2=0d0,max_nodal_residual_j_cm2=0d0
 end type
 public::trial_native_macro_heat_feedback
contains
 subroutine trial_native_macro_heat_feedback(p,control,f,h0,h1,matrix_initial,w0,w1,faces,exchange,external_out, &
    macro_initial,initial_available,top0,top1,top_available,bottom0,bottom1,bottom_available,t0,t1,slices,result)
  type(soil_temperature_parameters_t),intent(in)::p
  type(soil_temperature_numerical_config_t),intent(in)::control
  type(soil_temperature_forcing_t),intent(in)::f
  type(process_hydraulic_view_t),intent(in)::h0,h1
  type(soil_temperature_state_t),intent(in)::matrix_initial
  real(real64),intent(in)::w0(:,:),w1(:,:),faces(:,:),exchange(:,:),external_out(:,:),macro_initial(:,:)
  logical,intent(in)::initial_available(:,:),top_available(:),bottom_available(:)
  real(real64),intent(in)::top0(:),top1(:),bottom0(:),bottom1(:),t0,t1
  integer,intent(in)::slices
  type(native_heat_feedback_result_t),intent(out)::result
  type(soil_temperature_workspace_t)::w
  type(soil_temperature_state_t)::baseline
  type(soil_temperature_result_t)::base_result
  type(soil_temperature_diagnostics_t)::diagnostic
  type(macro_liquid_thermal_result_t)::macro
  real(real64),allocatable::lower(:),diagonal(:),upper(:),rhs(:),guess(:),solution(:),gamma(:),source(:),residual(:)
  logical,allocatable::matrix_available(:)
  real(real64)::dt,coefficient,boundary,top_flux,bottom_flux,energy_tolerance
  integer::n,it,status,i
  result=native_heat_feedback_result_t()
  if(p%solution_mode/=SOIL_TEMP_SOLUTION_NUMERIC)return
  if(f%top_boundary_mode==SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION)return
  call trial_restricted_soil_temperature(p,control,f,h0,h1,matrix_initial,t0,t1,w,baseline,base_result,diagnostic)
  if(base_result%status/=SOIL_TEMP_OK.or..not.base_result%produced)return
  n=p%active_nodes;dt=t1-t0
  allocate(lower(n),diagonal(n),upper(n),rhs(n),guess(n),solution(n),gamma(n),source(n),residual(n),matrix_available(n))
  lower=w%lower;upper=w%upper;diagonal=w%heat_capacity_j_cm3_k-lower-upper
  rhs=w%heat_capacity_j_cm3_k*w%old_temperature_c;matrix_available=.true.
  select case(f%top_boundary_mode)
  case(SOIL_TEMP_TOP_AIR_TEMPERATURE,SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE)
   coefficient=dt*w%face_conductivity_j_cm_k_day(1)/(p%dz_cm(1)*p%distance_above_cm(1))
   diagonal(1)=diagonal(1)+coefficient;rhs(1)=rhs(1)+coefficient*base_result%surface_temperature_c
  case(SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX)
   rhs(1)=rhs(1)+dt*f%prescribed_top_heat_flux_j_cm2_day/p%dz_cm(1)
  case default
   return
  end select
  if(f%bottom_boundary_mode==SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE)then
   coefficient=dt*w%node_conductivity_j_cm_k_day(n)/(p%dz_cm(n)*.5d0*p%dz_cm(n))
   diagonal(n)=diagonal(n)+coefficient;rhs(n)=rhs(n)+coefficient*f%prescribed_bottom_temperature_c
  end if
  guess=w%solution
  do it=1,60
   call advance_macro_liquid_thermal(w0,w1,faces,exchange,external_out,macro_initial,initial_available, &
       w%old_temperature_c,guess,matrix_available,top0,top1,top_available,bottom0,bottom1,bottom_available,dt,slices,4.18d0,macro)
   if(.not.macro%produced)return
   source=sum(macro%matrix_energy_j_cm2,dim=1)
   call reference_tridag(n,lower,diagonal,upper,rhs+source/p%dz_cm,solution,gamma,status,capture_in_gamma_requested=.false.)
   if(status/=0.or.any(.not.ieee_is_finite(solution)))return
   if(maxval(abs(solution-guess))<=1d-11)exit
   guess=solution
  end do
  if(it>60)return
  residual=diagonal*solution-rhs-source/p%dz_cm
  do i=2,n;residual(i)=residual(i)+lower(i)*solution(i-1);end do
  do i=1,n-1;residual(i)=residual(i)+upper(i)*solution(i+1);end do
  result%max_nodal_residual_j_cm2=maxval(abs(residual*p%dz_cm))
  top_flux=f%prescribed_top_heat_flux_j_cm2_day
  if(f%top_boundary_mode/=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX)top_flux=w%face_conductivity_j_cm_k_day(1)* &
      (base_result%surface_temperature_c-solution(1))/p%distance_above_cm(1)
  bottom_flux=0d0
  if(f%bottom_boundary_mode==SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE)bottom_flux=w%node_conductivity_j_cm_k_day(n)* &
      (f%prescribed_bottom_temperature_c-solution(n))/(.5d0*p%dz_cm(n))
  result%matrix_storage_change_j_cm2=sum(w%heat_capacity_j_cm3_k*p%dz_cm*(solution-w%old_temperature_c))
  result%macro_storage_change_j_cm2=macro%stock_change_j_cm2
  result%conductive_boundary_into_j_cm2=dt*(top_flux+bottom_flux)
  result%macro_external_into_j_cm2=macro%external_net_into_j_cm2
  result%water_roundoff_energy_j_cm2=macro%water_ledger_roundoff_energy_j_cm2
  result%joint_residual_j_cm2=result%matrix_storage_change_j_cm2+result%macro_storage_change_j_cm2- &
      result%conductive_boundary_into_j_cm2-result%macro_external_into_j_cm2-result%water_roundoff_energy_j_cm2
  energy_tolerance=control%energy_abs_tolerance_j_cm2
  if(result%max_nodal_residual_j_cm2>energy_tolerance.or.abs(result%joint_residual_j_cm2)>energy_tolerance)return
  result%matrix_temperature_c=solution;result%macro_temperature_c=macro%temperature_c
  result%macro_energy_to_matrix_j_cm2=macro%matrix_energy_j_cm2;result%iterations=it;result%produced=.true.
 end subroutine
end module
