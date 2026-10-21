! S5PT0001: one POSIX generation, water/heat/solute, same-platform ABI.
module mod_pond_thermal_restart_file
 use iso_fortran_env,only:real64,int64,int32,int8,iostat_end
 use iso_c_binding,only:c_int,c_char,c_null_char
 use ieee_arithmetic,only:ieee_is_finite
 use mod_transaction_reference,only:transaction_state_t
 use mod_kernel_transactions
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_committed_restart
 use mod_fmr_b111_pond_thermal_application
 use mod_fmr_b111_matrix_solute_route
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 use mod_solute_mobile_salt_state,only:mobile_salt_state_t
 use mod_solute_compartment_state,only:solute_compartment_state_t
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view, &
  initialize_soil_temperature_state
 use mod_age_joint_restart_file,only:crc32
 implicit none
 private
 public::write_pond_thermal_restart,read_pond_thermal_restart
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
 function heat_vector(p)result(v)
  type(fmr_b110_physical_parameters_t),intent(in)::p
  real(real64),allocatable::v(:)
  if(.not.p%soil_temperature_active.or..not.allocated(p%soil_temperature))return
  if(.not.p%soil_temperature%ready())return
  if(.not.allocated(p%z).or..not.allocated(p%dz).or..not.allocated(p%node_distance).or..not.allocated(p%cofgen))return
  associate(h=>p%soil_temperature)
   v=[p%z,p%dz,p%node_distance,reshape(p%cofgen,[size(p%cofgen)]), &
    real(h%solution_mode,real64),h%dz_cm,h%distance_above_cm,h%node_depth_cm,h%theta_sat, &
    h%f_quartz,h%f_clay,h%f_organic,h%fkk_qco_dry,h%fk_qco_dry,h%fkk_qco_wet,h%fk_qco_wet, &
    h%analytic_mean_temperature_c,h%analytic_amplitude_c,h%analytic_reference_day,h%analytic_damping_depth_cm]
  end associate
 end function
 integer function synchronize(path)result(st)
  character(*),intent(in)::path
  integer(c_int)::fd,rc
  st=1;fd=open_c(path//c_null_char,0_c_int);if(fd<0)return
  st=sync_c(fd);rc=close_c(fd);if(rc/=0)st=1
 end function
 subroutine bytes(path,a,st)
  character(*),intent(in)::path
  integer(int8),allocatable,intent(out)::a(:)
  integer,intent(out)::st
  integer::n,u,io
  st=1;inquire(file=path,size=n,iostat=io)
  if(io/=0.or.n<12.or.n>10485760)return
  allocate(a(n))
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io);if(io/=0)return
  read(u,iostat=io)a;close(u);if(io==0)st=0
 end subroutine
 subroutine write_pond_thermal_restart(path,column,template,water_id,parameters,water,chemical,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(fmr_b110_physical_parameters_t),intent(in)::parameters
  type(kernel_committed_state_t),intent(in)::water
  type(matrix_solute_state_t),intent(in)::chemical
  integer,intent(out)::status
  type(fmr_committed_restart_bundle_t)::b
  type(kernel_parameter_identity_t)::identity,expected_identity
  type(b111_reactive_solute_substep_forcing_t)::p
  type(mobile_salt_state_t)::m
  type(solute_compartment_state_t)::s
  type(soil_temperature_field_view_t)::heat
  real(real64),allocatable::v(:),hv(:),theta(:),derivative(:)
  real(real64)::time
  integer(int64)::id,revision
  integer(int8),allocatable::a(:)
  integer::u,io,code,n,slash
  logical::ok,history,opened
  character(:),allocatable::pending,parent
  status=1
  if(.not.matrix_thermal_template(template).or.column%state_handle/=1)return
  if(template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE)return
  if(.not.pond_thermal_states_match(water,chemical))return
  call water%certified_parameter_identity(identity,ok);if(.not.ok)return
  call parameters%capture_identity(expected_identity,ok);if(.not.ok)return
  if(.not.identity%matches(expected_identity))return
  call fmr_export_committed_restart([column],[template],[water],water_id,b,ok,code)
  if(.not.ok.or.code/=0)return
  call chemical%configuration(p,id);v=matrix_parameter_vector(p);hv=heat_vector(parameters)
  if(.not.allocated(v).or..not.allocated(hv))return
  if(.not.all(ieee_is_finite(v)).or..not.all(ieee_is_finite(hv)))return
  call chemical%snapshot(time,theta,m,s,revision)
  ! This format carries the physical water/heat state with no continuation history.
  select type(q=>b%records(1)%physical_state)
  type is(fmr_b110_physical_state_t)
   history=.false.
   call build_soil_temperature_field_view(q%soil_temperature,heat,code)
  class default
   return
  end select
  if(code/=0)return
  n=size(theta);pending=path//'.pending'
  open(newunit=u,file=pending,access='stream',form='unformatted',status='new',iostat=io);if(io/=0)return
  writing:block
   associate(r=>b%records(1))
    write(u,iostat=io)'S5PT0001',b%schema_version,b%parameter_set_identity,r%schema_version,r%kernel_schema_version, &
     r%column_id,r%parameter_ref,r%forcing_handle,r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
     n,history,identity%parameter_set_id,size(hv),hv
    if(io/=0)exit writing
    select type(q=>r%physical_state)
    type is(fmr_b110_physical_state_t)
     write(u,iostat=io)q%pressure_head,q%water_content,q%ponding_depth,q%groundwater_level,heat%temperature_c
    end select
    if(io/=0)exit writing
    if(history)write(u,iostat=io)derivative
    if(io/=0)exit writing
    write(u,iostat=io)id,revision,time,size(v),v,theta,m%concentration_mg_cm3,m%mass_mg_cm2,s%sorbed_matrix_mass,s%pond_mass
   end associate
   if(io/=0)exit writing
   flush(u,iostat=io);if(io/=0)exit writing
   close(u,iostat=io);if(io/=0)exit writing
   call bytes(pending,a,code);if(code/=0)exit writing
   open(newunit=u,file=pending,access='stream',form='unformatted',status='old',position='append',iostat=io)
   if(io/=0)exit writing
   write(u,iostat=io)crc32(a);if(io/=0)exit writing
   flush(u,iostat=io);if(io/=0)exit writing
   close(u,iostat=io);if(io/=0)exit writing
   if(synchronize(pending)/=0)exit writing
   code=rename_c(pending//c_null_char,path//c_null_char);if(code/=0)exit writing
   slash=index(path,'/',back=.true.);parent='.'
   if(slash==1)parent='/'
   if(slash>1)parent=path(:slash-1)
   if(synchronize(parent)/=0)exit writing
   status=0
  end block writing
  inquire(unit=u,opened=opened)
  if(opened)close(u,iostat=io)
  ! A failed pending generation is retained fail-closed for diagnosis/recovery.
 end subroutine

 subroutine read_pond_thermal_restart(path,column,template,water_id,chemical_id,parameters,p,water,chemical,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,chemical_id
  type(fmr_b110_physical_parameters_t),intent(in)::parameters
  type(b111_reactive_solute_substep_forcing_t),intent(in)::p
  type(kernel_committed_state_t),intent(inout)::water
  type(matrix_solute_state_t),intent(inout)::chemical
  integer,intent(out)::status
  type(fmr_committed_restart_bundle_t)::b
  type(kernel_committed_state_t)::temporary,w(1),certified
  type(kernel_parameter_identity_t)::identity
  type(fmr_b110_physical_state_t)::physical
  type(matrix_solute_state_t)::c
  integer(int8),allocatable::a(:)
  integer(int32)::checksum
  integer(int8)::extra
  real(real64),allocatable::v(:),expected(:),hv(:),want_heat(:),temperature(:),derivative(:), &
   theta(:),concentration(:),dissolved(:),sorbed(:)
  real(real64)::time,pond_mass
  integer(int64)::id,revision,physical_id
  character(8)::tag
  integer::u,io,n,count,code
  logical::ok,history
  status=1
  if(water%ready().or.chemical%ready())return
  if(.not.matrix_thermal_template(template).or.column%state_handle/=1)return
  if(template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE)return
  expected=matrix_parameter_vector(p);want_heat=heat_vector(parameters)
  if(.not.allocated(expected).or..not.allocated(want_heat))return
  if(.not.all(ieee_is_finite(expected)).or..not.all(ieee_is_finite(want_heat)))return
  call bytes(path,a,code);if(code/=0)return
  checksum=transfer(a(size(a)-3:),checksum)
  if(checksum/=crc32(a(:size(a)-4)))return
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io);if(io/=0)return
  allocate(b%records(1))
  decoding:block
   associate(r=>b%records(1))
    read(u,iostat=io)tag,b%schema_version,b%parameter_set_identity,r%schema_version,r%kernel_schema_version, &
     r%column_id,r%parameter_ref,r%forcing_handle,r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
     n,history,physical_id,count
    if(io/=0)exit decoding
    io=1
    if(tag/='S5PT0001'.or.n<1.or.n>256.or.n/=parameters%active_nodes)exit decoding
    if(physical_id/=parameters%parameter_set_id.or.count/=size(want_heat))exit decoding
    allocate(hv(count));read(u,iostat=io)hv;if(io/=0)exit decoding
    io=1
    if(.not.all(ieee_is_finite(hv)))exit decoding
    if(any(hv/=want_heat))exit decoding
    physical%active_nodes=n
    allocate(physical%pressure_head(n),physical%water_content(n),temperature(n),theta(n),concentration(n),dissolved(n),sorbed(n))
    read(u,iostat=io)physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level,temperature
    if(io/=0)exit decoding
    allocate(physical%soil_temperature)
    call initialize_soil_temperature_state(temperature,physical%soil_temperature,io);if(io/=0)exit decoding
    io=1
    if(history)exit decoding
    call fmr_new_b110_committed_state(temporary,column%column_id,physical,0d0,ok)
    io=1;if(.not.ok)exit decoding
    call temporary%snapshot(r%physical_state,ok);if(.not.ok)exit decoding
    read(u,iostat=io)id,revision,time,count;if(io/=0)exit decoding
    io=1
    if(id/=chemical_id.or.count/=size(expected))exit decoding
    allocate(v(count));read(u,iostat=io)v,theta,concentration,dissolved,sorbed,pond_mass,checksum
    if(io/=0)exit decoding
    io=1
    if(.not.all(ieee_is_finite(v)))exit decoding
    if(any(v/=expected))exit decoding
    read(u,iostat=io)extra
    if(io/=iostat_end)then;io=1;exit decoding;end if
    call fmr_restore_committed_restart(b,water_id,[column],[template],w,ok,io)
    if(.not.ok.or.io/=0)then;io=1;exit decoding;end if
    call parameters%capture_identity(identity,ok)
    if(.not.ok)then;io=1;exit decoding;end if
    call kernel_reconstruct_committed_state_trusted(certified,r%lineage_id,r%revision,r%physical_state, &
     r%committed_time,r%time_bound,ok,io,parameters,identity)
    if(.not.ok.or.io/=0)then;io=1;exit decoding;end if
    call reconstruct_matrix_solute_trusted(p,id,revision,time,theta,concentration,dissolved,sorbed,c,io,surface_mass=pond_mass)
    if(io/=0)exit decoding
    io=1
    if(.not.pond_thermal_states_match(certified,c))exit decoding
    io=0
   end associate
  end block decoding
  close(u)
  if(io/=0)return
  water=certified;chemical=c;status=0
 end subroutine
end module
