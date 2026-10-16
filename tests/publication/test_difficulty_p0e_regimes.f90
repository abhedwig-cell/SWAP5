program test_difficulty_p0e_regimes
 use, intrinsic::iso_fortran_env,only:real64
 use mod_difficulty_pretrial_descriptors
 use mod_difficulty_regime_selector
 implicit none
 type(difficulty_pretrial_descriptors_t)::d
 type(difficulty_regime_evidence_t)::e
 type(difficulty_regime_thresholds_t)::t
 d%available=.true.; d%top_flux_ratio_available=.true.; d%abs_top_flux_over_surface_k=0.1; d%grad_h_max=0.1; d%h_max=-10; e%forcing_available=.true.
 call req(classify_difficulty_regime(d,e,t)==DIFF_R1,'R1')
 d%h_max=-200; d%abs_top_flux_over_surface_k=2; e%top_flux=1; call req(classify_difficulty_regime(d,e,t)==DIFF_R2,'R2')
 d%grad_logk_max=1; call req(classify_difficulty_regime(d,e,t)==DIFF_R3,'R3')
 d%grad_logk_max=0; d%h_max=-0.5; call req(classify_difficulty_regime(d,e,t)==DIFF_R4,'R4')
 d%h_max=-10; d%abs_top_flux_over_surface_k=0.1; e%top_flux=-1; call req(classify_difficulty_regime(d,e,t)==DIFF_R5,'R5')
 e%boundary_distance_available=.true.; e%boundary_distance=0; call req(classify_difficulty_regime(d,e,t)==DIFF_R6,'R6 priority')
 write(*,'(A)') 'DIFFICULTY_P0E_OUTCOME_BLIND_REGIMES=PASS'
contains
 subroutine req(x,s); logical,intent(in)::x; character(len=*),intent(in)::s
 if(.not.x) then; write(*,*)'FAIL ',s; error stop 1; endif
 end subroutine
end program
