program test_wofost81_leaf_structural_evolution
  use iso_fortran_env, only: real64
  use mod_wofost_crop_owner_state
  use mod_wofost_one_day_structural_evolution
  use mod_wofost81_leaf_structural_evolution
  implicit none
  type(wofost_crop_owner_state_t)::c
  type(wofost_one_day_rate_packet_t)::r
  type(wofost81_leaf_structure_diagnostics_t)::d
  integer::status
  call setup(c)
  r%leaf_stress_death_rate=10; r%leaf_growth_rate=5; r%youngest_specific_leaf_area=.02_real64
  r%leaf_age_increment=.5_real64; r%lai_exponential_growth_rate=.4_real64; r%lai_exponential_rate_recomputed=.true.
  call apply_wofost81_leaf_structural_update(c,r,d,status)
  call check(status==WOFOST81_LEAF_STRUCTURE_OK,'basic update')
  call check(size(c%biomass%leaf_biomass)==4,'cohort count shift')
  call check(all(abs(c%biomass%leaf_biomass-[5._real64,30._real64,30._real64,30._real64])<1e-14_real64),'oldest-only death')
  call check(all(abs(c%biomass%leaf_age-[0._real64,1.5_real64,3.5_real64,5.5_real64])<1e-14_real64),'age shift')
  call check(abs(d%applied_leaf_death-10._real64)<1e-14_real64,'applied death')
  ! Crucial preservation: the >SPAN cohorts survive unless already represented in combined DRLV.
  call check(c%biomass%leaf_biomass(4)>0._real64,'no second over-age sweep')
  call check(abs(c%biomass%exponential_leaf_area_index-.9_real64)<1e-14_real64,'GLAIEXP update')

  call setup(c); c%biomass%exponential_leaf_area_index=5.9_real64
  r%leaf_stress_death_rate=0; r%lai_exponential_growth_rate=.2_real64; r%leaf_growth_rate=0
  call apply_wofost81_leaf_structural_update(c,r,d,status)
  call check(status==0.and.d%captured_lai_exponential_carryover,'carryover captured')
  call check(allocated(c%b110_reference_compatibility),'carryover allocated')
  call check(abs(c%b110_reference_compatibility%lai_exponential_rate_carryover-.2_real64)<1e-14_real64,'carryover value')

  r%lai_exponential_rate_recomputed=.false.; r%lai_exponential_growth_rate=0
  call apply_wofost81_leaf_structural_update(c,r,d,status)
  call check(status==0.and.d%used_lai_exponential_carryover,'carryover reused')
  call check(abs(c%biomass%exponential_leaf_area_index-6.3_real64)<1e-14_real64,'carryover GLAIEXP')

  print '(A)','F_WOF_PP02_LEAF_STRUCTURE_PASS'
contains
  subroutine setup(x)
    type(wofost_crop_owner_state_t),intent(out)::x
    x%crop_emerged=.true.; x%development_stage=.1_real64; allocate(x%biomass)
    x%biomass%leaf_biomass=[30._real64,30._real64,40._real64]
    x%biomass%specific_leaf_area=[.02_real64,.02_real64,.02_real64]
    x%biomass%leaf_age=[1._real64,3._real64,5._real64]
    x%biomass%exponential_leaf_area_index=.5_real64
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok; character(len=*),intent(in)::label
    if(.not.ok) then; print '(A)',trim(label)//' failed'; error stop 1; endif
  end subroutine
end program
