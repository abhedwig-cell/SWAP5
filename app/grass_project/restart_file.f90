! Bounded same-build Grassgrowth prefix file. Existing kernel/crop owners are
! restored; this adapter owns no physical continuation. Source bytes, application
! binding and CRC are checked before either committed owner is replaced.
module mod_grass_prefix_restart_file
 use iso_fortran_env,only:real64,int64,int32,int8
 use iso_c_binding,only:c_int,c_char,c_null_char
 use ieee_arithmetic,only:ieee_is_finite
 use mod_transaction_reference,only:transaction_state_t
 use mod_kernel_transactions
 use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_parameters_t,fmr_b110_boesten_evaporation_state_t
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view, &
   initialize_soil_temperature_state
 use mod_wofost_potential_shadow_state
 use mod_crop_root_depth_rate_owner
 use mod_wofost_crop_owner_state
 use mod_wofost_grass_development,only:grass_management_continuation_t
 use mod_age_joint_restart_file,only:crc32
 implicit none
 private
 public::write_grass_prefix_restart,read_grass_prefix_restart
 character(8),parameter::MAGIC='S5GRS002'
 character(24),parameter::FILES(6)=[character(24)::'input.swp','grass.crp','input.met','swap.bbc','swap.dra','application.binding']
 interface
  integer(c_int) function rename_c(a,b)bind(C,name='rename')
   import c_int,c_char
   character(c_char),intent(in)::a(*),b(*)
  end function
  integer(c_int) function open_c(a,b)bind(C,name='open')
   import c_int,c_char
   character(c_char),intent(in)::a(*)
   integer(c_int),value::b
  end function
  integer(c_int) function sync_c(a)bind(C,name='fsync')
   import c_int
   integer(c_int),value::a
  end function
  integer(c_int) function close_c(a)bind(C,name='close')
   import c_int
   integer(c_int),value::a
  end function
 end interface
