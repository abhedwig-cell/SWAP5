! Atomic historical rotation envelope. The incumbent maize adapter owns the
! water/heat/reactive-chemical disk stream; the incumbent WOFOST owner codec
! owns potato state. Decode every owner and input binding before publication.
module mod_hupsel_rotation_restart
 use iso_fortran_env,only:real64,int64,int32,int8,iostat_end
 use iso_c_binding,only:c_int,c_char,c_null_char
 use ieee_arithmetic,only:ieee_is_finite
 use mod_hupsel_germination
 use mod_hupsel_potato
 use mod_hupsel_scheduled_irrigation
 use mod_fmr_serialized_reference_backend
 use mod_fmr_runtime_core
 use mod_kernel_transactions
 use mod_fmr_b111_matrix_solute_route
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_transaction_persistence_t
 use mod_wofost_crop_native_codec,only:serialize_wofost_crop_view
 use mod_age_joint_restart_file,only:crc32
 implicit none
 private
 public::write_hupsel_rotation_restart,read_hupsel_rotation_restart,peek_hupsel_rotation_clock
 character(8),parameter::MAGIC='S5HR0003'
 character(10),parameter::INPUTS(6)=[character(10)::'swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']
 integer,parameter::MAX_FILE_BYTES=16777216
 interface
  integer(c_int) function open_c(path,mode)bind(C,name='open')
   import c_int,c_char
   character(c_char),intent(in)::path(*)
   integer(c_int),value::mode
  end function
  integer(c_int) function fsync_c(fd)bind(C,name='fsync')
   import c_int
   integer(c_int),value::fd
  end function
  integer(c_int) function close_c(fd)bind(C,name='close')
   import c_int
   integer(c_int),value::fd
  end function
  integer(c_int) function rename_c(old,new)bind(C,name='rename')
   import c_int,c_char
   character(c_char),intent(in)::old(*),new(*)
  end function
  integer(c_int) function getpid_c()bind(C,name='getpid')
   import c_int
  end function
 end interface
