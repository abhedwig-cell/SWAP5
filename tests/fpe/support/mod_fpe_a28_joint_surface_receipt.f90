! EXTERNAL_SUPPLY_PARTITION_V1_RESEARCH, not general ponded RFM physics.
module mod_fpe_a28_joint_surface_receipt
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_is_finite
 use mod_soil_water_solver_contract,only:soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE
 use mod_rfm_unponded_activation,only:rfm_unponded_activation_result_t,RFM_ACTIVATION_AVAILABLE
 use mod_rfm_unponded_surface_composition,only:rfm_unponded_surface_composition_result_t, &
      RFM_SURFACE_COMPOSITION_AVAILABLE,RFM_SURFACE_COMPOSITION_INVALID
 implicit none
 private
 public::compose_external_supply_partition,materialize_joint_surface_receipt
contains
 pure subroutine compose_external_supply_partition(p,a,tol,r)
  type(soil_water_top_boundary_result_t),intent(in)::p
  type(rfm_unponded_activation_result_t),intent(in)::a
  real(real64),intent(in)::tol
  type(rfm_unponded_surface_composition_result_t),intent(out)::r
  real(real64)::v(6),residual
  r=rfm_unponded_surface_composition_result_t();r%status=RFM_SURFACE_COMPOSITION_INVALID
  if(.not.ieee_is_finite(tol))return
  if(tol<0.)return
  if(p%status/=SW_TOP_BOUNDARY_AVAILABLE.or.a%status/=RFM_ACTIVATION_AVAILABLE)return
  if(.not.p%carries_surface_mass_terms.or..not.p%runoff_resolved)return
  v=[p%net_potential_surface_flux,a%matrix_rate_cm_per_day,a%preferential_rate_cm_per_day,a%preferential_fraction, &
     p%candidate_ponding_depth,p%runoff_depth]
  if(.not.all(ieee_is_finite(v)))return
  if(any(v<0.).or.a%preferential_fraction>1.)return
  residual=v(1)-v(2)-v(3)
  if(abs(residual)>tol)return
  r%effective_supply_cm_per_day=v(1);r%matrix_supply_cm_per_day=v(2)
  r%preferential_supply_cm_per_day=v(3);r%partition_residual_cm_per_day=residual
  r%status=RFM_SURFACE_COMPOSITION_AVAILABLE
 end subroutine

 pure subroutine materialize_joint_surface_receipt(rain,pref,dt,oldpond,newpond,qtop,runoff,tol,external_in,external_out,residual,ok)
  real(real64),intent(in)::rain,pref,dt,oldpond,newpond,qtop,runoff,tol
  real(real64),intent(out)::external_in,external_out,residual
  logical,intent(out)::ok
  real(real64)::v(8)
  external_in=0.;external_out=0.;residual=0.;ok=.false.
  v=[rain,pref,dt,oldpond,newpond,qtop,runoff,tol]
  if(.not.all(ieee_is_finite(v)))return
  if(rain<0..or.pref<0..or.dt<=0..or.oldpond<0..or.newpond<0..or.runoff<0..or.tol<0.)return
  if(pref>rain)return
  external_in=rain*dt;external_out=runoff
  residual=(rain-pref)*dt+qtop*dt+oldpond-newpond-runoff
  if(.not.all(ieee_is_finite([external_in,external_out,residual])))return
  ok=abs(residual)<=tol
 end subroutine
end module
