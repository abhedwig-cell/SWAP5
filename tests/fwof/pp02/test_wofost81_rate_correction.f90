program test_wofost81_rate_correction
  use iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table
  use mod_wofost_one_day_rate_state_view
  use mod_wofost_one_day_structural_evolution
  use mod_wofost81_daily_parameter_contract
  use mod_wofost81_n_owner_state
  use mod_wofost81_rate_correction
  implicit none
  type(wofost81_daily_parameter_contract_t)::p
  type(wofost81_n_owner_state_t)::n
  type(wofost_one_day_rate_state_view_t)::s
  type(wofost_one_day_rate_packet_t)::base,got
  type(wofost81_rate_correction_diagnostics_t)::d
  real(real64)::b(3),a(3), expected_idx,expected_rfr,expected_nsllv,expected_dalv
  integer::status
  call setup_parameters(p,status); call check(status==0,'setup parameters')
  s%development_stage=.1_real64; s%actual_stem_biomass=50; s%actual_storage_biomass=0
  s%living_leaf_biomass=100; s%actual_leaf_area_index=.5_real64; s%exponential_leaf_area_index=.5_real64
  n%value%namountlv=2.0_real64; n%value%namountst=.5_real64; n%value%namountso=0
  n%value%initial_total=2.5_real64
  b=[30._real64,30._real64,40._real64]; a=[1._real64,3._real64,5._real64]
  base%leaf_stress_death_rate=10; base%leaf_growth_rate=10; base%youngest_specific_leaf_area=.4_real64
  base%lai_exponential_growth_rate=4; base%relative_transpiration_used=1
  call correct_wofost81_leaf_rates(s,b,a,2._real64,1._real64,.03_real64,.true.,p,n,base,got,d,status)
  call check(status==WOFOST81_RATE_CORRECTION_OK,'active correction')
  expected_idx=1.7_real64 ! max N=100*.03 +50*.5*.03 =3.75; / actual 2.5 =1.5, corrected below
  expected_idx=1.5_real64
  expected_nsllv=1.4_real64
  expected_dalv=min(70._real64*expected_nsllv,100._real64)
  call check(abs(d%nstress_index_dlv-expected_idx)<1e-14_real64,'stress index')
  call check(abs(d%leaf_ageing_n_stress_multiplier-expected_nsllv)<1e-14_real64,'NSLLV')
  call check(abs(got%leaf_stress_death_rate-expected_dalv)<1e-14_real64,'DRLV=max(DSLV,DALV)')
  expected_rfr=1._real64-(1._real64-0._real64)*(.03_real64-.004_real64)/.03_real64
  call check(abs(d%rfrgrl-expected_rfr)<1e-14_real64,'RFRGRL')
  call check(abs(got%lai_exponential_growth_rate-4._real64*expected_rfr)<1e-14_real64,'juvenile GLAIEX')
  call check(abs(got%youngest_specific_leaf_area-(4._real64*expected_rfr/10._real64))<1e-14_real64,'juvenile SLA')
  call check(d%juvenile_lai_n_stress_applied,'juvenile stress diagnostic')
  base%leaf_stress_death_rate=120
  call correct_wofost81_leaf_rates(s,b,a,2._real64,1._real64,.03_real64,.true.,p,n,base,got,d,status)
  call check(status==0.and.abs(got%leaf_stress_death_rate-120._real64)<1e-14_real64,'DSLV dominates')
  s%development_stage=.3_real64; base%leaf_stress_death_rate=10; base%lai_exponential_growth_rate=4
  call correct_wofost81_leaf_rates(s,b,a,2._real64,1._real64,.03_real64,.true.,p,n,base,got,d,status)
  call check(status==0.and.abs(got%lai_exponential_growth_rate-4._real64)<1e-14_real64,'post-juvenile GLAI unchanged')
  s%development_stage=.1_real64
  call correct_wofost81_leaf_rates(s,b,a,2._real64,1._real64,.03_real64,.false.,p,n,base,got,d,status)
  call check(status==0.and.abs(d%leaf_ageing_n_stress_multiplier-1._real64)<1e-14_real64,'inactive N NSLLV default')
  call check(abs(d%rfrgrl-1._real64)<1e-14_real64,'inactive N RFRGRL default')
  call check(abs(got%leaf_stress_death_rate-70._real64)<1e-14_real64,'inactive N WOFOST81 ageing still active')
  call correct_wofost81_leaf_rates(s,b(1:2),a,2._real64,1._real64,.03_real64,.true.,p,n,base,got,d,status)
  call check(status==WOFOST81_RATE_CORRECTION_INVALID_LEAF_COHORTS,'shape mismatch rejected')
  print '(A)','F_WOF_PP02_RATE_CORRECTION_PASS'
contains
  subroutine setup_parameters(q,st)
    type(wofost81_daily_parameter_contract_t),intent(out)::q; integer,intent(out)::st
    q%base%assimilation%amax_ref=35; q%base%assimilation%amax_slp=3.24_real64; q%base%assimilation%kn=.4_real64
    q%base%nitrogen%nmaxst_fr=.5_real64; q%base%nitrogen%nmaxrt_fr=.5_real64; q%base%nitrogen%nmaxso=.0176_real64
    q%base%nitrogen%nresidlv=.004_real64; q%base%nitrogen%nresidst=.002_real64; q%base%nitrogen%nresidrt=.002_real64
    q%base%nitrogen%tcnt=10; q%base%nitrogen%nfix_fr=0; q%base%nitrogen%rnuptakemax=7.2_real64
    q%base%nitrogen%dvs_n_transl=.8_real64; q%base%nitrogen%rgrlai_min=.004_real64
    call construct_wofost_rate_table([0._real64,40._real64],[.4_real64,.4_real64],q%tables%light_use_efficiency,st)
    call construct_wofost_rate_table([0._real64,2._real64],[.44_real64,.44_real64],q%tables%diffuse_extinction_coefficient,st)
    call construct_wofost_rate_table([0._real64,2._real64],[.03_real64,.03_real64],q%tables%maximum_leaf_n_concentration,st)
    call construct_wofost_rate_table([0._real64,1.1_real64,1.5_real64,2._real64,2.5_real64], &
      [1._real64,1._real64,1.4_real64,1.5_real64,1.5_real64],q%tables%leaf_ageing_n_stress_multiplier,st)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok; character(len=*),intent(in)::label
    if(.not.ok) then; print '(A)',trim(label)//' failed'; error stop 1; endif
  end subroutine
end program