contains
 function local_stage(path,label)result(stage)
  character(*),intent(in)::path,label
  character(:),allocatable::stage
  character(32)::pid
  write(pid,'(i0)')getpid_c();stage=trim(path)//'.'//label//'.'//trim(pid)
 end function
 subroutine remove_file(path)
  character(*),intent(in)::path
  integer::u,io
  open(newunit=u,file=path,status='old',iostat=io)
  if(io==0)close(u,status='delete',iostat=io)
 end subroutine
 subroutine file_bytes(path,raw,status)
  character(*),intent(in)::path
  integer(int8),allocatable,intent(out)::raw(:)
  integer,intent(out)::status
  integer::n,u,io
  status=1;inquire(file=path,size=n,iostat=io)
  if(io/=0.or.n<1.or.n>MAX_FILE_BYTES)return
  allocate(raw(n),stat=io);if(io/=0)return
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
  if(io/=0)return
  read(u,iostat=io)raw;close(u)
  if(io==0)status=0
 end subroutine
 logical function crop_clock_matches(v,crop,clock)result(ok)
  type(fmr_wofost_crop_transaction_persistence_t),intent(in)::v
  type(potato_crop_t),intent(in)::crop
  real(real64),intent(in)::clock
  ok=.false.
  if(.not.v%ready().or..not.ieee_is_finite(clock))return
  if(clock<0d0.or.clock>1096d0.or.clock/=aint(clock))return
  if(clock<crop%crop_start+1d0)then
   if(v%receipt_present)return
   if(crop%grass_mode)then
    if(.not.v%owner%crop_emerged.or..not.v%grass_management_present)return
    if(v%grass_management%cut_index/=1.or.v%grass_management%potential_cut_index/=1)return
    if(v%grass_management%actual_cut_age/=0.or.v%grass_management%potential_cut_age/=0)return
    if(v%grass_management%harvested_dry_matter/=0d0.or.v%grass_management%potential_harvested_dry_matter/=0d0)return
   else
    if(v%owner%crop_emerged)return
   end if
   if(v%lifecycle%revision/=0_int64.or.v%lifecycle%germination_temperature_sum/=0d0)return
  else
   if(.not.v%receipt_present)return
   if(v%receipt%t1/=min(clock,crop%crop_end+1d0))return
  end if
  ok=.true.
 end function
 subroutine write_hupsel_rotation_restart(path,column,template,water_id,p,water,chemical,maize,potato,grass,irrigation,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(fmr_b110_physical_parameters_t),intent(in)::p
  type(kernel_committed_state_t),intent(in)::water
  type(matrix_solute_state_t),intent(in)::chemical
  type(hupsel_germination_t),intent(in)::maize
  type(potato_crop_t),intent(in)::potato,grass
  type(original_potato_irrigation_t),intent(in)::irrigation
  type(original_potato_irrigation_t)::irrigation_copy
  integer,intent(out)::status
  type(fmr_wofost_crop_transaction_persistence_t)::v,g
  integer(int8),allocatable::blob(:),raw(:),input(:)
  character(:),allocatable::inner,pending
  integer::u,io,code,i,n
  integer(int32)::crc
  integer(c_int)::fd,rc
  real(real64)::clock
  logical::ok
  status=1
  if(.not.water%ready().or..not.chemical%ready().or.p%active_nodes/=34)return
  call water%current_time(clock,ok);if(.not.ok)return
  call potato%export_state(v,code);if(code/=0)return
  if(.not.crop_clock_matches(v,potato,clock))return
  call grass%export_state(g,code);if(code/=0)return
  if(.not.crop_clock_matches(g,grass,clock))return
  if(.not.irrigation%valid().or.irrigation%clock/=clock)return
  irrigation_copy=irrigation
  inner=local_stage(path,'water-stage');pending=local_stage(path,'pending')
  call maize%write_restart(inner,column,template,water_id,p,water,chemical,code)
  if(code/=0)then;call remove_file(inner);return;end if
  call file_bytes(inner,blob,code);call remove_file(inner);if(code/=0)return
  call remove_file(pending)
  open(newunit=u,file=pending,access='stream',form='unformatted',status='new',action='write',iostat=io)
  if(io/=0)return
  write(u,iostat=io)MAGIC,clock,p%active_nodes
  do i=1,size(INPUTS)
   if(io/=0)exit
   call file_bytes(trim(INPUTS(i)),input,code)
   if(code/=0)then;io=1;exit;end if
   write(u,iostat=io)size(input),input
  end do
  if(io==0)write(u,iostat=io)size(blob),blob
  if(io==0)call serialize_wofost_crop_view(u,.false.,v,io,source_clipped_schema=.true.,grass_schema=.true.)
  if(io==0)call serialize_wofost_crop_view(u,.false.,g,io,source_clipped_schema=.true.,grass_schema=.true.)
  if(io==0)call irrigation_native_view(u,.false.,irrigation_copy,io)
  close(u)
  if(io/=0)then;call remove_file(pending);return;end if
  call file_bytes(pending,raw,code)
  if(code/=0)then;call remove_file(pending);return;end if
  crc=crc32(raw)
  open(newunit=u,file=pending,access='stream',form='unformatted',status='old',position='append',action='write',iostat=io)
  if(io==0)then
   write(u,iostat=io)crc;close(u)
  end if
  if(io/=0)then;call remove_file(pending);return;end if
  fd=open_c(pending//c_null_char,0_c_int)
  if(fd<0)then;call remove_file(pending);return;end if
  rc=fsync_c(fd);code=close_c(fd)
  if(rc/=0)then;call remove_file(pending);return;end if
  rc=rename_c(pending//c_null_char,trim(path)//c_null_char)
  if(rc/=0)then;call remove_file(pending);return;end if
  status=0
 end subroutine
 subroutine decode_envelope(path,clock,blob,v,g,irrigation,status)
  character(*),intent(in)::path
  real(real64),intent(out)::clock
  integer(int8),allocatable,intent(out)::blob(:)
  type(fmr_wofost_crop_transaction_persistence_t),intent(out)::v,g
  type(original_potato_irrigation_t),intent(out)::irrigation
  real(real64)::origin
  integer,intent(out)::status
  integer(int8),allocatable::raw(:),input(:),bound(:)
  character(8)::tag
  integer::u,io,code,nodes,n,i
  integer(int8)::extra
  integer(int32)::crc
  clock=0d0;status=1
  call file_bytes(path,raw,code);if(code/=0)return
  n=size(raw);if(n<32)return
  crc=transfer(raw(n-3:n),crc)
  if(crc32(raw(:n-4))/=crc)return
  ! Parse precisely the generation whose CRC was validated, even if another
  ! process publishes the path through an atomic rename during this read.
  open(newunit=u,status='scratch',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  write(u,iostat=io)raw(:n-4)
  if(io/=0)then;close(u);return;end if
  rewind(u)
  read(u,iostat=io)tag,clock,nodes
  if(io/=0)then;close(u);return;end if
  if(tag/=MAGIC.or.nodes/=34.or..not.ieee_is_finite(clock))then;close(u);return;end if
  if(clock<0d0.or.clock>1096d0.or.clock/=aint(clock))then;close(u);return;end if
  do i=1,size(INPUTS)
   read(u,iostat=io)n
   if(io/=0)exit
   if(n<1.or.n>MAX_FILE_BYTES)then;io=1;exit;end if
   if(allocated(bound))deallocate(bound)
   allocate(bound(n),stat=io);if(io/=0)exit
   read(u,iostat=io)bound;if(io/=0)exit
   call file_bytes(trim(INPUTS(i)),input,code)
   if(code/=0)then;io=1;exit;end if
   if(size(input)/=n)then;io=1;exit;end if
   if(any(input/=bound))then;io=1;exit;end if
  end do
  if(io==0)then
   read(u,iostat=io)n
   if(io==0)then
    if(n<1.or.n>MAX_FILE_BYTES)then
     io=1
    else
     allocate(blob(n),stat=io)
     if(io==0)read(u,iostat=io)blob
    end if
   end if
  end if
  if(io==0)call serialize_wofost_crop_view(u,.true.,v,io,source_clipped_schema=.true.,grass_schema=.true.)
  if(io==0)call serialize_wofost_crop_view(u,.true.,g,io,source_clipped_schema=.true.,grass_schema=.true.)
  if(io==0)then
   call rdinit(74,0,'swap.swp');call rdstim('tstart',origin);close(74)
   call irrigation%initialize('potato.crp',origin,34,code)
   if(code/=0)io=1
  end if
  if(io==0)call irrigation_native_view(u,.true.,irrigation,io)
  if(io==0)then
   if(irrigation%clock/=clock)io=1
  end if
  if(io==0)then
   if(.not.v%ready().or..not.g%ready())io=1
  end if
  if(io==0)then
   read(u,iostat=io)extra
   if(io==iostat_end)then;status=0;end if
  end if
  close(u)
 end subroutine
 subroutine peek_hupsel_rotation_clock(path,clock,status)
  character(*),intent(in)::path
  real(real64),intent(out)::clock
  integer,intent(out)::status
  integer(int8),allocatable::blob(:)
  type(fmr_wofost_crop_transaction_persistence_t)::v,g
  type(original_potato_irrigation_t)::irrigation
  call decode_envelope(path,clock,blob,v,g,irrigation,status)
 end subroutine
 subroutine read_hupsel_rotation_restart(path,column,template,water_id,chemical_id,p,chemistry,water,chemical,maize,potato,grass,irrigation,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,chemical_id
  type(fmr_b110_physical_parameters_t),intent(in)::p
  type(b111_reactive_solute_substep_forcing_t),intent(in)::chemistry
  type(kernel_committed_state_t),intent(inout)::water
  type(matrix_solute_state_t),intent(inout)::chemical
  type(hupsel_germination_t),intent(inout)::maize
  type(potato_crop_t),intent(inout)::potato,grass
  type(original_potato_irrigation_t),intent(inout)::irrigation
  type(original_potato_irrigation_t)::irrigation_next
  integer,intent(out)::status
  type(kernel_committed_state_t)::w
  type(matrix_solute_state_t)::c
  type(hupsel_germination_t)::m
  type(potato_crop_t)::crop,grass_next
  type(fmr_wofost_crop_transaction_persistence_t)::v,g
  integer(int8),allocatable::blob(:)
  character(:),allocatable::inner
  real(real64)::clock,observed
  integer::io,code,u
  logical::ok
  status=1
  if(water%ready().or.chemical%ready())return
  call decode_envelope(path,clock,blob,v,g,irrigation_next,code);if(code/=0)return
  if(.not.crop_clock_matches(v,potato,clock))return
  crop=potato;call crop%restore_state(v,code);if(code/=0)return
  if(.not.crop_clock_matches(g,grass,clock))return
  grass_next=grass;call grass_next%restore_state(g,code);if(code/=0)return
  inner=local_stage(path,'read-stage');call remove_file(inner)
  open(newunit=u,file=inner,status='new',access='stream',form='unformatted',action='write',iostat=io)
  if(io/=0)return
  write(u,iostat=io)blob;close(u)
  if(io/=0)then;call remove_file(inner);return;end if
  m=maize
  call m%read_restart(inner,column,template,water_id,chemical_id,p,chemistry,w,c,code)
  call remove_file(inner);if(code/=0)return
  call w%current_time(observed,ok);if(.not.ok.or.observed/=clock)return
  water=w;chemical=c;maize=m;potato=crop;grass=grass_next;irrigation=irrigation_next;status=0
 end subroutine
end module mod_hupsel_rotation_restart
