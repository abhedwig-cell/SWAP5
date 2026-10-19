! MC-NUT01-GROSS01: experimental conservative gross-water / dissolved-N
! surface control volume. NOT the admitted historical soil-N interface.
module mod_b111_surface_n_gross_budget
 use, intrinsic :: iso_fortran_env, only: real64
 use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
 implicit none
 private
 integer,parameter,public::SURFACE_N_OK=0,SURFACE_N_INVALID=1,SURFACE_N_WATER_BALANCE=2, &
      SURFACE_N_MASS_BALANCE=3
 type,public::surface_n_gross_request_t
  real(real64)::pond_start_cm=0.0_real64,pond_end_cm=0.0_real64
  real(real64)::gross_rain_cm=0.0_real64,gross_irrigation_cm=0.0_real64,gross_runon_cm=0.0_real64
  real(real64)::infiltration_cm=0.0_real64,runoff_cm=0.0_real64,evaporation_cm=0.0_real64
  real(real64)::rain_n_kg_m2(2)=0.0_real64,irrigation_n_kg_m2(2)=0.0_real64
  real(real64)::runon_n_kg_m2(2)=0.0_real64
  real(real64)::pond_n_initial_kg_m2(2)=0.0_real64,dry_n_initial_kg_m2(2)=0.0_real64
 end type
 type,public::surface_n_gross_receipt_t
  integer::status=SURFACE_N_INVALID
  real(real64)::pond_n_final_kg_m2(2)=0.0_real64,dry_n_final_kg_m2(2)=0.0_real64
  real(real64)::soil_n_input_kg_m2(2)=0.0_real64,runoff_n_export_kg_m2(2)=0.0_real64
  real(real64)::external_n_input_kg_m2(2)=0.0_real64
  real(real64)::water_residual_cm=0.0_real64,n_residual_kg_m2(2)=0.0_real64
 end type
 public::evaluate_surface_n_gross_budget
contains
 pure subroutine evaluate_surface_n_gross_budget(f,r)
  type(surface_n_gross_request_t),intent(in)::f
  type(surface_n_gross_receipt_t),intent(out)::r
  real(real64)::old(2),gross(2),available(2),wet_end,wet_export,water_scale,n_scale
  r=surface_n_gross_receipt_t()
  if(.not.all(ieee_is_finite([f%pond_start_cm,f%pond_end_cm,f%gross_rain_cm, &
   f%gross_irrigation_cm,f%gross_runon_cm,f%infiltration_cm,f%runoff_cm, &
   f%evaporation_cm,f%rain_n_kg_m2,f%irrigation_n_kg_m2,f%runon_n_kg_m2, &
   f%pond_n_initial_kg_m2,f%dry_n_initial_kg_m2])))return
  if(minval([f%pond_start_cm,f%pond_end_cm,f%gross_rain_cm,f%gross_irrigation_cm, &
   f%gross_runon_cm,f%infiltration_cm,f%runoff_cm,f%evaporation_cm])<0.0_real64)return
  if(maxval([f%pond_start_cm,f%pond_end_cm,f%gross_rain_cm,f%gross_irrigation_cm, &
   f%gross_runon_cm,f%infiltration_cm,f%runoff_cm,f%evaporation_cm])>1.0e5_real64)return
  if(any([f%rain_n_kg_m2,f%irrigation_n_kg_m2,f%runon_n_kg_m2, &
   f%pond_n_initial_kg_m2,f%dry_n_initial_kg_m2]<0.0_real64))return
  if(any([f%rain_n_kg_m2,f%irrigation_n_kg_m2,f%runon_n_kg_m2, &
   f%pond_n_initial_kg_m2,f%dry_n_initial_kg_m2]>1.0e4_real64))return
  if(f%pond_start_cm<=0.0_real64.and.any(f%pond_n_initial_kg_m2>0.0_real64))return
  r%water_residual_cm=f%pond_end_cm-f%pond_start_cm-f%gross_rain_cm- &
     f%gross_irrigation_cm-f%gross_runon_cm+f%infiltration_cm+f%runoff_cm+f%evaporation_cm
  water_scale=max(1.0_real64,f%pond_start_cm,f%pond_end_cm,f%gross_rain_cm, &
     f%gross_irrigation_cm,f%gross_runon_cm,f%infiltration_cm,f%runoff_cm,f%evaporation_cm)
  if(abs(r%water_residual_cm)>1.0e-10_real64*water_scale)then
    r%status=SURFACE_N_WATER_BALANCE
    return
  end if
  old=f%pond_n_initial_kg_m2+f%dry_n_initial_kg_m2
  gross=f%rain_n_kg_m2+f%irrigation_n_kg_m2+f%runon_n_kg_m2
  r%external_n_input_kg_m2=gross
  available=old+gross
  wet_end=f%pond_end_cm
  wet_export=f%infiltration_cm+f%runoff_cm
  ! Water evaporation cannot export dissolved N. With zero remaining
  ! water and no liquid exports, inventory is retained as dry deposited N.
  ! Instantaneous full mixing is a candidate policy, not historical admission.
  if(wet_end+wet_export>0.0_real64)then
    r%pond_n_final_kg_m2=available*wet_end/(wet_end+wet_export)
    r%soil_n_input_kg_m2=available*f%infiltration_cm/(wet_end+wet_export)
    r%runoff_n_export_kg_m2=available*f%runoff_cm/(wet_end+wet_export)
  else
    r%dry_n_final_kg_m2=available
  end if
  r%n_residual_kg_m2=r%pond_n_final_kg_m2+r%dry_n_final_kg_m2+ &
     r%soil_n_input_kg_m2+r%runoff_n_export_kg_m2-old-gross
  n_scale=max(1.0_real64,maxval(abs(available)))
  if(.not.all(ieee_is_finite(r%n_residual_kg_m2)))return
  if(maxval(abs(r%n_residual_kg_m2))>8192.0_real64*epsilon(1.0_real64)*n_scale)then
    r%status=SURFACE_N_MASS_BALANCE
    return
  end if
  r%status=SURFACE_N_OK
 end subroutine
end module
