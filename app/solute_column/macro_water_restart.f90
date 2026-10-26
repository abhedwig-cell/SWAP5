! One same-platform, CRC-protected committed water/heat/macro/Rutter generation.
module mod_macro_water_restart
 use iso_fortran_env,only:real64,int64,int32,int8
 use ieee_arithmetic,only:ieee_is_finite
 use mod_macropore_standard_storage,only:macropore_standard_storage_view_t,derive_macropore_standard_storage_view
 use iso_c_binding,only:c_int,c_char,c_null_char
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_committed_restart
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view,initialize_soil_temperature_state
 use mod_interception_source_window_runtime,only:interception_source_window_t
 use mod_rutter_source_window_processor
 use mod_age_joint_restart_file,only:crc32
 implicit none
 private
 public::write_macro_water_restart,read_macro_water_restart
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
 subroutine write_macro_water_restart(path,binding,column,template,p,water,window,status)
 character(*),intent(in)::path,binding
 type(fmr_logical_column_t),intent(in)::column
 type(fmr_template_t),intent(in)::template
 type(fmr_b110_physical_parameters_t),intent(in)::p
 type(kernel_committed_state_t),intent(in)::water
 type(interception_source_window_t),intent(in)::window
 integer,intent(out)::status
 type(fmr_committed_restart_bundle_t)::b
 type(soil_temperature_field_view_t)::heat
 type(rutter_source_restart_t)::rutter
 integer::u,io,n,nd,st,size_bytes,slash
 character(:),allocatable::directory
 integer(c_int)::fd,rc
 integer(int8),allocatable::bytes(:)
 integer(int32)::crc
 logical::ok,rutter_bound
 status=1
 if(len_trim(binding)/=64)return
 call fmr_export_committed_restart([column],[template],[water],p%parameter_set_id,b,ok,st)
 if(.not.ok.or.st/=FMR_RESTART_OK)return
 select type(s=>b%records(1)%physical_state)
 type is(fmr_b110_boesten_macropore_state_t)
  if(.not.allocated(s%macropore).or..not.allocated(s%soil_temperature).or..not.allocated(s%rutter))return
  if(.not.valid_state(s,p,b%records(1)%committed_time))return
  n=s%active_nodes;nd=s%macropore%num_domains
  call build_soil_temperature_field_view(s%soil_temperature,heat,st);if(st/=0)return
  rutter_bound=s%rutter%source_window_initialized()
  if(rutter_bound)then
   call export_rutter_source_restart(window,s%rutter,rutter,st);if(st/=0)return
   if(rutter%source_progress%accepted_until/=rutter%source_progress%t1)return
  else
   rutter%canopy_storage_cm=s%rutter%canopy_storage()
  end if
  open(newunit=u,file=path//'.tmp',status='replace',access='stream',form='unformatted',action='readwrite',iostat=io)
  if(io/=0)return
  write(u,iostat=io)'S5WM0001',binding(1:64),n,nd,b%schema_version,b%parameter_set_identity
  if(io==0)write(u,iostat=io)b%records(1)%kernel_schema_version,b%records(1)%column_id,b%records(1)%parameter_ref, &
   b%records(1)%forcing_handle,b%records(1)%template_identity,b%records(1)%lineage_id,b%records(1)%revision, &
   b%records(1)%committed_time,b%records(1)%time_bound
  if(io==0)write(u,iostat=io)s%pressure_head,s%water_content,s%ponding_depth,s%groundwater_level,s%boesten_evaporation
  if(io==0)write(u,iostat=io)s%macropore%icp_bottom_domain,s%macropore%sorptivity,s%macropore%theta_sorption_ref, &
   s%macropore%absorption_time,s%macropore%volume_domain_cp,s%macropore%water_domain_cp,s%macropore%dynamic_volume_cp
  if(io==0)write(u,iostat=io)heat%temperature_c,rutter_bound,rutter
  if(io/=0)then;close(u);return;end if
  inquire(unit=u,size=size_bytes);allocate(bytes(size_bytes));read(u,pos=1,iostat=io)bytes
  if(io==0)then;crc=crc32(bytes);write(u,pos=size_bytes+1,iostat=io)crc;end if
  close(u);if(io/=0)return
  fd=open_c(path//'.tmp'//c_null_char,0_c_int);if(fd<0)return
  rc=sync_c(fd);st=close_c(fd);if(rc/=0.or.st/=0)return
  rc=rename_c(path//'.tmp'//c_null_char,path//c_null_char);if(rc/=0)return
  slash=index(path,'/',back=.true.);directory='.'
  if(slash==1)directory='/'
  if(slash>1)directory=path(:slash-1)
  fd=open_c(directory//c_null_char,0_c_int);if(fd<0)return
  rc=sync_c(fd);st=close_c(fd);if(rc/=0.or.st/=0)return
  status=0
 class default
  return
 end select
 end subroutine
 subroutine read_macro_water_restart(path,binding,column,template,p,water,window,status)
 character(*),intent(in)::path,binding
 type(fmr_logical_column_t),intent(in)::column
 type(fmr_template_t),intent(in)::template
 type(fmr_b110_physical_parameters_t),intent(in)::p
 type(kernel_committed_state_t),intent(inout)::water
 type(interception_source_window_t),intent(out)::window
 integer,intent(out)::status
 type(fmr_committed_restart_bundle_t)::b
 type(fmr_b110_boesten_macropore_state_t)::s
 type(kernel_committed_state_t)::registry(1)
 type(rutter_source_restart_t)::rutter
 integer::u,io,n,nd,st,size_bytes,position
 integer(int8),allocatable::bytes(:)
 real(real64),allocatable::temperature(:)
 integer(int32)::crc
 character(8)::magic
 character(64)::stored_binding
 logical::ok,rutter_bound
 status=1
 if(water%ready().or.len_trim(binding)/=64)return
 open(newunit=u,file=path,status='old',access='stream',form='unformatted',action='read',iostat=io);if(io/=0)return
 inquire(unit=u,size=size_bytes)
 if(size_bytes<128.or.size_bytes>10000000)then;close(u);return;end if
 allocate(bytes(size_bytes-4));read(u,pos=1,iostat=io)bytes
 if(io==0)read(u,iostat=io)crc
 if(io/=0)then;close(u);return;end if
 if(crc32(bytes)/=crc)then;close(u);return;end if
 read(u,pos=1,iostat=io)magic,stored_binding,n,nd
 if(io/=0)then;close(u);return;end if
 if(magic/='S5WM0001'.or.stored_binding/=binding.or.n/=p%active_nodes.or.nd<1.or.nd>64)then;close(u);return;end if
 if(.not.allocated(p%macropore).or..not.allocated(p%soil_temperature))then;close(u);return;end if
 if(nd/=p%macropore%geometry%num_domains)then;close(u);return;end if
 allocate(b%records(1))
 read(u,iostat=io)b%schema_version,b%parameter_set_identity
 if(io==0)read(u,iostat=io)b%records(1)%kernel_schema_version,b%records(1)%column_id,b%records(1)%parameter_ref, &
   b%records(1)%forcing_handle,b%records(1)%template_identity,b%records(1)%lineage_id,b%records(1)%revision, &
   b%records(1)%committed_time,b%records(1)%time_bound
 if(io/=0)then;close(u);return;end if
 b%records(1)%schema_version=b%schema_version
 s%active_nodes=n;allocate(s%pressure_head(n),s%water_content(n),s%macropore,s%soil_temperature,s%rutter,temperature(n))
 call s%macropore%initialize(nd,n,ok);if(.not.ok)then;close(u);return;end if
 read(u,iostat=io)s%pressure_head,s%water_content,s%ponding_depth,s%groundwater_level,s%boesten_evaporation
 if(io==0)read(u,iostat=io)s%macropore%icp_bottom_domain,s%macropore%sorptivity,s%macropore%theta_sorption_ref, &
   s%macropore%absorption_time,s%macropore%volume_domain_cp,s%macropore%water_domain_cp,s%macropore%dynamic_volume_cp
 if(io==0)read(u,iostat=io)temperature,rutter_bound,rutter
 inquire(unit=u,pos=position);close(u)
 if(io/=0.or.position/=size_bytes-3)return
 call initialize_soil_temperature_state(temperature,s%soil_temperature,st);if(st/=0)return
 if(rutter_bound)then
  if(rutter%source_progress%accepted_until/=rutter%source_progress%t1)return
  call restore_rutter_source_restart(rutter,window,s%rutter,st)
 else
  if(rutter%schema/=0.or.rutter%source_progress%schema/=0)return
  window=interception_source_window_t()
  call initialize_rutter_canopy_state(rutter%canopy_storage_cm,s%rutter,st)
 end if
 if(st/=0)return
 if(.not.valid_state(s,p,b%records(1)%committed_time))return
 allocate(b%records(1)%physical_state,source=s)
 call fmr_restore_committed_restart(b,p%parameter_set_id,[column],[template],registry,ok,st)
 if(.not.ok.or.st/=FMR_RESTART_OK)return
 water=registry(1);status=0
 end subroutine
 logical function valid_state(s,p,clock)result(ok)
 type(fmr_b110_boesten_macropore_state_t),intent(in)::s
 type(fmr_b110_physical_parameters_t),intent(in)::p
 real(real64),intent(in)::clock
 type(macropore_standard_storage_view_t)::view
 ok=.false.
 if(.not.ieee_is_finite(clock).or.clock<0d0)return
 if(.not.all(ieee_is_finite(s%pressure_head)).or..not.all(ieee_is_finite(s%water_content)))return
 if(any(s%water_content<0d0).or.any(s%water_content>1d0))return
 if(.not.all(ieee_is_finite([s%ponding_depth,s%groundwater_level,s%boesten_evaporation%spev,s%boesten_evaporation%saev])))return
 if(s%ponding_depth<0d0.or.s%boesten_evaporation%spev<0d0.or.s%boesten_evaporation%saev<0d0)return
 if(.not.allocated(s%macropore).or..not.allocated(s%rutter).or..not.allocated(s%soil_temperature))return
 if(.not.s%macropore%ready())return
 associate(m=>s%macropore)
 if(.not.all(ieee_is_finite(m%sorptivity)).or..not.all(ieee_is_finite(m%theta_sorption_ref)).or. &
    .not.all(ieee_is_finite(m%absorption_time)).or..not.all(ieee_is_finite(m%volume_domain_cp)).or. &
    .not.all(ieee_is_finite(m%water_domain_cp)).or..not.all(ieee_is_finite(m%dynamic_volume_cp)))return
 if(any(m%sorptivity<0d0).or.any(m%theta_sorption_ref<0d0).or.any(m%absorption_time<0d0).or. &
    any(m%volume_domain_cp<0d0).or.any(m%water_domain_cp<0d0).or.any(m%dynamic_volume_cp<0d0))return
 call derive_macropore_standard_storage_view(m,p%macropore%geometry%top_node,p%z,p%dz,view)
 if(.not.view%valid)return
 if(maxval(abs(view%normalized_water_cm-m%water_domain_cp))>1d-10)return
 end associate
 if(s%rutter%source_window_initialized())then
  if(abs(s%rutter%accepted_until()-clock)>64d0*epsilon(1d0)*max(1d0,abs(clock)))return
 else
  if(clock/=0d0)return
 end if
 ok=.true.
 end function
end module
