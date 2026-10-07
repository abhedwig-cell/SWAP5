program test_swap431_grass_management
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_grass_management_owner
  implicit none

  type(grass_management_parameters_t) :: p, invalid_p
  type(grass_management_state_t) :: m0, m1
  type(wofost_crop_owner_state_t) :: crop
  type(grass_management_forcing_t) :: f
  type(grass_management_result_t) :: r
  integer :: status
  real(real64), parameter :: tol=1.0e-10_real64
  real(real64) :: before_total, after_total, fixed_grazing_loss

  allocate(p%event_sequence(2))
  p%event_sequence=[GRASS_EVENT_MOW,GRASS_EVENT_GRAZE]
  p%trigger_mode=GRASS_TRIGGER_BIOMASS
  p%maximum_growth_days_mowing=20
  p%maximum_growth_days_grazing=20
  p%mowing_residual_biomass=50.0_real64
  p%mowing_loss_enabled=.true.
  p%grazing_uptake_per_day=10.0_real64
  p%grazing_fixed_loss_per_day=2.0_real64
  p%grazing_residual_biomass=20.0_real64
  p%grazing_days=2
  p%grazing_loss_enabled=.true.
  p%dewooling_residual_biomass=15.0_real64
  call make([1.0_real64,366.0_real64],[1.0_real64,1.0_real64],p%mowing_biomass_trigger_by_day)
  call make([1.0_real64,366.0_real64],[1.0_real64,1.0_real64],p%grazing_biomass_trigger_by_day)
  call make([-1000.0_real64,0.0_real64],[0.1_real64,0.1_real64],p%mowing_loss_fraction_by_head)
  call make([0.0_real64,100.0_real64],[1.0_real64,3.0_real64],p%mowing_delay_by_removed_biomass)
  call make([-1000.0_real64,0.0_real64],[0.1_real64,0.1_real64],p%grazing_treading_loss_fraction_by_head)
  call make([0.0_real64,2.0_real64],[0.6_real64,0.6_real64],p%leaf_partition_by_dvs)
  call make([0.0_real64,2.0_real64],[0.4_real64,0.4_real64],p%stem_partition_by_dvs)
  call make([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],p%specific_leaf_area_by_dvs)
  if(.not.p%ready()) error stop 1

  crop%crop_emerged=.true.
  crop%development_stage=0.5_real64
  allocate(crop%biomass)
  crop%biomass%root_biomass=20.0_real64
  crop%biomass%stem_biomass=40.0_real64
  crop%biomass%storage_biomass=0.0_real64
  crop%biomass%exponential_leaf_area_index=1.2_real64
  crop%biomass%leaf_biomass=[40.0_real64,20.0_real64]
  crop%biomass%specific_leaf_area=[0.02_real64,0.02_real64]
  crop%biomass%leaf_age=[1.0_real64,3.0_real64]
  if(crop%validate()/=WOFOST_CROP_OWNER_OK) error stop 2

  call initialize_grass_management_state(p,.false.,100.0_real64,m0,status)
  if(status/=GRASS_MGMT_OK) error stop 3
  m0%dead_leaf_biomass=6.0_real64
  m0%dead_stem_biomass=4.0_real64

  f%current_time_day=101.0_real64
  f%day_of_year=150
  f%mowing_average_head_cm=-200.0_real64
  f%grazing_average_head_cm=-200.0_real64

  before_total=crop%biomass%stem_biomass+crop%biomass%living_leaf_biomass()+ &
       crop%biomass%storage_biomass+m0%dead_leaf_biomass+m0%dead_stem_biomass
  call evaluate_grass_management_day(p,m0,crop,f,r,status)
  if(status/=GRASS_MGMT_OK) error stop 4
  if(.not.r%harvest_event.or.r%crop_growth_may_continue) error stop 5
  if(abs(r%harvested_biomass-54.0_real64)>tol) error stop 6
  if(abs(r%lost_biomass-6.0_real64)>tol) error stop 7
  if(abs(r%removed_total_biomass-60.0_real64)>tol) error stop 8
  if(r%candidate_management%event_index/=2.or.r%candidate_management%days_since_cut/=0) error stop 9
  if(r%candidate_management%growth_delay_days/=2) error stop 10
  if(abs(r%candidate_management%dead_leaf_biomass)>tol.or. &
     abs(r%candidate_management%dead_stem_biomass)>tol) error stop 11
  if(abs(r%candidate_crop%biomass%living_leaf_biomass()-30.0_real64)>tol) error stop 12
  if(abs(r%candidate_crop%biomass%stem_biomass-20.0_real64)>tol) error stop 13
  if(size(r%candidate_crop%biomass%leaf_biomass)/=2) error stop 14
  if(abs(r%candidate_crop%biomass%leaf_biomass(2))>tol) error stop 15
  if(abs(r%candidate_crop%biomass%specific_leaf_area(1)-0.02_real64)>tol) error stop 16
  after_total=r%candidate_crop%biomass%stem_biomass+r%candidate_crop%biomass%living_leaf_biomass()+ &
       r%candidate_crop%biomass%storage_biomass+r%candidate_management%dead_leaf_biomass+ &
       r%candidate_management%dead_stem_biomass
  if(abs((before_total-after_total)-r%removed_total_biomass)>tol) error stop 17

  ! First grazing day is full and keeps the event active.
  m1=r%candidate_management
  crop=r%candidate_crop
  f%current_time_day=102.0_real64
  before_total=crop%biomass%stem_biomass+crop%biomass%living_leaf_biomass()+ &
       crop%biomass%storage_biomass+m1%dead_leaf_biomass+m1%dead_stem_biomass
  call evaluate_grass_management_day(p,m1,crop,f,r,status)
  if(status/=GRASS_MGMT_OK) error stop 18
  if(.not.r%candidate_management%grazing_active.or.r%candidate_management%cut_ends_today) error stop 19
  if(abs(r%harvested_biomass-10.0_real64)>tol) error stop 20
  if(abs(r%lost_biomass-5.0_real64)>tol) error stop 21
  fixed_grazing_loss=p%grazing_fixed_loss_per_day
  after_total=r%candidate_crop%biomass%stem_biomass+r%candidate_crop%biomass%living_leaf_biomass()+ &
       r%candidate_crop%biomass%storage_biomass+r%candidate_management%dead_leaf_biomass+ &
       r%candidate_management%dead_stem_biomass
  ! Source removes UPTGRZ + LOSSGRZ + treading, but publishes only UPTGRZ as
  ! harvest and treading as DMLOSS. Keep that accounting asymmetry explicit.
  if(abs((before_total-after_total)-(r%harvested_biomass+r%lost_biomass+fixed_grazing_loss))>tol) error stop 22

  ! Second grazing day becomes partial at residual biomass and closes event.
  m1=r%candidate_management
  crop=r%candidate_crop
  f%current_time_day=103.0_real64
  call evaluate_grass_management_day(p,m1,crop,f,r,status)
  if(status/=GRASS_MGMT_OK) error stop 23
  if(r%candidate_management%event_index/=3.or.r%candidate_management%grazing_active) error stop 24

  ! B1.11 local DMLoss is undefined for SW_LOSSGRZ=0. Fail closed rather
  ! than silently adopting a zero initialization.
  invalid_p=p
  invalid_p%grazing_loss_enabled=.false.
  if(invalid_p%ready()) error stop 25

  print '(a)','SW431_CROP_GRASS_MANAGEMENT=PASS'

contains
  subroutine make(x,y,table)
    real(real64),intent(in)::x(:),y(:)
    type(wofost_rate_table_t),intent(out)::table
    integer::rc
    call construct_wofost_rate_table(x,y,table,rc)
    if(rc/=WOFOST_RATE_TABLE_OK)error stop 99
  end subroutine make
end program
