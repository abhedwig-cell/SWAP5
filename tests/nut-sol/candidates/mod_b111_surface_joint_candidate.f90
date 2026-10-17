! Standalone candidate, NOT an accepted production or historic-physics owner.
module mod_b111_surface_joint_candidate
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_surface_receipt_gate
 use mod_b111_surface_loss_budget
 implicit none
 private
 integer,parameter,public::JOINT_CANDIDATE_OK=0,JOINT_CANDIDATE_REJECTED=1
 type,public::joint_candidate_receipt_t
  integer::status=JOINT_CANDIDATE_REJECTED
  real(real64)::mass_end=0d0,soil_input=0d0,runoff_export=0d0,external_input=0d0
 end type
 public::evaluate_joint_surface_candidate
contains
 pure subroutine evaluate_joint_surface_candidate(w,initial_mass,rain_conc,irrigation_conc, &
       runon_conc,dry_deposition_rate,outcome)
  type(surface_gross_receipt_t),intent(in)::w
  real(real64),intent(in)::initial_mass,rain_conc,irrigation_conc,runon_conc,dry_deposition_rate
  type(joint_candidate_receipt_t),intent(out)::outcome
  type(surface_loss_receipt_t)::chemical
  integer::water_status
  real(real64)::water_residual,combined,combined_conc,dt
  outcome=joint_candidate_receipt_t()
  call check_surface_gross_receipt(w,water_status,water_residual)
  if(water_status/=SURFACE_RECEIPT_OK)return
  if(.not.all(ieee_is_finite([initial_mass,rain_conc,irrigation_conc,runon_conc,dry_deposition_rate])))return
  if(min(initial_mass,rain_conc,irrigation_conc,runon_conc,dry_deposition_rate)<0d0)return
  if(w%qtop>0d0)return
  dt=w%t1-w%t0
  combined=w%rain+w%runon
  combined_conc=0d0
  if(combined>0d0)combined_conc=(w%rain*rain_conc+w%runon*runon_conc)/combined
  call evaluate_surface_loss_budget(w%depth_begin,initial_mass,dt,combined,w%irrigation, &
       -w%qtop,w%evaporation,w%runoff,combined_conc,irrigation_conc,dry_deposition_rate,chemical)
  if(chemical%status/=SURFACE_LOSS_OK)return
  if(abs(chemical%depth_end-w%depth_end)>1d-10)return
  outcome%mass_end=chemical%mass_end
  outcome%soil_input=chemical%infiltrated_mass
  outcome%runoff_export=chemical%runoff_mass
  outcome%external_input=chemical%external_mass
  outcome%status=JOINT_CANDIDATE_OK
 end subroutine
end module
