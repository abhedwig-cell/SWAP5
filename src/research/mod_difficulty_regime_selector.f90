module mod_difficulty_regime_selector
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_difficulty_pretrial_descriptors, only: difficulty_pretrial_descriptors_t
  implicit none
  private
  integer,parameter,public::DIFF_R_NONE=0,DIFF_R1=1,DIFF_R2=2,DIFF_R3=3,DIFF_R4=4,DIFF_R5=5,DIFF_R6=6
  type,public::difficulty_regime_thresholds_t
    real(real64)::r1_grad_h_max=0.25_real64
    real(real64)::r1_flux_ratio_max=0.25_real64
    real(real64)::r2_h_surface_max=-100.0_real64
    real(real64)::r2_flux_ratio_min=1.0_real64
    real(real64)::r3_grad_logk_min=0.5_real64
    real(real64)::r4_h_max_min=-1.0_real64
    real(real64)::r5_h_surface_min=-100.0_real64
    real(real64)::r5_top_flux_max=-0.1_real64
    real(real64)::r6_boundary_distance_max=0.05_real64
  end type
  type,public::difficulty_regime_evidence_t
    logical::forcing_available=.false.
    real(real64)::top_flux=0
    logical::boundary_distance_available=.false.
    real(real64)::boundary_distance=0
  end type
  public::classify_difficulty_regime
contains
  pure integer function classify_difficulty_regime(d,e,t) result(r)
    type(difficulty_pretrial_descriptors_t),intent(in)::d
    type(difficulty_regime_evidence_t),intent(in)::e
    type(difficulty_regime_thresholds_t),intent(in)::t
    r=DIFF_R_NONE
    if(.not.d%available) return
    ! Priority is frozen and outcome-independent: switching neighbourhood, near saturation,
    ! established front, dry infiltration, drying, then benign control.
    if(e%boundary_distance_available) then
      if(abs(e%boundary_distance)<=t%r6_boundary_distance_max) then; r=DIFF_R6; return; endif
    endif
    if(d%h_max>=t%r4_h_max_min) then; r=DIFF_R4; return; endif
    if(d%grad_logk_max>=t%r3_grad_logk_min) then; r=DIFF_R3; return; endif
    if(e%forcing_available.and.d%top_flux_ratio_available) then
      if(d%h_max<=t%r2_h_surface_max.and.e%top_flux>0.and.d%abs_top_flux_over_surface_k>=t%r2_flux_ratio_min) then; r=DIFF_R2; return; endif
      if(d%h_max>=t%r5_h_surface_min.and.e%top_flux<t%r5_top_flux_max) then; r=DIFF_R5; return; endif
    endif
    if(d%grad_h_max<=t%r1_grad_h_max.and.(.not.d%top_flux_ratio_available.or.d%abs_top_flux_over_surface_k<=t%r1_flux_ratio_max)) r=DIFF_R1
  end function
end module
