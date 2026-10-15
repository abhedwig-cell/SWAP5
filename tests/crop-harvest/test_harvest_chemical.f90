program test_harvest_chemical
 use iso_fortran_env,only:real64,int64
 use mod_b111_soil_n_addition
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_crop_soil_n_senescence_day
 use mod_crop_soil_n_material_day
 use mod_crop_senescence_residue
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 implicit none
 type(reactive_parameters_t)::sp
 type(reactive_state_t)::soil,gotsoil
 type(crop_n_configuration_t)::cp,bad_cp
 type(soil_n_pool_state_t)::pools,got,beforep
 type(wofost81_crop_owner_state_t)::crop,decoded
 type(crop_soil_state_t)::state,before,harvested,restored,corrupted
 type(crop_soil_harvest_receipt_t)::h
 type(senescence_day_receipt_t)::day
 type(crop_senescence_policy_t)::policy
 type(crop_residue_pending_t)::pending,actual
 type(soil_n_material_input_t)::items(2)
 type(b111_soil_n_split_parameters_t)::split
 type(wofost_one_day_forcing_t)::weather
 type(wofost81_harvest_record_t)::record
 real(real64),allocatable::v(:),w(:),bad(:)
 real(real64)::clock,theta,n0,nh,inc
 integer(int64)::rev
 integer::code,i,checks
 logical::has
 checks=0
 call parameters(sp);call materials(items,split);call configure_crop(cp)
 cp%base%nitrogen%nfix_fr=.3d0;cp%update%leaf_lifespan=1.5d0;cp%lai_crit_nupt=1d0
 allocate(cp%harvest);cp%harvest%crop_identity=7;cp%harvest%crop_end=0d0
 cp%harvest%policy%return_fraction=[.2d0,.5d0,.3d0]
 cp%harvest%policy%application_age=[1.57d0,.99d0,1.57d0,.99d0]
 call configure_owner(crop,cp,code);call require(code==0,'crop initialization')
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,code)
 call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
 call initialize_crop_soil(soil,crop,cp,9101_int64,state,code);call require(code==0,'configured harvest bound at initialization')
 call harvest_crop_soil_boundary(state,h);call require(h%status/=0,'unaccepted initial state cannot harvest')
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 policy%application_age=[1.57d0,.99d0,1.57d0]
 call advance_crop_soil_senescence_day(state,0d0,1d0,.34d0-.001d0/.3d0,0d0,0d0,0d0,.001d0,.1d0, &
  weather,items,split,policy,day)
 call require(day%status==0,'actual accepted crop soil day')
 call state%pending_snapshot(pending,has);call require(has,'daily death already pending')
 before=state;n0=crop_soil_whole_n(state)
 call state%snapshot(soil,crop)
 bad_cp=cp;bad_cp%harvest%policy%application_age(4)=.67d0
 call initialize_crop_soil(soil,crop,bad_cp,9102_int64,corrupted,code,pending)
 call require(code==0,'independent profile with structurally valid but unincorporable harvest age')
 call harvest_crop_soil_boundary(corrupted,h)
 call require(h%status/=0,'late residue chemistry refusal rejects entire harvest')
 call corrupted%snapshot(gotsoil,decoded)
 call require(.not.decoded%harvested().and.decoded%crop%crop_emerged,'late refusal retains active crop')
 call corrupted%pending_snapshot(actual,has)
 call require(has.and.all(actual%nitrogen_kg_ha==pending%nitrogen_kg_ha),'late refusal preserves prior pending death')

 call state%snapshot(soil,crop);call soil%snapshot(clock,theta,beforep,rev)
 call harvest_crop_soil_boundary(state,h)
 call require(h%status==0.and.abs(h%residual)<=1d-12,'atomic chemical harvest balance')
 call require(abs(n0-crop_soil_whole_n(state)-h%exported_n)<=1d-12,'harvest external export only')
 call state%pending_snapshot(actual,has)
 call require(has.and.all(actual%nitrogen_kg_ha==pending%nitrogen_kg_ha).and. &
  all(actual%dry_matter_kg_ha==pending%dry_matter_kg_ha),'preserve existing final day pending death')
 call state%snapshot(gotsoil,crop);call gotsoil%snapshot(clock,theta,got,rev)
 call require(clock==1d0.and.rev==1.and.all(got%fom_kg_m3==beforep%fom_kg_m3),'harvest leaves accepted soil clock and pools unchanged')
 call crop%harvest_snapshot(record,has)
 inc=pending%nitrogen_kg_m2()+sum(record%pending_n)*1d-4
 v=pack_crop_n_continuation(crop);call unpack_crop_n_continuation(v,decoded,code)
 call require(code==0,'unconsumed harvest owner codec')
 w=pack_crop_n_continuation(decoded);call require(all(v==w),'unconsumed bitwise owner continuation')
 call initialize_crop_soil(gotsoil,decoded,cp,9101_int64,restored,code,pending)
 call require(code==0.and.harvest_incorporation_valid(restored),'restart reconstructs complete chemical phase')
 bad=v;bad(4)=1d0
 call unpack_crop_n_continuation(bad,decoded,code)
 call require(code==0,'phase flag alone still forms an owner but cannot form coupled authority')
 call initialize_crop_soil(gotsoil,decoded,cp,9101_int64,corrupted,code,pending)
 call require(code/=0,'forged consumed flag fails coupled N and OM continuation budget')
 harvested=state;nh=crop_soil_whole_n(state)
 call harvest_crop_soil_boundary(state,h);call require(h%status/=0,'harvest duplicate rejected')
 call require(crop_soil_whole_n(state)==nh,'duplicate no material debit')
 do i=1,8
  bad=v
  select case(i)
  case(1);bad(4)=2d0
  case(2);bad(16)=-1d0
  case(3);bad(30)=99999d0
  case(4);bad(12)=0d0
  case(5);bad(24)=999d0
  case(6);bad(3)=.5d0
  case(7);bad(8)=.66d0
  case(8);bad(5)=1.1d0
  end select
  call unpack_crop_n_continuation(bad,decoded,code)
  call require(code/=0,'corrupt harvest owner fail closed')
 end do
 call consume_crop_soil_harvest_pending(state,h)
 call require(h%status==0.and.abs(h%residual)<=1d-12.and.abs(h%incorporated_n-inc)<=1d-12,'seven organ incorporation once')
 call require(abs(crop_soil_whole_n(state)-nh)<=1d-12,'internal transfer whole N unchanged')
 call state%pending_snapshot(actual,has);call require(.not.has,'daily pending retired only after acceptance')
 call state%snapshot(soil,crop);call soil%snapshot(clock,theta,got,rev)
 call require(clock==1d0.and.rev==1,'no artificial timestep or soil revision')
 call require(abs(got%nitrogen_total(sp%mineral%inventory)-beforep%nitrogen_total(sp%mineral%inventory)-inc)<=1d-12, &
  'soil receives complete daily and harvest N exactly once')
 w=pack_crop_n_continuation(crop);call unpack_crop_n_continuation(w,decoded,code)
 call require(code==0,'consumed harvest owner codec')
 bad=w;bad(4)=0d0
 call unpack_crop_n_continuation(bad,decoded,code)
 call require(code==0,'reverse forged phase retains standalone syntax')
 call initialize_crop_soil(soil,decoded,cp,9101_int64,corrupted,code)
 call require(code/=0,'consumed flag cannot reintroduce fictitious pending mass')
 call consume_crop_soil_harvest_pending(restored,h);call require(h%status==0,'restored pending consumption')
 call restored%snapshot(gotsoil,decoded);bad=pack_crop_n_continuation(decoded)
 call require(all(bad==w),'continuous restored consumed owner identity')
 call consume_crop_soil_harvest_pending(state,h);call require(h%status/=0,'duplicate consumption refused')
 call state%snapshot(soil,decoded);bad=pack_crop_n_continuation(decoded)
 call require(all(bad==w),'duplicate no consumed phase mutation')
 print '(A,I0)','HARVEST_CHEMICAL_ASSERTIONS=',checks
 print '(A)','HARVEST_CHEMICAL_ATOMIC_PENDING_CONTINUATION=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
  checks=checks+1
 end subroutine
 ! Mechanically expanded unchanged fixture: tests/nut-crop/crop_fixture.inc
  subroutine configure_crop(p)
    type(crop_n_configuration_t), intent(out) :: p
    p%scalars%development_daylength_mode = 0
    p%scalars%vegetative_temperature_sum_required = 1000.0_real64
    p%scalars%generative_temperature_sum_required = 1000.0_real64
    p%scalars%diffuse_extinction_coefficient = 0.5_real64
    p%scalars%initial_light_use_efficiency = 0.4_real64
    p%scalars%co2_to_dry_matter_fraction = 0.7_real64
    p%scalars%attainable_yield_multiplier = 1.0_real64
    p%scalars%conversion_efficiency_root = 0.7_real64
    p%scalars%conversion_efficiency_stem = 0.7_real64
    p%scalars%conversion_efficiency_leaf = 0.7_real64
    p%scalars%conversion_efficiency_storage = 0.7_real64
    p%scalars%respiration_temperature_q10 = 2.0_real64
    p%scalars%maintenance_respiration_root = 0.01_real64
    p%scalars%maintenance_respiration_leaf = 0.01_real64
    p%scalars%maintenance_respiration_stem = 0.01_real64
    p%scalars%maintenance_respiration_storage = 0.01_real64
    p%scalars%maximum_leaf_relative_death_rate = 0.03_real64
    p%scalars%leaf_age_base_temperature = 0.0_real64
    p%scalars%maximum_relative_lai_growth_rate = 0.008_real64
    call make_table([0.0_real64,40.0_real64],[10.0_real64,10.0_real64],p%tables(1))
    call make_table([0.0_real64,2.0_real64],[35.0_real64,35.0_real64],p%tables(2))
    call make_table([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],p%tables(3))
    call make_table([-10.0_real64,20.0_real64],[1.0_real64,1.0_real64],p%tables(4))
    call make_table([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],p%tables(5))
    call make_table([0.0_real64,2.0_real64],[0.2_real64,0.2_real64],p%tables(6))
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables(7))
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables(8))
    call make_table([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],p%tables(9))
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],p%tables(10))
    call make_table([0.0_real64,2.0_real64],[0.01_real64,0.01_real64],p%tables(11))
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],p%tables(12))
    call configure_p81(p)
    p%root_depth_cm=30d0;p%tcsf_n=1d0;p%lai_crit_nupt=3d0
    p%update%development_stage_end=2d0;p%update%leaf_lifespan=100d0
  end subroutine

  subroutine make_table(x,y,table)
    real(real64),intent(in)::x(:),y(:)
    type(crop_n_table_t),intent(out)::table
    table%x=x;table%y=y
  end subroutine

  subroutine configure_p81(p)
    type(crop_n_configuration_t), intent(inout) :: p
    p%base%assimilation%amax_lnb = 0.0_real64
    p%base%assimilation%amax_ref = 35.0_real64
    p%base%assimilation%amax_slp = 3.24_real64
    p%base%assimilation%kn = 0.4_real64
    p%base%nitrogen%nmaxst_fr = 0.5_real64
    p%base%nitrogen%nmaxrt_fr = 0.5_real64
    p%base%nitrogen%nmaxso = 0.0176_real64
    p%base%nitrogen%nresidlv = 0.004_real64
    p%base%nitrogen%nresidst = 0.002_real64
    p%base%nitrogen%nresidrt = 0.002_real64
    p%base%nitrogen%tcnt = 10.0_real64
    p%base%nitrogen%nfix_fr = 0.0_real64
    p%base%nitrogen%rnuptakemax = 100.0_real64
    p%base%nitrogen%dvs_n_transl = 0.8_real64
    p%base%nitrogen%rgrlai_min = 0.004_real64
    call make_table([0.0_real64,40.0_real64],[0.4_real64,0.4_real64],p%tables(13))
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables(14))
    call make_table([0.0_real64,2.0_real64],[0.04_real64,0.04_real64],p%tables(15))
    call make_table([0.0_real64,3.0_real64],[1.0_real64,1.0_real64],p%tables(16))
  end subroutine

  subroutine configure_owner(owner,p,status)
    type(wofost81_crop_owner_state_t), intent(out) :: owner
    type(crop_n_configuration_t), intent(in) :: p
    integer, intent(out) :: status
    owner%crop%crop_emerged = .true.
    owner%crop%development_stage = 0.5_real64
    allocate(owner%crop%biomass,owner%crop%evolution_continuation)
    owner%crop%biomass%root_biomass = 100.0_real64
    owner%crop%biomass%stem_biomass = 200.0_real64
    owner%crop%biomass%storage_biomass = 50.0_real64
    owner%crop%biomass%leaf_biomass = [100.0_real64,100.0_real64]
    owner%crop%biomass%specific_leaf_area = [0.02_real64,0.02_real64]
    owner%crop%biomass%leaf_age = [1.0_real64,2.0_real64]
    owner%crop%biomass%exponential_leaf_area_index = 4.0_real64
    call initialize_wofost81_n_owner_state(200.0_real64,200.0_real64,100.0_real64,0.04_real64, &
         p%base%nitrogen,owner%nitrogen,status)
  end subroutine


 ! Mechanically expanded unchanged fixture: tests/nut-material/material_fixture.inc
 subroutine parameters(p)
   type(reactive_parameters_t),intent(out)::p
   p%mineral%dz_cm=[5d0,5d0,10d0,10d0];p%mineral%inventory%depth_m=.3d0
   p%mineral%inventory%nfrac_fom=[.015d0,.025d0]
   p%mineral%inventory%nfrac_biomass=.04d0;p%mineral%inventory%nfrac_humus=.02d0
   p%mineral%drybd=1300d0;p%mineral%sorption=.0002d0
   p%mineral%c_bottom=[.1d0,.2d0];p%mineral%c_lateral=[.3d0,.4d0]
   p%organic_reference%ratecon_fom=[.04d0,.015d0]
   p%organic_reference%asfa_fom_bio=[.2d0,.25d0];p%organic_reference%asfa_fom_hum=[.15d0,.1d0]
   p%organic_reference%ratecon_bio=.008d0;p%organic_reference%ratecon_hum=.0008d0
   p%organic_reference%asfa_bio=.3d0;p%organic_reference%asfa_hum=.2d0
   p%cfrac_fom=[.45d0,.45d0];p%cfrac_biomass=.45d0;p%cfrac_humus=.45d0;p%wfpscrit=.6d0
   p%environment%temperature_c=20d0;p%environment%temperature_reference_c=20d0
   p%environment%wfrac_sat=.423d0;p%environment%wfpscrit2=.5d0
   p%environment%cdissi_half_kg_m2=.1d0
   p%environment%nitrification_ref_per_day=.02d0;p%environment%denitrification_ref_per_day=.03d0
   p%mineral%inventory%nfrac_fom=[.06d0,.002d0,.06d0,.002d0,.06d0,.002d0,.06d0,.002d0]
   p%mineral%inventory%nfrac_biomass=.58d0/10d0;p%mineral%inventory%nfrac_humus=.58d0/14d0
   p%organic_reference%ratecon_fom=[3d0,3d0,3d0,3d0,.3d0,.3d0,.3d0,.3d0]/365.2425d0
   p%organic_reference%asfa_fom_bio=[.04d0,.04d0,.28d0,.28d0,.04d0,.04d0,.28d0,.28d0]*.46d0
   p%organic_reference%asfa_fom_hum=[.04d0,.04d0,.28d0,.28d0,.04d0,.04d0,.28d0,.28d0]*.54d0
   p%organic_reference%ratecon_bio=.66d0/365.2425d0;p%organic_reference%ratecon_hum=.02d0/365.2425d0
   p%organic_reference%asfa_bio=.46d0*.2d0;p%organic_reference%asfa_hum=.54d0*.2d0
   p%cfrac_fom=spread(.45d0,1,8);p%cfrac_biomass=.58d0;p%cfrac_humus=.58d0
 end subroutine
 subroutine materials(items,split)
 type(soil_n_material_input_t),intent(out)::items(2)
 type(b111_soil_n_split_parameters_t),intent(out)::split
 split%nfrac_fom_min=.002d0;split%nfrac_fom_max=.06d0;split%nfrac_humus=.58d0/14d0
 split%asfa_min=.04d0;split%asfa_max=.28d0
 items(1)%kind=MATERIAL_AMENDMENT;items(1)%material%application_kg_m2=.04d0
 items(1)%material%application_age=3.16d0;items(1)%material%organic_matter_fraction=.5d0
 items(1)%material%organic_n_fraction=.025d0;items(1)%material%ammonium_n_fraction=.02d0
 items(1)%material%nitrate_n_fraction=.01d0;items(1)%material%volatilization_fraction=.25d0
 items(2)=items(1);items(2)%kind=MATERIAL_RESIDUE;items(2)%material%application_age=.99d0
 items(2)%material%volatilization_fraction=0d0;items(2)%material%application_kg_m2=.01d0
 end subroutine

end program
