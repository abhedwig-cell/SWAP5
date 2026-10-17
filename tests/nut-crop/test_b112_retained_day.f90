program test_b112_retained_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_crop_soil_n_senescence_day
 use mod_crop_soil_n_material_day
 use mod_crop_senescence_residue
 use mod_b111_soil_n_addition
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_wofost_one_day_structural_evolution
 implicit none
 type(crop_n_configuration_t)::cp,bad
 type(reactive_parameters_t)::sp
 type(reactive_state_t)::soil,gotsoil
 type(soil_n_pool_state_t)::pools,gotpools
 type(wofost81_crop_owner_state_t)::crop,gotcrop,restored
 type(crop_soil_state_t)::state,previous
 type(wofost_one_day_forcing_t)::weather,invalid_weather
 type(crop_senescence_policy_t)::policy
 type(crop_residue_pending_t)::pending
 type(soil_n_material_input_t)::items(2)
 type(b111_soil_n_split_parameters_t)::split
 type(senescence_day_receipt_t)::day_r
 type(crop_soil_harvest_receipt_t)::harvest_r
 type(wofost81_harvest_record_t)::h
 real(real64),parameter::fractions(3)=[0d0,.25d0,1d0],phases(2)=[.5d0,1.2d0]
 real(real64)::dm(3),n(3),retained_dm(2),retained_n(2),time,theta,before_n,before_dm,stock_n
 real(real64),allocatable::v(:),proof(:)
 integer(int64)::revision
 integer::i,j,k,l,day,code,cases,rejected_material
 logical::has
 call parameters(sp);call materials(items,split)
 policy%application_age=[1d0,2d0,3d0]
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 cases=0;rejected_material=0
 do l=0,2
 do i=1,3
 do j=1,3
 do k=1,3
  call configure_crop(cp);cp%update%leaf_lifespan=2.5d0
  cp%tables(15)%y=.01d0 ! same valid N range as the B1.12 source qualification
  allocate(cp%b111_reproductive,cp%b112_return,cp%harvest)
  cp%b111_reproductive%dvsnlt=.9d0;cp%b111_reproductive%dvsnt=.8d0
  cp%b111_reproductive%fntrt=.25d0;cp%b111_reproductive%nfixf=.25d0
  cp%b112_return%leaf_fraction=fractions(i)
  cp%harvest%crop_identity=1;cp%harvest%crop_end=2d0;cp%harvest%sw_harv=0;cp%harvest%sw_wofost=1
  cp%harvest%policy%return_fraction=[fractions(j),fractions(k),1d0]
  cp%harvest%policy%application_age=[1d0,2d0,3d0,4d0]
  call configure_owner(crop,cp,code);call require(code==0,'seed N initialize')
  crop%nitrogen%value%namountlv=2d0;crop%nitrogen%value%namountst=1d0;crop%nitrogen%value%namountrt=.5d0
  crop%nitrogen%value%initial_total=3.5d0
  crop%crop%development_stage=phases(max(1,l));crop%crop%evolution_continuation%anthesis_reached=l==2
  if(l>0)then
   crop%nitrogen%value%namountso=.5d0
   crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total+.5d0
  endif
  call initialize_soil_n_pool_state(sp%mineral%inventory,spread(20d0,1,8),5d0,40d0,.02d0,.03d0,pools,code)
  call initialize_reactive(sp,9001_int64,0d0,.34d0,pools,soil,code)
  call initialize_crop_soil(soil,crop,cp,9101_int64,state,code);call require(code==0.and.state%ready(),'explicit B112 initialize')
  retained_dm=0d0;retained_n=0d0
  do day=1,3
   previous=state;call state%snapshot(gotsoil,gotcrop);v=pack_crop_n_owner(gotcrop)
   invalid_weather=weather;invalid_weather%average_temperature=ieee_value(0d0,ieee_quiet_nan)
   call advance_crop_soil_senescence_day(state,real(day-1,real64),real(day,real64),.34d0-real(day,real64)*.0005d0/.3d0, &
    0d0,0d0,0d0,.0005d0,.1d0,invalid_weather,items(:0),split,policy,day_r)
   call require(day_r%status/=0,'bad daily trial rejects')
   call state%snapshot(gotsoil,gotcrop);proof=pack_crop_n_owner(gotcrop)
   call require(size(v)==size(proof).and.all(v==proof),'rejection leaves physical stocks unchanged')
   call advance_crop_soil_senescence_day(state,real(day-1,real64),real(day,real64),.34d0-real(day,real64)*.0005d0/.3d0, &
    0d0,0d0,0d0,.0005d0,.1d0,weather,items(:0),split,policy,day_r)
   if(day_r%status/=0)print *,'daily failure',l,i,j,k,day,day_r%status,day_r%materials%status,day_r%materials%day%status
   call require(day_r%status==0,'actual soil-crop partial-return day')
   call require(abs(day_r%whole_n_residual)<1d-12,'whole N includes retained and pending once')
   associate(d=>day_r%materials%day)
    dm=[d%prepared%drrt,d%prepared%drlv,d%prepared%drst]
    n=[d%crop%rndeathrt,d%crop%rndeathlv,d%crop%rndeathst]
   end associate
   retained_dm=retained_dm+[(1d0-fractions(i))*dm(2),dm(3)]
   retained_n=retained_n+[(1d0-fractions(i))*n(2),n(3)]
   call state%snapshot(gotsoil,gotcrop)
   call require(all(abs(gotcrop%crop%biomass%retained_dead_biomass-retained_dm)<1d-12),'actual retained leaf/stem DM')
   call require(all(abs(gotcrop%nitrogen%retained_dead_n-retained_n)<1d-12),'actual retained leaf/stem N')
   call require(gotcrop%crop%biomass%cumulative_dead_leaf_biomass>=retained_dm(1),'gross mortality is distinct')
   call state%pending_snapshot(pending,has);call require(has,'real pending material')
   call require(all(abs(pending%dry_matter_kg_ha-[dm(1),fractions(i)*dm(2),0d0])<1d-12),'source partial pending DM')
   v=pack_crop_n_owner(gotcrop);call unpack_crop_n_owner(v,restored,code);proof=pack_crop_n_owner(restored)
   call require(code==0.and.size(v)==size(proof),'physical/gross owner codec')
   call require(all(v==proof),'exact physical/gross owner continuation')
   call require(restored%nitrogen%b112_residue_profile,'owner codec retains selected profile')
  enddo
  call require(retained_dm(2)>0d0.and.retained_n(2)>0d0,'nonzero retained stem fixture')
  if(i<3)call require(retained_dm(1)>0d0.and.retained_n(1)>0d0,'nonzero retained leaf fixture')
  before_n=crop_soil_whole_n(state);before_dm=crop_soil_organic_mass(state)
  call harvest_crop_soil_boundary(state,harvest_r)
  if(l==0)then
   ! Real chemistry rejects N-free storage OM below its qualified N-fraction domain.
   call require(harvest_r%status/=0.and.harvest_r%rejection_stage==5,'invalid storage residue rejects atomically')
   call state%snapshot(gotsoil,gotcrop);proof=pack_crop_n_owner(gotcrop)
   call require(size(v)==size(proof).and.all(v==proof),'rejected residue harvest preserves retained stock')
   rejected_material=rejected_material+1;cycle
  endif
  if(harvest_r%status/=0)then
   call state%snapshot(gotsoil,gotcrop)
   call prepare_wofost81_harvest(gotcrop,3d0,1_int64,2d0,0,1,2d0,cp%harvest%policy,restored,code)
   print *,'harvest failure',i,j,k,harvest_r%status,'stage',harvest_r%rejection_stage,'prepare',code,'owner',gotcrop%validate(),gotcrop%nitrogen%validate()
   print *,'physical',gotcrop%crop%biomass%retained_dead_biomass,gotcrop%nitrogen%retained_dead_n
   print *,'gross',gotcrop%nitrogen%value%nlosses_total
  endif
  call require(harvest_r%status==0,'partial/full harvest includes retained material')
  call state%snapshot(gotsoil,gotcrop);call gotcrop%harvest_snapshot(h,has)
  call require(has.and.all(gotcrop%nitrogen%retained_dead_n==0d0),'physical retained N clears at harvest')
  call require(abs(before_n-crop_soil_whole_n(state)-sum(h%exported_n)*1d-4)<1d-12,'harvest whole N closes')
  call require(abs(before_dm-crop_soil_organic_mass(state)-sum(h%exported_dm)*1d-4)<1d-12,'harvest whole organic material closes')
  v=pack_crop_n_continuation(gotcrop);call unpack_crop_n_continuation(v,restored,code);proof=pack_crop_n_continuation(restored)
  call require(code==0.and.size(v)==size(proof),'harvest stock codec shape')
  call require(all(v==proof),'harvest material owner codec exact')
  stock_n=crop_soil_whole_n(state);before_dm=crop_soil_organic_mass(state)
  call consume_crop_soil_harvest_pending(state,harvest_r)
  call require(harvest_r%status==0,'daily and harvest pending consume together once')
  call require(abs(stock_n-crop_soil_whole_n(state))<1d-12,'incorporation preserves whole N')
  call require(abs(before_dm-crop_soil_organic_mass(state))<1d-12,'incorporation preserves whole OM')
  previous=state;call consume_crop_soil_harvest_pending(state,harvest_r)
  call require(harvest_r%status/=0,'duplicate pending consumption rejects')
  call state%snapshot(gotsoil,gotcrop);v=pack_crop_n_continuation(gotcrop)
  call unpack_crop_n_continuation(v,restored,code);proof=pack_crop_n_continuation(restored)
  call require(code==0.and.all(v==proof),'consumed harvest continuation exact')
  cases=cases+1
 enddo
 enddo
 enddo
 enddo
 print '(A,I0)','B112_ACTUAL_DAILY_PARTIAL_HARVEST_CASES=',cases
 print '(A,I0)','B112_REAL_INVALID_STORAGE_RESIDUE_REJECTIONS=',rejected_material
 print '(A)','B112_SOIL_CROP_RETAINED_WHOLE_N_OM_REJECT_REPLAY_CODEC=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,label;error stop 1;endif
 end subroutine
 include 'crop_fixture.inc'
 include 'material_fixture.inc'
end program
