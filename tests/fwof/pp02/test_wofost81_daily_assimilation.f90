program test_wofost81_daily_assimilation
  use iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_wofost81_daily_parameter_contract
  use mod_wofost81_n_owner_state, only: wofost81_n_owner_state_t
  use mod_wofost81_prepare_assimilation
  use MOD_wofost81_assimilation, only: totass81
  implicit none
  type(wofost81_daily_parameter_contract_t) :: p
  type(wofost_rate_parameter_bundle_t) :: common
  type(wofost_one_day_rate_state_view_t) :: state
  type(wofost81_n_owner_state_t) :: n
  type(wofost_one_day_forcing_t) :: forcing
  type(wofost81_prepare_assimilation_result_t) :: got
  real(real64) :: dtga, expected, eff, kdif
  integer :: status

  p%base%assimilation%amax_lnb=0._real64; p%base%assimilation%amax_ref=35._real64
  p%base%assimilation%amax_slp=3.24_real64; p%base%assimilation%kn=.4_real64
  p%base%nitrogen%nmaxst_fr=.5_real64
  p%base%nitrogen%nmaxrt_fr=.5_real64
  p%base%nitrogen%nmaxso=.0176_real64
  p%base%nitrogen%nresidlv=.004_real64
  p%base%nitrogen%nresidst=.002_real64
  p%base%nitrogen%nresidrt=.002_real64
  p%base%nitrogen%tcnt=10._real64
  p%base%nitrogen%nfix_fr=.2_real64
  p%base%nitrogen%rnuptakemax=4.26_real64
  p%base%nitrogen%dvs_n_transl=.8_real64
  p%base%nitrogen%rgrlai_min=.004_real64

  call construct_wofost_rate_table([0._real64,20._real64,40._real64], &
       [.2_real64,.4_real64,.6_real64],p%tables%light_use_efficiency,status)
  call check(status==0,'EFF table')
  call construct_wofost_rate_table([0._real64,1._real64,2._real64], &
       [.4_real64,.5_real64,.6_real64],p%tables%diffuse_extinction_coefficient,status)
  call check(status==0,'KDIF table')
  call construct_wofost_rate_table([0._real64,.4_real64,.7_real64,1._real64,2._real64], &
       [.06_real64,.04_real64,.03_real64,.02_real64,.016_real64], &
       p%tables%maximum_leaf_n_concentration,status)
  call check(status==0,'NMAX table')
  call construct_wofost_rate_table([0._real64,1.1_real64,1.5_real64,2._real64,2.5_real64], &
       [1._real64,1._real64,1.4_real64,1.5_real64,1.5_real64], &
       p%tables%leaf_ageing_n_stress_multiplier,status)
  call check(status==0,'NSLLV table')
  call check(p%validate()==WOFOST81_DAILY_PARAMETER_OK,'daily contract valid')
  call p%evaluate_maximum_leaf_n_concentration(.7_real64,expected,status)
  call check(status==0 .and. abs(expected-.03_real64)<1e-15_real64,'NMAX eval')
  call p%evaluate_leaf_ageing_n_stress_multiplier(1.5_real64,expected,status)
  call check(status==0 .and. abs(expected-1.4_real64)<1e-15_real64,'NSLLV eval')

  state%development_stage=.7_real64
  state%actual_leaf_area_index=4._real64
  state%living_leaf_biomass=3000._real64
  state%actual_root_biomass=600._real64
  state%actual_stem_biomass=1200._real64
  state%actual_storage_biomass=100._real64
  state%exponential_leaf_area_index=4._real64
  n%value%namountlv=140._real64
  n%value%namountst=10._real64
  n%value%namountrt=8._real64
  n%value%namountso=2._real64
  n%value%initial_total=160._real64
  forcing%minimum_temperature=5._real64
  forcing%average_temperature=5._real64
  forcing%daytime_average_temperature=30._real64
  forcing%global_radiation=18.e6_real64
  forcing%daylength_hours=12._real64
  forcing%photoperiodic_daylength_hours=12._real64
  forcing%sinld=.6_real64
  forcing%cosld=.4_real64
  forcing%diffuse_perpendicular_radiation=120._real64
  forcing%daily_sine_solar_elevation_integral=30000._real64
  forcing%co2_efficiency_factor=1.1_real64
  forcing%co2_amax_factor=1.2_real64

  call prepare_wofost81_actual_assimilation(state,common,p,n,forcing,2._real64,got,status)
  call check(status==WOFOST81_PREPARE_ASSIMILATION_OK,'prepare status')
  eff=.5_real64 ! EFFTB queried at daytime_average_temperature=30
  kdif=.47_real64 ! KDIFTB queried at DVS=.7
  call totass81(0._real64,35._real64,3.24_real64,12._real64,1.2_real64,.5_real64, &
       1.1_real64*eff,.4_real64,4._real64,140._real64,kdif,18.e6_real64, &
       120._real64,30000._real64,.6_real64,.4_real64,dtga)
  expected=dtga*(2._real64/3._real64)*30._real64*(.4_real64/.7_real64)/44._real64
  call check(abs(got%actual_pgass-expected)<=2e-12_real64*max(1._real64,abs(expected)),'source-faithful wrapper')
  call check(abs(got%light_use_efficiency-eff)<1e-15_real64,'EFF query uses TAVD')
  call check(abs(got%diffuse_extinction_coefficient-kdif)<1e-15_real64,'KDIF query uses DVS')

  state%actual_leaf_area_index=0._real64
  call prepare_wofost81_actual_assimilation(state,common,p,n,forcing,2._real64,got,status)
  call check(status==0 .and. abs(got%actual_pgass)<1e-30_real64,'zero LAI')

  print '(A)', 'F_WOF_PP02_DAILY_ASSIMILATION_PASS'
contains
  subroutine check(ok,label)
    logical,intent(in)::ok; character(len=*),intent(in)::label
    if(.not.ok) then; print '(A)',trim(label)//' failed'; error stop 1; endif
  end subroutine
end program
