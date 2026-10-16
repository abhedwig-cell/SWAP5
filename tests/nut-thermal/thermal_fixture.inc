 subroutine thermal_water_unchanged(w,before)
  type(kernel_committed_state_t),intent(in)::w,before
  class(transaction_state_t),allocatable::p,q
  type(soil_temperature_field_view_t)::a,b
  type(kernel_parameter_identity_t)::x,y
  real(real64),allocatable::d1(:),d2(:)
  logical::ok1,ok2
  integer::code
  call w%certified_parameter_identity(x,ok1);call before%certified_parameter_identity(y,ok2)
  call require(ok1.and.ok2.and.x%matches(y),'rejected day certificate unchanged')
  call w%snapshot(p,ok1);call before%snapshot(q,ok2);call require(ok1.and.ok2,'rollback physical snapshots')
  select type(p)
  class is(fmr_b110_physical_state_t)
   select type(q)
   class is(fmr_b110_physical_state_t)
    call require(all(p%pressure_head==q%pressure_head).and.all(p%water_content==q%water_content).and. &
     p%ponding_depth==q%ponding_depth.and.p%groundwater_level==q%groundwater_level,'rejected physical water unchanged')
    call build_soil_temperature_field_view(p%soil_temperature,a,code);call require(code==0,'rollback heat field')
    call build_soil_temperature_field_view(q%soil_temperature,b,code);call require(code==0,'original heat field')
    call require(all(a%temperature_c==b%temperature_c),'rejected heat profile unchanged')
   end select
  end select
  select type(p)
  type is(fmr_b110_temporal_indicator_state_t)
   select type(q)
   type is(fmr_b110_temporal_indicator_state_t)
    call p%temporal_history_snapshot(d1,ok1);call q%temporal_history_snapshot(d2,ok2)
    call require(ok1.eqv.ok2,'rejected history availability unchanged')
    if(ok1)call require(all(d1==d2),'rejected temporal history unchanged')
   end select
  end select
 end subroutine
 subroutine initialize_thermal_water(w)
  type(kernel_committed_state_t),intent(out)::w
  type(kernel_committed_state_t)::temporary
  class(transaction_state_t),allocatable::physical
  logical::available
  call fmr_new_b110_temporal_indicator_committed_state(temporary,column%column_id,cfg%tiles(1)%initial_state,0d0,available, &
   spread(0d0,1,numnod))
  call require(available,'initial temporal history')
  call temporary%snapshot(physical,available);call require(available,'initial detached physical state')
  call w%initialize(column%column_id,physical,available,0d0,cfg%tiles(1)%parameters)
  call require(available,'certified initial temporal heat water')
 end subroutine
 subroutine enable_heat()
  integer::code
  cfg%tiles(1)%parameters%soil_temperature_active=.true.
  cfg%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  allocate(cfg%tiles(1)%parameters%soil_temperature,cfg%tiles(1)%initial_state%soil_temperature,cfg%tiles(1)%base_forcing%soil_temperature)
  call initialize_soil_temperature_parameters(dz,disnod(1:numnod),cfg%tiles(1)%parameters%cofgen(2,:), &
   spread(.3d0,1,numnod),spread(.2d0,1,numnod),spread(.04d0,1,numnod),cfg%tiles(1)%parameters%soil_temperature,code)
  call require(code==SOIL_TEMP_OK,'real thermal parameters')
  call initialize_soil_temperature_state([5d0,10d0,20d0,35d0],cfg%tiles(1)%initial_state%soil_temperature,code)
  call require(code==SOIL_TEMP_OK,'nonuniform real thermal profile')
  cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=5d0
 end subroutine
 real(real64)function accepted_literal_temperature(w,t0,t1)result(temperature)
  type(kernel_committed_state_t),intent(in)::w
  real(real64),intent(in)::t0,t1
  class(transaction_state_t),allocatable::physical
  type(soil_temperature_field_view_t)::heat
  type(soil_n_day_environment_t)::sampled
  real(real64)::used,selected
  logical::available
  integer::code
  call w%snapshot(physical,available);call require(available,'detached accepted profile')
  select type(physical)
  class is(fmr_b110_physical_state_t)
   call build_soil_temperature_field_view(physical%soil_temperature,heat,code)
   call require(code==0,'accepted actual thermal field')
  end select
  call literal_profile(cfg%tiles(1)%parameters%dz,heat%temperature_c,.3d0,temperature,used)
  call sample_accepted_soil_n_environment(w,w%current_lineage_id(),w%current_revision(),t0,t1,.3d0,sampled,selected,code)
  call require(code==0.and.sampled%temperature_c==temperature.and.selected==used,'certified reducer matches literal accepted profile')
  call require(used==.2d0,'source strict depth boundary')
 end function
 include 'literal_profile.inc'