contains
 subroutine read_bytes(path,bytes,status)
  character(*),intent(in)::path
  integer(int8),allocatable,intent(out)::bytes(:)
  integer,intent(out)::status
  integer::n,u,io
  status=1
  inquire(file=path,size=n,iostat=io)
  if(io/=0.or.n<1.or.n>16777216)return
  allocate(bytes(n))
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
  if(io/=0)return
  read(u,iostat=io)bytes;close(u)
  if(io==0)status=0
 end subroutine
 subroutine file_text(path,text,status)
  character(*),intent(in)::path
  character(:),allocatable,intent(out)::text
  integer,intent(out)::status
  integer::n,u,io
  status=1;inquire(file=path,size=n,iostat=io)
  if(io/=0.or.n<1.or.n>2097152)return
  allocate(character(n)::text)
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
  if(io/=0)return
  read(u,iostat=io)text;close(u)
  if(io==0)status=0
 end subroutine
 integer function synchronize(path)result(status)
  character(*),intent(in)::path
  integer(c_int)::fd,ignored
  status=1;fd=open_c(trim(path)//c_null_char,0_c_int)
  if(fd<0)return
  status=sync_c(fd);ignored=close_c(fd)
 end function
 subroutine write_grass_prefix_restart(path,water,crop,management,status,potential,roots)
  character(*),intent(in)::path
  type(kernel_committed_state_t),intent(in)::water
  type(wofost_crop_owner_state_t),intent(in)::crop
  type(grass_management_continuation_t),intent(in)::management
  integer,intent(out)::status
  type(wofost_potential_shadow_state_t),intent(in)::potential
  type(crop_root_depth_rate_state_t),intent(in)::roots
  type(wofost_crop_owner_state_t)::potential_owner
  class(transaction_state_t),allocatable::physical
  type(kernel_parameter_identity_t)::identity
  type(soil_temperature_field_view_t)::heat
  integer(int8),allocatable::bytes(:)
  character(:),allocatable::text,pending
  integer::u,io,code,n,i,leaf_count
  integer(int32)::crc
  real(real64)::time
  logical::ok
  status=1
  if(potential%validate()/=0.or..not.potential%active.or.roots%validate()/=0)return
  call potential%materialize_owner(crop,potential_owner,ok,code)
  if(code/=0.or..not.ok.or.allocated(potential_owner%b110_reference_compatibility))return
  if(.not.water%ready().or.crop%validate()/=WOFOST_CROP_OWNER_OK)return
  if(.not.crop%crop_emerged.or..not.allocated(crop%biomass).or..not.allocated(crop%evolution_continuation))return
  if(allocated(crop%b110_reference_compatibility))return
  if(min(management%warm_days,management%regrowth_delay_days)<0)return
  call water%current_time(time,ok)
  if(.not.ok.or.time/=aint(time).or.time<0d0.or.time>366d0)return
  call water%certified_parameter_identity(identity,ok);if(.not.ok)return
  call water%snapshot(physical,ok);if(.not.ok)return
  select type(q=>physical)
  type is(fmr_b110_boesten_evaporation_state_t)
   n=q%active_nodes
   if(allocated(q%salt).or.allocated(q%macropore).or.allocated(q%snow).or.allocated(q%rutter))return
   if(.not.allocated(q%soil_temperature))return
   call build_soil_temperature_field_view(q%soil_temperature,heat,code);if(code/=0)return
   leaf_count=crop%biomass%active_leaf_cohort_count()
   if(leaf_count<1.or.leaf_count>4096)return
   pending=trim(path)//'.pending'
   open(newunit=u,file=pending,access='stream',form='unformatted',status='replace',action='write',iostat=io)
   if(io/=0)return
   write(u,iostat=io)MAGIC
   if(io/=0)then
    close(u);return
   end if
   do i=1,size(FILES)
    call file_text(trim(FILES(i)),text,code)
    if(code/=0)then
     close(u);return
    end if
    write(u,iostat=io)len(text),text
    deallocate(text)
    if(io/=0)then
     close(u);return
    end if
   end do
   write(u,iostat=io)n,time,water%current_lineage_id(),water%current_revision(),identity%parameter_set_id, &
     identity%active_nodes,identity%heat_enabled,identity%valid,identity%z,identity%dz
   if(io/=0)then
    close(u);return
   end if
   write(u,iostat=io)q%pressure_head,q%water_content,q%ponding_depth,q%groundwater_level,heat%temperature_c, &
     q%boesten_evaporation%spev,q%boesten_evaporation%saev
   if(io/=0)then
    close(u);return
   end if
   write(u,iostat=io)crop%development_stage,leaf_count, &
    crop%biomass%root_biomass,crop%biomass%stem_biomass,crop%biomass%storage_biomass, &
    crop%biomass%cumulative_dead_root_biomass,crop%biomass%cumulative_dead_stem_biomass,crop%biomass%cumulative_dead_leaf_biomass, &
    crop%biomass%exponential_leaf_area_index,crop%biomass%retained_dead_biomass, &
    crop%biomass%leaf_biomass,crop%biomass%specific_leaf_area,crop%biomass%leaf_age, &
    crop%evolution_continuation%temperature_sum,crop%evolution_continuation%anthesis_reached, &
    crop%evolution_continuation%minimum_temperature_history_count,crop%evolution_continuation%minimum_temperature_history, &
    management%warm_days,management%regrowth_delay_days
   if(io==0)call write_crop(u,potential_owner,io)
   if(io==0)write(u,iostat=io)roots%actual_root_depth_cm,roots%potential_root_depth_cm
   close(u)
   if(io/=0)return
   call read_bytes(pending,bytes,code);if(code/=0)return
   crc=crc32(bytes)
   open(newunit=u,file=pending,access='stream',form='unformatted',status='old',position='append',iostat=io)
   if(io/=0)return
   write(u,iostat=io)crc;close(u);if(io/=0)return
   if(synchronize(pending)/=0)return
   if(rename_c(pending//c_null_char,trim(path)//c_null_char)/=0)return
   if(synchronize('.')/=0)return
   status=0
  class default
   return
  end select
 end subroutine
 subroutine read_grass_prefix_restart(path,parameters,water,crop,management,time,status,potential,roots,root_parameters)
  character(*),intent(in)::path
  type(fmr_b110_physical_parameters_t),intent(in)::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(wofost_crop_owner_state_t),intent(inout)::crop
  type(grass_management_continuation_t),intent(inout)::management
  real(real64),intent(out)::time
  integer,intent(out)::status
  type(wofost_potential_shadow_state_t),intent(inout)::potential
  type(crop_root_depth_rate_state_t),intent(inout)::roots
  type(crop_root_depth_rate_parameters_t),intent(in)::root_parameters
  type(wofost_crop_owner_state_t)::potential_owner
  type(wofost_potential_shadow_state_t)::decoded_potential
  type(crop_root_depth_rate_state_t)::decoded_roots
  type(kernel_committed_state_t)::restored
  type(wofost_crop_owner_state_t)::decoded
  type(grass_management_continuation_t)::m
  type(kernel_parameter_identity_t)::identity
  class(transaction_state_t),allocatable::physical
  integer(int8),allocatable::bytes(:)
  real(real64),allocatable::temperatures(:)
  character(:),allocatable::text,current
  character(8)::tag
  integer::u,io,code,n,i,length,leaf_count,position
  integer(int64)::lineage,revision
  integer(int32)::expected_crc
  real(real64)::clock
  logical::ok
  status=1;time=0d0
  call read_bytes(path,bytes,code);if(code/=0)return
  if(size(bytes)<16)return
  expected_crc=transfer(bytes(size(bytes)-3:),expected_crc)
  if(crc32(bytes(:size(bytes)-4))/=expected_crc)return
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
  if(io/=0)return
  decode:block
   read(u,iostat=io)tag;if(io/=0.or.tag/=MAGIC)exit decode
   do i=1,size(FILES)
    read(u,iostat=io)length;if(io/=0.or.length<1.or.length>2097152)exit decode
    allocate(character(length)::text)
    read(u,iostat=io)text;if(io/=0)exit decode
    call file_text(trim(FILES(i)),current,code);if(code/=0)exit decode
    if(text/=current)exit decode
    deallocate(text,current)
   end do
   read(u,iostat=io)n,clock,lineage,revision,identity%parameter_set_id,identity%active_nodes,identity%heat_enabled,identity%valid
   if(io/=0.or.n<2.or.n>256)exit decode
   if(n/=parameters%active_nodes.or.n/=identity%active_nodes)exit decode
   if(.not.ieee_is_finite(clock))exit decode
   if(clock/=aint(clock).or.clock<0d0.or.clock>366d0)exit decode
   allocate(identity%z(n),identity%dz(n),temperatures(n))
   read(u,iostat=io)identity%z,identity%dz;if(io/=0)exit decode
   allocate(fmr_b110_boesten_evaporation_state_t::physical)
   select type(q=>physical)
   type is(fmr_b110_boesten_evaporation_state_t)
    q%active_nodes=n;allocate(q%pressure_head(n),q%water_content(n),q%soil_temperature)
    read(u,iostat=io)q%pressure_head,q%water_content,q%ponding_depth,q%groundwater_level,temperatures, &
      q%boesten_evaporation%spev,q%boesten_evaporation%saev
    if(io/=0)exit decode
    if(.not.all(ieee_is_finite([q%boesten_evaporation%spev,q%boesten_evaporation%saev])))exit decode
    if(min(q%boesten_evaporation%spev,q%boesten_evaporation%saev)<0d0)exit decode
    call initialize_soil_temperature_state(temperatures,q%soil_temperature,code);if(code/=0)exit decode
   end select
   decoded%crop_emerged=.true.;allocate(decoded%biomass,decoded%evolution_continuation)
   read(u,iostat=io)decoded%development_stage,leaf_count
   if(io/=0.or.leaf_count<1.or.leaf_count>4096)exit decode
   allocate(decoded%biomass%leaf_biomass(leaf_count),decoded%biomass%specific_leaf_area(leaf_count),decoded%biomass%leaf_age(leaf_count))
   read(u,iostat=io)decoded%biomass%root_biomass,decoded%biomass%stem_biomass,decoded%biomass%storage_biomass, &
    decoded%biomass%cumulative_dead_root_biomass,decoded%biomass%cumulative_dead_stem_biomass,decoded%biomass%cumulative_dead_leaf_biomass, &
    decoded%biomass%exponential_leaf_area_index,decoded%biomass%retained_dead_biomass, &
    decoded%biomass%leaf_biomass,decoded%biomass%specific_leaf_area,decoded%biomass%leaf_age, &
    decoded%evolution_continuation%temperature_sum,decoded%evolution_continuation%anthesis_reached, &
    decoded%evolution_continuation%minimum_temperature_history_count,decoded%evolution_continuation%minimum_temperature_history, &
    m%warm_days,m%regrowth_delay_days
   if(io/=0)exit decode
   call read_crop(u,potential_owner,io);if(io/=0)exit decode
   call initialize_wofost_potential_shadow_from_actual(potential_owner,decoded_potential,code)
   if(code/=0)exit decode
   read(u,iostat=io)decoded_roots%actual_root_depth_cm,decoded_roots%potential_root_depth_cm
   if(io/=0.or.decoded_roots%validate()/=0.or..not.root_parameters%ready())exit decode
   if(decoded_roots%potential_root_depth_cm>root_parameters%maximum_root_depth_cm)exit decode
   inquire(unit=u,pos=position)
   if(position/=size(bytes)-3)exit decode
   if(decoded%validate()/=WOFOST_CROP_OWNER_OK.or.min(m%warm_days,m%regrowth_delay_days)<0)exit decode
   call kernel_reconstruct_committed_state_trusted(restored,lineage,revision,physical,clock,.true.,ok,code, &
      parameters=parameters,persisted_identity=identity)
   if(.not.ok)exit decode
   water=restored;crop=decoded;management=m;potential=decoded_potential;roots=decoded_roots;time=clock;status=0
  end block decode
  close(u)
 end subroutine
 subroutine write_crop(u,crop,io)
  integer,intent(in)::u
  type(wofost_crop_owner_state_t),intent(in)::crop
  integer,intent(out)::io
  integer::leaf_count
  leaf_count=crop%biomass%active_leaf_cohort_count()
  write(u,iostat=io)crop%development_stage,leaf_count, &
   crop%biomass%root_biomass,crop%biomass%stem_biomass,crop%biomass%storage_biomass, &
   crop%biomass%cumulative_dead_root_biomass,crop%biomass%cumulative_dead_stem_biomass,crop%biomass%cumulative_dead_leaf_biomass, &
   crop%biomass%exponential_leaf_area_index,crop%biomass%retained_dead_biomass, &
   crop%biomass%leaf_biomass,crop%biomass%specific_leaf_area,crop%biomass%leaf_age, &
   crop%evolution_continuation%temperature_sum,crop%evolution_continuation%anthesis_reached, &
   crop%evolution_continuation%minimum_temperature_history_count,crop%evolution_continuation%minimum_temperature_history, &
   0,0
 end subroutine
 subroutine read_crop(u,crop,io)
  integer,intent(in)::u
  type(wofost_crop_owner_state_t),intent(out)::crop
  integer,intent(out)::io
  integer::leaf_count,warm_days,delay_days
  crop%crop_emerged=.true.;allocate(crop%biomass,crop%evolution_continuation)
  read(u,iostat=io)crop%development_stage,leaf_count
  if(io/=0)return
  if(leaf_count<1.or.leaf_count>4096)then
   io=1;return
  end if
  allocate(crop%biomass%leaf_biomass(leaf_count),crop%biomass%specific_leaf_area(leaf_count),crop%biomass%leaf_age(leaf_count))
  read(u,iostat=io)crop%biomass%root_biomass,crop%biomass%stem_biomass,crop%biomass%storage_biomass, &
   crop%biomass%cumulative_dead_root_biomass,crop%biomass%cumulative_dead_stem_biomass,crop%biomass%cumulative_dead_leaf_biomass, &
   crop%biomass%exponential_leaf_area_index,crop%biomass%retained_dead_biomass, &
   crop%biomass%leaf_biomass,crop%biomass%specific_leaf_area,crop%biomass%leaf_age, &
   crop%evolution_continuation%temperature_sum,crop%evolution_continuation%anthesis_reached, &
   crop%evolution_continuation%minimum_temperature_history_count,crop%evolution_continuation%minimum_temperature_history, &
   warm_days,delay_days
  if(io/=0)return
  if(crop%validate()/=0.or.min(warm_days,delay_days)<0)io=1
 end subroutine
end module
